import Foundation
import Combine

struct ModelLimit {
    let label: String
    let percent: Double
    let resetTime: Date?
}

struct UsageData {
    var sessionPercent: Double = 0
    var sessionResetTime: Date? = nil
    var weeklyPercent: Double = 0
    var weeklyResetTime: Date? = nil
    var modelLimits: [ModelLimit] = []
    var lastFetched: Date? = nil
    var error: String? = nil
}

@MainActor
class UsageService: ObservableObject {
    @Published var usage = UsageData()
    @Published var isLoading = false

    private var timer: Timer?
    private var refreshInterval: TimeInterval = 60
    private let defaultInterval: TimeInterval = 60
    private let maxInterval: TimeInterval = 120

    init() {
        startPolling()
    }

    func startPolling(fetchImmediately: Bool = true) {
        timer?.invalidate()
        if fetchImmediately {
            Task { await fetchUsage() }
        }
        timer = Timer.scheduledTimer(withTimeInterval: refreshInterval, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                await self?.fetchUsage()
            }
        }
    }

    func refreshNow() {
        Task { await fetchUsage() }
    }

    func fetchUsage() async {
        NSLog("[CU] fetchUsage called, interval=%.0f", refreshInterval)
        guard let credentials = KeychainHelper.readClaudeOAuthToken() else {
            NSLog("[CU] EXIT: no credentials")
            usage.error = "No OAuth token found. Make sure you're logged into Claude Code."
            return
        }

        // Auto-refresh if token is expired or expiring within 60s
        var activeCredentials = credentials
        if let expiresAt = credentials.expiresAt, expiresAt.timeIntervalSinceNow < 60 {
            NSLog("[CU] Token expiring, refreshing...")
            KeychainHelper.clearCache()
            if let refreshed = await KeychainHelper.refreshAccessToken() {
                activeCredentials = refreshed
                NSLog("[CU] Token refreshed OK")
            } else {
                NSLog("[CU] EXIT: refresh failed")
                usage.error = "Token expired. Run 'claude' to refresh your session."
                return
            }
        }

        isLoading = true
        defer { isLoading = false }

        var request = URLRequest(url: URL(string: "https://api.anthropic.com/api/oauth/usage")!)
        request.httpMethod = "GET"
        request.setValue("Bearer \(activeCredentials.accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("oauth-2025-04-20", forHTTPHeaderField: "anthropic-beta")
        request.setValue("claude-code/2.1.63", forHTTPHeaderField: "User-Agent")

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                NSLog("[CU] EXIT: invalid response object")
                usage.error = "Invalid response"
                return
            }

            NSLog("[CU] HTTP %d", httpResponse.statusCode)

            if httpResponse.statusCode == 401 {
                KeychainHelper.clearCache()
                if let refreshed = await KeychainHelper.refreshAccessToken() {
                    var retryRequest = request
                    retryRequest.setValue("Bearer \(refreshed.accessToken)", forHTTPHeaderField: "Authorization")
                    if let (data2, resp2) = try? await URLSession.shared.data(for: retryRequest),
                       let http2 = resp2 as? HTTPURLResponse, http2.statusCode == 200,
                       let json2 = try? JSONSerialization.jsonObject(with: data2) as? [String: Any] {
                        parseUsageResponse(json2)
                        usage.lastFetched = Date()
                        usage.error = nil
                        NSLog("[CU] 401→refresh→OK session=%.0f%% weekly=%.0f%%", usage.sessionPercent, usage.weeklyPercent)
                        if refreshInterval != defaultInterval {
                            refreshInterval = defaultInterval
                            startPolling()
                        }
                        return
                    }
                }
                NSLog("[CU] EXIT: 401 unrecoverable")
                usage.error = "Token expired. Run 'claude' to refresh your session."
                return
            }

            if httpResponse.statusCode == 429 {
                let retryAfterHeader = Int(httpResponse.value(forHTTPHeaderField: "Retry-After") ?? "") ?? 10
                let retryDelay = max(retryAfterHeader, 10) + Int.random(in: 0...15)
                NSLog("[CU] 429 — sleeping %ds before retry", retryDelay)
                try? await Task.sleep(nanoseconds: UInt64(retryDelay) * 1_000_000_000)
                do {
                    let (data2, response2) = try await URLSession.shared.data(for: request)
                    if let http2 = response2 as? HTTPURLResponse, http2.statusCode == 200,
                       let json2 = try JSONSerialization.jsonObject(with: data2) as? [String: Any] {
                        parseUsageResponse(json2)
                        usage.lastFetched = Date()
                        usage.error = nil
                        NSLog("[CU] 429→retry→OK session=%.0f%% weekly=%.0f%%", usage.sessionPercent, usage.weeklyPercent)
                        if refreshInterval != defaultInterval {
                            refreshInterval = defaultInterval
                            startPolling()
                        }
                        return
                    } else if let http2 = response2 as? HTTPURLResponse {
                        NSLog("[CU] 429→retry→HTTP %d", http2.statusCode)
                    }
                } catch {
                    NSLog("[CU] 429→retry→error: %@", error.localizedDescription)
                }

                refreshInterval = min(refreshInterval * 2, maxInterval)
                NSLog("[CU] EXIT: 429 backoff, next interval=%.0f", refreshInterval)
                startPolling(fetchImmediately: false)
                if usage.lastFetched == nil {
                    usage.error = "Rate limited — retrying in \(Int(refreshInterval))s"
                }
                return
            }

            guard httpResponse.statusCode == 200 else {
                NSLog("[CU] EXIT: unexpected HTTP %d", httpResponse.statusCode)
                usage.error = "API error: HTTP \(httpResponse.statusCode)"
                return
            }

            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                NSLog("[CU] EXIT: JSON parse failed")
                usage.error = "Failed to parse response"
                return
            }

            parseUsageResponse(json)
            usage.lastFetched = Date()
            usage.error = nil
            NSLog("[CU] OK session=%.0f%% weekly=%.0f%%", usage.sessionPercent, usage.weeklyPercent)

            if refreshInterval != defaultInterval {
                refreshInterval = defaultInterval
                startPolling()
            }

        } catch {
            NSLog("[CU] Network error: %@, retrying in 3s...", error.localizedDescription)
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            do {
                let (data2, response2) = try await URLSession.shared.data(for: request)
                if let http2 = response2 as? HTTPURLResponse, http2.statusCode == 200,
                   let json2 = try JSONSerialization.jsonObject(with: data2) as? [String: Any] {
                    parseUsageResponse(json2)
                    usage.lastFetched = Date()
                    usage.error = nil
                    NSLog("[CU] network→retry→OK session=%.0f%% weekly=%.0f%%", usage.sessionPercent, usage.weeklyPercent)
                    if refreshInterval != defaultInterval {
                        refreshInterval = defaultInterval
                        startPolling()
                    }
                    return
                } else if let http2 = response2 as? HTTPURLResponse {
                    NSLog("[CU] network→retry→HTTP %d", http2.statusCode)
                }
            } catch {
                NSLog("[CU] network→retry→error: %@", error.localizedDescription)
            }

            refreshInterval = min(refreshInterval * 2, maxInterval)
            NSLog("[CU] EXIT: network backoff, next interval=%.0f", refreshInterval)
            startPolling(fetchImmediately: false)
            if usage.lastFetched == nil {
                usage.error = "Network error: \(error.localizedDescription)"
            }
        }
    }

    private func parseUsageResponse(_ json: [String: Any]) {
        // Parse five_hour (current session)
        if let fiveHour = json["five_hour"] as? [String: Any] {
            if let utilization = fiveHour["utilization"] as? Double {
                usage.sessionPercent = utilization
            }
            if let resetAt = fiveHour["resets_at"] as? String {
                usage.sessionResetTime = parseDate(resetAt)
            }
        }

        // Parse seven_day (weekly)
        if let sevenDay = json["seven_day"] as? [String: Any] {
            if let utilization = sevenDay["utilization"] as? Double {
                usage.weeklyPercent = utilization
            }
            if let resetAt = sevenDay["resets_at"] as? String {
                usage.weeklyResetTime = parseDate(resetAt)
            }
        }

        // Parse any model-specific weekly limits (e.g. seven_day_sonnet, seven_day_opus)
        var models: [ModelLimit] = []
        for (key, value) in json {
            guard key.hasPrefix("seven_day_"),
                  let dict = value as? [String: Any],
                  let util = dict["utilization"] as? Double else { continue }
            let label = key.replacingOccurrences(of: "seven_day_", with: "")
                            .replacingOccurrences(of: "_", with: " ").capitalized
            let resetTime: Date? = (dict["resets_at"] as? String).flatMap { parseDate($0) }
            models.append(ModelLimit(label: label, percent: util, resetTime: resetTime))
        }
        usage.modelLimits = models.sorted { $0.label < $1.label }
    }

    private func parseDate(_ string: String) -> Date? {
        // Try ISO8601DateFormatter with fractional seconds
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = iso.date(from: string) { return date }

        // Fallback without fractional seconds
        iso.formatOptions = [.withInternetDateTime]
        if let date = iso.date(from: string) { return date }

        // Fallback: DateFormatter which handles more formats
        let df = DateFormatter()
        df.locale = Locale(identifier: "en_US_POSIX")
        df.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSSSSxxx"
        if let date = df.date(from: string) { return date }

        df.dateFormat = "yyyy-MM-dd'T'HH:mm:ssxxx"
        return df.date(from: string)
    }

    deinit {
        timer?.invalidate()
    }
}

import Foundation
import Combine

/// File logger — appends to /tmp/ClaudeUsage.log (max 500KB, auto-rotated).
private func cuLog(_ msg: String) {
    let ts = ISO8601DateFormatter.string(from: Date(), timeZone: .current, formatOptions: [.withFullDate, .withFullTime, .withFractionalSeconds])
    let line = "\(ts) [CU] \(msg)\n"
    NSLog("[CU] %@", msg)
    let path = "/tmp/ClaudeUsage.log"
    // Rotate if > 500KB
    if let attrs = try? FileManager.default.attributesOfItem(atPath: path),
       let size = attrs[.size] as? UInt64, size > 500_000 {
        try? FileManager.default.removeItem(atPath: path + ".old")
        try? FileManager.default.moveItem(atPath: path, toPath: path + ".old")
    }
    if let data = line.data(using: .utf8) {
        if FileManager.default.fileExists(atPath: path),
           let fh = FileHandle(forWritingAtPath: path) {
            fh.seekToEndOfFile()
            fh.write(data)
            fh.closeFile()
        } else {
            FileManager.default.createFile(atPath: path, contents: data)
        }
    }
}

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
        guard !isLoading else {
            cuLog("fetchUsage skipped, already in progress")
            return
        }
        cuLog("fetchUsage called, interval=\(Int(refreshInterval))")
        guard let credentials = KeychainHelper.readClaudeOAuthToken() else {
            cuLog("EXIT: no credentials")
            usage.error = "No OAuth token found. Make sure you're logged into Claude Code."
            return
        }

        // If token is expiring, clear cache to re-read from Keychain
        // (Claude Code extension keeps the token fresh in Keychain)
        var activeCredentials = credentials
        if let expiresAt = credentials.expiresAt, expiresAt.timeIntervalSinceNow < 60 {
            cuLog("Token expiring, re-reading from Keychain...")
            KeychainHelper.clearCache()
            if let fresh = KeychainHelper.readClaudeOAuthToken() {
                activeCredentials = fresh
                cuLog("Got fresh token from Keychain")
            } else {
                cuLog("EXIT: no fresh token in Keychain")
                usage.error = "Token expired. Open Claude Code or run 'claude' to refresh."
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
                cuLog("EXIT: invalid response object")
                usage.error = "Invalid response"
                return
            }

            cuLog("HTTP \(httpResponse.statusCode)")

            if httpResponse.statusCode == 401 {
                // Re-read from Keychain in case Claude Code refreshed the token
                KeychainHelper.clearCache()
                if let fresh = KeychainHelper.readClaudeOAuthToken() {
                    var retryRequest = request
                    retryRequest.setValue("Bearer \(fresh.accessToken)", forHTTPHeaderField: "Authorization")
                    if let (data2, resp2) = try? await URLSession.shared.data(for: retryRequest),
                       let http2 = resp2 as? HTTPURLResponse, http2.statusCode == 200,
                       let json2 = try? JSONSerialization.jsonObject(with: data2) as? [String: Any] {
                        parseUsageResponse(json2)
                        usage.lastFetched = Date()
                        usage.error = nil
                        cuLog("401→re-read→OK session=\(Int(usage.sessionPercent))% weekly=\(Int(usage.weeklyPercent))%")
                        if refreshInterval != defaultInterval {
                            refreshInterval = defaultInterval
                            startPolling()
                        }
                        return
                    }
                }
                cuLog("EXIT: 401 unrecoverable")
                usage.error = "Token expired. Open Claude Code or run 'claude' to refresh."
                return
            }

            if httpResponse.statusCode == 429 {
                let retryAfterHeader = Int(httpResponse.value(forHTTPHeaderField: "Retry-After") ?? "") ?? 10
                let retryDelay = max(retryAfterHeader, 10) + Int.random(in: 0...15)
                cuLog("429 — sleeping \(retryDelay)s before retry")
                try? await Task.sleep(nanoseconds: UInt64(retryDelay) * 1_000_000_000)
                do {
                    let (data2, response2) = try await URLSession.shared.data(for: request)
                    if let http2 = response2 as? HTTPURLResponse, http2.statusCode == 200,
                       let json2 = try JSONSerialization.jsonObject(with: data2) as? [String: Any] {
                        parseUsageResponse(json2)
                        usage.lastFetched = Date()
                        usage.error = nil
                        cuLog("429→retry→OK session=\(Int(usage.sessionPercent))% weekly=\(Int(usage.weeklyPercent))%")
                        if refreshInterval != defaultInterval {
                            refreshInterval = defaultInterval
                            startPolling()
                        }
                        return
                    } else if let http2 = response2 as? HTTPURLResponse {
                        cuLog("429→retry→HTTP \(http2.statusCode)")
                    }
                } catch {
                    cuLog("429→retry→error: \(error.localizedDescription)")
                }

                refreshInterval = min(refreshInterval * 2, maxInterval)
                cuLog("EXIT: 429 backoff, next interval=\(Int(refreshInterval))")
                startPolling(fetchImmediately: false)
                if usage.lastFetched == nil {
                    usage.error = "Rate limited — retrying in \(Int(refreshInterval))s"
                }
                return
            }

            guard httpResponse.statusCode == 200 else {
                cuLog("EXIT: unexpected HTTP \(httpResponse.statusCode)")
                usage.error = "API error: HTTP \(httpResponse.statusCode)"
                return
            }

            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                cuLog("EXIT: JSON parse failed")
                usage.error = "Failed to parse response"
                return
            }

            parseUsageResponse(json)
            usage.lastFetched = Date()
            usage.error = nil
            cuLog("OK session=\(Int(usage.sessionPercent))% weekly=\(Int(usage.weeklyPercent))%")

            if refreshInterval != defaultInterval {
                refreshInterval = defaultInterval
                startPolling()
            }

        } catch {
            cuLog("Network error: \(error.localizedDescription), retrying in 3s...")
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            do {
                let (data2, response2) = try await URLSession.shared.data(for: request)
                if let http2 = response2 as? HTTPURLResponse, http2.statusCode == 200,
                   let json2 = try JSONSerialization.jsonObject(with: data2) as? [String: Any] {
                    parseUsageResponse(json2)
                    usage.lastFetched = Date()
                    usage.error = nil
                    cuLog("network→retry→OK session=\(Int(usage.sessionPercent))% weekly=\(Int(usage.weeklyPercent))%")
                    if refreshInterval != defaultInterval {
                        refreshInterval = defaultInterval
                        startPolling()
                    }
                    return
                } else if let http2 = response2 as? HTTPURLResponse {
                    cuLog("network→retry→HTTP \(http2.statusCode)")
                }
            } catch {
                cuLog("network→retry→error: \(error.localizedDescription)")
            }

            refreshInterval = min(refreshInterval * 2, maxInterval)
            cuLog("EXIT: network backoff, next interval=\(Int(refreshInterval))")
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

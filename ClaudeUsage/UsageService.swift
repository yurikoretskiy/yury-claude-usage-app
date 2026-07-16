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

/// Credits are not a simple on/off: when the monthly cap is exhausted the API reports
/// `enabled: false` with `disabled_reason: "org_level_disabled_until"` even though the
/// user's claude.ai toggle is still ON — mapping that to "Off" showed the opposite of
/// the truth. Keep it a distinct state.
enum CreditsState: String {
    case on
    case limitReached
    case off
}

struct UsageData {
    var sessionPercent: Double = 0
    var sessionResetTime: Date? = nil
    var weeklyPercent: Double = 0
    var weeklyResetTime: Date? = nil
    var modelLimits: [ModelLimit] = []
    var creditsState: CreditsState = .off
    var creditsCritical: Bool = false
    var creditsPercent: Double? = nil
    var creditsUsedDollars: Double? = nil
    var creditsLimitDollars: Double? = nil
    var lastFetched: Date? = nil
    var error: String? = nil
}

@MainActor
class UsageService: ObservableObject {
    @Published var usage = UsageData()
    @Published var isLoading = false

    private var timer: Timer?
    private var refreshInterval: TimeInterval = 60

    /// Read `claude --version` once at startup so User-Agent never goes stale.
    static let claudeVersion: String = {
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/usr/local/bin/claude")
        proc.arguments = ["--version"]
        let pipe = Pipe()
        proc.standardOutput = pipe
        proc.standardError = Pipe()
        do {
            try proc.run()
            proc.waitUntilExit()
            let out = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .split(separator: " ").first.map(String.init) ?? "2.1.76"
            return out
        } catch {
            return "2.1.76"
        }
    }()
    private let defaultInterval: TimeInterval = 60
    private let maxInterval: TimeInterval = 300

    init() {
        loadCachedUsage()
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
        request.setValue("claude-code/\(Self.claudeVersion)", forHTTPHeaderField: "User-Agent")

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
                        saveCachedUsage()
                        cuLog("401→re-read→OK session=\(Int(usage.sessionPercent))% weekly=\(Int(usage.weeklyPercent))%")
                        if refreshInterval != defaultInterval {
                            refreshInterval = defaultInterval
                            startPolling(fetchImmediately: false)
                        }
                        return
                    }
                }
                cuLog("EXIT: 401 unrecoverable")
                usage.error = "Token expired. Open Claude Code or run 'claude' to refresh."
                return
            }

            if httpResponse.statusCode == 429 {
                // Non-blocking 429 handling: schedule retry via timer, never sleep inline.
                // Cap Retry-After to maxInterval (300s) — API can return 3000+s.
                // Use exponential backoff: double current interval, floor at Retry-After.
                let retryAfterHeader = Int(httpResponse.value(forHTTPHeaderField: "Retry-After") ?? "") ?? 10
                let backoff = min(refreshInterval * 2, maxInterval)
                let retryDelay = min(max(backoff, TimeInterval(retryAfterHeader)), maxInterval)
                refreshInterval = retryDelay
                cuLog("EXIT: 429 (Retry-After: \(retryAfterHeader)s), next poll in \(Int(retryDelay))s via timer")
                startPolling(fetchImmediately: false)
                if usage.lastFetched == nil {
                    usage.error = "Rate limited — retrying in \(Int(retryDelay))s"
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
            saveCachedUsage()
            cuLog("OK session=\(Int(usage.sessionPercent))% weekly=\(Int(usage.weeklyPercent))%")

            if refreshInterval != defaultInterval {
                refreshInterval = defaultInterval
                startPolling(fetchImmediately: false)
            }

        } catch {
            cuLog("Network error: \(error.localizedDescription)")
            refreshInterval = min(refreshInterval * 2, maxInterval)
            cuLog("EXIT: network backoff, next interval=\(Int(refreshInterval))")
            startPolling(fetchImmediately: false)
            // Always surface the failure — stale data shown as fresh is worse
            // than a visible warning (popover row + menu bar badge).
            let offlineCodes: [URLError.Code] = [
                .notConnectedToInternet, .networkConnectionLost, .dnsLookupFailed,
                .cannotFindHost, .cannotConnectToHost, .timedOut, .dataNotAllowed
            ]
            if let urlError = error as? URLError, offlineCodes.contains(urlError.code) {
                usage.error = "No internet connection — showing last known data"
            } else {
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

        // Parse per-model weekly limits from the newer `limits[]` array — this is the
        // only place scoped models (e.g. Fable) currently surface; the legacy
        // `seven_day_<model>` keys stay null even when a scoped limit is active.
        var models: [ModelLimit] = []
        if let limits = json["limits"] as? [[String: Any]] {
            for item in limits {
                guard (item["group"] as? String) == "weekly",
                      let scope = item["scope"] as? [String: Any],
                      let model = scope["model"] as? [String: Any],
                      let label = model["display_name"] as? String,
                      let percent = asDouble(item["percent"]) else { continue }
                let resetTime: Date? = (item["resets_at"] as? String).flatMap { parseDate($0) }
                models.append(ModelLimit(label: label, percent: percent, resetTime: resetTime))
            }
        }

        // Fallback: legacy seven_day_* prefix scan, for API responses without `limits[]`.
        if models.isEmpty {
            for (key, value) in json {
                guard key.hasPrefix("seven_day_"),
                      let dict = value as? [String: Any],
                      let util = dict["utilization"] as? Double else { continue }
                let label = key.replacingOccurrences(of: "seven_day_", with: "")
                                .replacingOccurrences(of: "_", with: " ").capitalized
                let resetTime: Date? = (dict["resets_at"] as? String).flatMap { parseDate($0) }
                models.append(ModelLimit(label: label, percent: util, resetTime: resetTime))
            }
        }
        usage.modelLimits = models.sorted { $0.label < $1.label }

        // Parse usage credits — prefer `spend` (percent + enabled + dollar figures),
        // fall back to `extra_usage`. Balance and auto-reload state aren't in this API
        // at all (both come back null), so they're never shown.
        if let spend = json["spend"] as? [String: Any] {
            let state = creditsState(
                enabled: (spend["enabled"] as? Bool) ?? false,
                disabledReason: spend["disabled_reason"] as? String
            )
            usage.creditsState = state
            usage.creditsCritical = (spend["severity"] as? String) == "critical"
            applyCreditsNumbers(
                state: state,
                percent: asDouble(spend["percent"]),
                used: dollarAmount(spend["used"] as? [String: Any]),
                limit: dollarAmount(spend["limit"] as? [String: Any])
            )
        } else if let extra = json["extra_usage"] as? [String: Any] {
            let state = creditsState(
                enabled: (extra["is_enabled"] as? Bool) ?? false,
                disabledReason: extra["disabled_reason"] as? String
            )
            usage.creditsState = state
            usage.creditsCritical = (asDouble(extra["utilization"]) ?? 0) >= 90
            applyCreditsNumbers(
                state: state,
                percent: asDouble(extra["utilization"]),
                used: asDouble(extra["used_credits"]),
                limit: asDouble(extra["monthly_limit"])
            )
        } else {
            usage.creditsState = .off
            usage.creditsCritical = false
            usage.creditsPercent = nil
            usage.creditsUsedDollars = nil
            usage.creditsLimitDollars = nil
        }
    }

    /// Two display corrections Yury asked for:
    /// - Toggled OFF: the API nulls all consumption data (`used: 0, limit: null`), but the
    ///   month's spend didn't vanish — keep the last known numbers (cache survives restarts)
    ///   instead of overwriting with zeros.
    /// - Limit reached: the OAuth spend counter lags web billing (showed 92% while claude.ai
    ///   showed 100%), but exhausted means exhausted — pin the display to 100% / $limit.
    private func applyCreditsNumbers(state: CreditsState, percent: Double?, used: Double?, limit: Double?) {
        switch state {
        case .off where limit == nil:
            break // retain last known values
        case .limitReached:
            usage.creditsPercent = 100
            usage.creditsLimitDollars = limit ?? usage.creditsLimitDollars
            usage.creditsUsedDollars = usage.creditsLimitDollars ?? used
        default:
            usage.creditsPercent = percent
            usage.creditsUsedDollars = used
            usage.creditsLimitDollars = limit
        }
    }

    private func creditsState(enabled: Bool, disabledReason: String?) -> CreditsState {
        if enabled { return .on }
        // "org_level_disabled_until" = spending suspended because the cap was exhausted,
        // not because the user toggled credits off.
        if disabledReason == "org_level_disabled_until" { return .limitReached }
        return .off
    }

    private func dollarAmount(_ obj: [String: Any]?) -> Double? {
        guard let obj, let minor = asDouble(obj["amount_minor"]) else { return nil }
        let exponent = (obj["exponent"] as? Int) ?? 2
        return minor / pow(10, Double(exponent))
    }

    /// JSONSerialization can hand back a whole-number percent (e.g. `81`) as an Int-backed
    /// NSNumber, which a plain `as? Double` cast silently fails on — normalize through NSNumber.
    private func asDouble(_ value: Any?) -> Double? {
        (value as? NSNumber)?.doubleValue
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

    // MARK: - Persist last-known-good data across launches

    private func saveCachedUsage() {
        let defaults = UserDefaults.standard
        defaults.set(usage.sessionPercent, forKey: "cu_sessionPercent")
        defaults.set(usage.weeklyPercent, forKey: "cu_weeklyPercent")
        defaults.set(usage.sessionResetTime?.timeIntervalSince1970, forKey: "cu_sessionResetTime")
        defaults.set(usage.weeklyResetTime?.timeIntervalSince1970, forKey: "cu_weeklyResetTime")
        defaults.set(usage.lastFetched?.timeIntervalSince1970, forKey: "cu_lastFetched")
        // Save model limits as array of dicts
        let models = usage.modelLimits.map { m -> [String: Any] in
            var d: [String: Any] = ["label": m.label, "percent": m.percent]
            if let rt = m.resetTime { d["resetTime"] = rt.timeIntervalSince1970 }
            return d
        }
        defaults.set(models, forKey: "cu_modelLimits")
        defaults.set(usage.creditsState.rawValue, forKey: "cu_creditsState")
        defaults.set(usage.creditsCritical, forKey: "cu_creditsCritical")
        if let cp = usage.creditsPercent {
            defaults.set(cp, forKey: "cu_creditsPercent")
        } else {
            defaults.removeObject(forKey: "cu_creditsPercent")
        }
        if let used = usage.creditsUsedDollars {
            defaults.set(used, forKey: "cu_creditsUsedDollars")
        } else {
            defaults.removeObject(forKey: "cu_creditsUsedDollars")
        }
        if let limit = usage.creditsLimitDollars {
            defaults.set(limit, forKey: "cu_creditsLimitDollars")
        } else {
            defaults.removeObject(forKey: "cu_creditsLimitDollars")
        }
    }

    private func loadCachedUsage() {
        let defaults = UserDefaults.standard
        guard defaults.object(forKey: "cu_sessionPercent") != nil else { return }
        usage.sessionPercent = defaults.double(forKey: "cu_sessionPercent")
        usage.weeklyPercent = defaults.double(forKey: "cu_weeklyPercent")
        if let ts = defaults.object(forKey: "cu_sessionResetTime") as? TimeInterval {
            usage.sessionResetTime = Date(timeIntervalSince1970: ts)
        }
        if let ts = defaults.object(forKey: "cu_weeklyResetTime") as? TimeInterval {
            usage.weeklyResetTime = Date(timeIntervalSince1970: ts)
        }
        if let ts = defaults.object(forKey: "cu_lastFetched") as? TimeInterval {
            usage.lastFetched = Date(timeIntervalSince1970: ts)
        }
        if let models = defaults.array(forKey: "cu_modelLimits") as? [[String: Any]] {
            usage.modelLimits = models.compactMap { d in
                guard let label = d["label"] as? String, let percent = d["percent"] as? Double else { return nil }
                let resetTime = (d["resetTime"] as? TimeInterval).map { Date(timeIntervalSince1970: $0) }
                return ModelLimit(label: label, percent: percent, resetTime: resetTime)
            }
        }
        if let raw = defaults.string(forKey: "cu_creditsState"),
           let state = CreditsState(rawValue: raw) {
            usage.creditsState = state
        }
        usage.creditsCritical = defaults.bool(forKey: "cu_creditsCritical")
        if defaults.object(forKey: "cu_creditsPercent") != nil {
            usage.creditsPercent = defaults.double(forKey: "cu_creditsPercent")
        }
        if defaults.object(forKey: "cu_creditsUsedDollars") != nil {
            usage.creditsUsedDollars = defaults.double(forKey: "cu_creditsUsedDollars")
        }
        if defaults.object(forKey: "cu_creditsLimitDollars") != nil {
            usage.creditsLimitDollars = defaults.double(forKey: "cu_creditsLimitDollars")
        }
        cuLog("Loaded cached usage: session=\(Int(usage.sessionPercent))% weekly=\(Int(usage.weeklyPercent))%")
    }

    deinit {
        timer?.invalidate()
    }
}

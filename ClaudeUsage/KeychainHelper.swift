import Foundation

private extension Data {
    init?(hexString: String) {
        let len = hexString.count
        guard len % 2 == 0 else { return nil }
        var data = Data(capacity: len / 2)
        var index = hexString.startIndex
        while index < hexString.endIndex {
            let nextIndex = hexString.index(index, offsetBy: 2)
            guard let byte = UInt8(hexString[index..<nextIndex], radix: 16) else { return nil }
            data.append(byte)
            index = nextIndex
        }
        self = data
    }
}

struct OAuthCredentials {
    let accessToken: String
    let refreshToken: String
    let expiresAt: Date?
}

enum KeychainHelper {
    /// Cached token to avoid repeated keychain reads
    private static var cachedCredentials: OAuthCredentials?
    private static var cacheTime: Date?

    /// Path to Claude Code's credentials file — the canonical token source.
    private static let credentialsFilePath = NSString("~/.claude/.credentials.json").expandingTildeInPath

    static func readClaudeOAuthToken() -> OAuthCredentials? {
        // Return cached token if less than 5 minutes old
        if let cached = cachedCredentials, let cacheTime = cacheTime,
           Date().timeIntervalSince(cacheTime) < 300 {
            return cached
        }

        // PRIMARY: read from ~/.claude/.credentials.json (same source Claude Code uses)
        if let creds = readFromCredentialsFile() {
            cachedCredentials = creds
            cacheTime = Date()
            return creds
        }

        // FALLBACK: read from macOS Keychain
        if let creds = readFromKeychain() {
            cachedCredentials = creds
            cacheTime = Date()
            return creds
        }

        return nil
    }

    /// Read credentials from ~/.claude/.credentials.json
    private static func readFromCredentialsFile() -> OAuthCredentials? {
        guard let data = FileManager.default.contents(atPath: credentialsFilePath),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }
        return extractCredentials(from: json)
    }

    /// Read credentials from macOS Keychain — searches ALL entries with service
    /// "Claude Code-credentials" and picks the one with the freshest non-expired token.
    /// This is future-proof: if the CLI changes the account name again, we still find it.
    private static func readFromKeychain() -> OAuthCredentials? {
        // Use Security framework to find ALL matching entries
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "Claude Code-credentials",
            kSecReturnData as String: true,
            kSecReturnAttributes as String: true,
            kSecMatchLimit as String: kSecMatchLimitAll
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess,
              let items = result as? [[String: Any]] else {
            return nil
        }

        // Try each entry, pick the one with the latest non-expired token
        var bestCreds: OAuthCredentials? = nil
        var bestExpiry: Date = .distantPast

        for item in items {
            guard let data = item[kSecValueData as String] as? Data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let creds = extractCredentials(from: json) else {
                continue
            }
            let expiry = creds.expiresAt ?? .distantFuture
            if expiry > bestExpiry {
                bestCreds = creds
                bestExpiry = expiry
            }
        }

        return bestCreds
    }

    /// Decode the password line from `security -g` output.
    /// Format is either `password: 0x<HEX><trailing>` or `password: "<string>"`.
    private static func decodeKeychainOutput(_ output: String) -> String? {
        // Hex-encoded password (newer macOS / Claude Code versions)
        if let match = output.range(of: #"password: 0x([0-9A-Fa-f]+)(.*)"#, options: .regularExpression) {
            let line = String(output[match])
            // Extract hex portion
            if let hexRange = line.range(of: #"0x([0-9A-Fa-f]+)"#, options: .regularExpression) {
                let hexWithPrefix = String(line[hexRange])
                let hex = String(hexWithPrefix.dropFirst(2))
                guard let data = Data(hexString: hex),
                      let decoded = String(data: data, encoding: .utf8) else { return nil }
                // Append any trailing text after the hex (security CLI may include it)
                let afterHex = String(line[hexRange.upperBound...])
                return decoded + afterHex
            }
        }
        // Plain string password
        if let match = output.range(of: #"password: "(.*)""#, options: .regularExpression) {
            let line = String(output[match])
            let start = line.index(line.startIndex, offsetBy: 11) // skip `password: "`
            let end = line.index(before: line.endIndex)            // skip trailing `"`
            return String(line[start..<end])
        }
        return nil
    }

    /// Extract credentials via regex when JSON is truncated.
    private static func extractCredentialsViaRegex(from text: String) -> OAuthCredentials? {
        guard let tokenMatch = text.range(of: #""accessToken"\s*:\s*"(sk-ant-[^"]+)""#, options: .regularExpression) else {
            print("Missing accessToken in keychain data")
            return nil
        }
        // Extract the token value from the match
        let matchStr = String(text[tokenMatch])
        guard let valueStart = matchStr.range(of: "sk-ant-"),
              let valueEnd = matchStr.lastIndex(of: "\"") else { return nil }
        let accessToken = String(matchStr[valueStart.lowerBound..<valueEnd])

        // Try to extract refreshToken
        var refreshToken = ""
        if let rtMatch = text.range(of: #""refreshToken"\s*:\s*"(sk-ant-[^"]+)""#, options: .regularExpression) {
            let rtStr = String(text[rtMatch])
            if let rtStart = rtStr.range(of: "sk-ant-"),
               let rtEnd = rtStr.lastIndex(of: "\"") {
                refreshToken = String(rtStr[rtStart.lowerBound..<rtEnd])
            }
        }

        return OAuthCredentials(accessToken: accessToken, refreshToken: refreshToken, expiresAt: nil)
    }

    /// Clear cached credentials (call when token is expired)
    static func clearCache() {
        cachedCredentials = nil
        cacheTime = nil
    }

    // MARK: - Token Refresh

    private static let oauthTokenURL = URL(string: "https://platform.claude.com/v1/oauth/token")!
    private static let oauthClientID = "9d1c250a-e61b-44d9-88ed-5944d1962f5e"

    /// Refresh the OAuth access token using the refresh token.
    /// Updates credentials file + Keychain, clears cache, returns new credentials.
    static func refreshAccessToken() async -> OAuthCredentials? {
        // Read current credentials to get refreshToken
        guard let data = FileManager.default.contents(atPath: credentialsFilePath),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let oauth = json["claudeAiOauth"] as? [String: Any],
              let refreshToken = oauth["refreshToken"] as? String,
              !refreshToken.isEmpty else {
            print("[ClaudeUsage] No refresh token available")
            return nil
        }

        // POST to token endpoint
        var request = URLRequest(url: oauthTokenURL)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.setValue("claude-code/2.1.63", forHTTPHeaderField: "User-Agent")

        let body = "grant_type=refresh_token&refresh_token=\(refreshToken)&client_id=\(oauthClientID)"
        request.httpBody = body.data(using: .utf8)

        do {
            let (responseData, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200,
                  let result = try? JSONSerialization.jsonObject(with: responseData) as? [String: Any],
                  let newAccess = result["access_token"] as? String else {
                print("[ClaudeUsage] Token refresh failed")
                return nil
            }

            let newRefresh = result["refresh_token"] as? String ?? refreshToken
            let expiresIn = result["expires_in"] as? Double ?? 3600
            let expiresAtMs = Int((Date().timeIntervalSince1970 + expiresIn) * 1000)

            // Update credentials file
            var fullJson = json
            var oauthDict = oauth
            oauthDict["accessToken"] = newAccess
            oauthDict["refreshToken"] = newRefresh
            oauthDict["expiresAt"] = expiresAtMs
            fullJson["claudeAiOauth"] = oauthDict

            if let updatedData = try? JSONSerialization.data(withJSONObject: fullJson, options: [.sortedKeys]) {
                try? updatedData.write(to: URL(fileURLWithPath: credentialsFilePath))
            }

            // Update Keychain
            let keychainPayload = #"{"accessToken":"\#(newAccess)","refreshToken":"\#(newRefresh)","expiresAt":\#(expiresAtMs)}"#
            let kcProcess = Process()
            kcProcess.executableURL = URL(fileURLWithPath: "/usr/bin/security")
            kcProcess.arguments = ["add-generic-password", "-U",
                                   "-s", "Claude Code-credentials",
                                   "-a", "Claude Code-credentials",
                                   "-w", keychainPayload]
            kcProcess.standardOutput = Pipe()
            kcProcess.standardError = Pipe()
            try? kcProcess.run()
            kcProcess.waitUntilExit()

            // Clear cache so next read picks up new token
            clearCache()

            let expiresAt = Date(timeIntervalSince1970: Double(expiresAtMs) / 1000)
            let creds = OAuthCredentials(accessToken: newAccess, refreshToken: newRefresh, expiresAt: expiresAt)
            cachedCredentials = creds
            cacheTime = Date()
            return creds

        } catch {
            print("[ClaudeUsage] Token refresh error: \(error)")
            return nil
        }
    }

    private static func extractCredentials(from json: [String: Any]) -> OAuthCredentials? {
        // Try nested format first (legacy): {"claudeAiOauth": {"accessToken": ...}}
        if let oauth = json["claudeAiOauth"] as? [String: Any],
           let accessToken = oauth["accessToken"] as? String {
            return parseOAuthFields(from: oauth, accessToken: accessToken)
        }

        // Flat format (current): {"accessToken": "sk-ant-..."}
        if let accessToken = json["accessToken"] as? String {
            return parseOAuthFields(from: json, accessToken: accessToken)
        }

        print("Missing accessToken in keychain data")
        return nil
    }

    private static func parseOAuthFields(from dict: [String: Any], accessToken: String) -> OAuthCredentials {
        let refreshToken = dict["refreshToken"] as? String ?? ""
        var expiresAt: Date? = nil
        if let expiresAtStr = dict["expiresAt"] as? String {
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            expiresAt = formatter.date(from: expiresAtStr)
        } else if let expiresAtNum = dict["expiresAt"] as? TimeInterval {
            expiresAt = Date(timeIntervalSince1970: expiresAtNum / 1000)
        }
        return OAuthCredentials(accessToken: accessToken, refreshToken: refreshToken, expiresAt: expiresAt)
    }
}

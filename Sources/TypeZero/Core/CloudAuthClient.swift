import Foundation

public struct CloudUserProfile: Codable, Equatable, Sendable {
    public let id: String
    public let email: String
    public let balanceCny: Double
    public let balanceMicroCny: Int64?
    public let totalUsedCny: Double
    public let asrSecondsUsed: Int
    public let llmRequestsUsed: Int
    public let trialGranted: Bool
    public let isBanned: Bool
    public let createdAt: Int64?
}

public struct CloudCapabilities: Codable, Equatable, Sendable {
    public let ok: Bool
    public let googleOAuthEnabled: Bool
    public let smtpEnabled: Bool
    public let volcAsrReady: Bool
    public let deepseekReady: Bool
    public let trialSignupEnabled: Bool
    public let trialBonusCny: Double
}

public struct CloudAuthSuccess: Codable, Sendable {
    public let ok: Bool
    public let token: String
    public let isNew: Bool?
    public let grantedTrial: Bool?
    public let user: CloudUserProfile
}

public struct CloudGoogleStartResponse: Codable, Sendable {
    public let ok: Bool
    public let sessionId: String
    public let authUrl: String
}

public struct CloudGooglePollResponse: Codable, Sendable {
    public let status: String
    public let token: String?
    public let user: CloudUserProfile?
    public let grantedTrial: Bool?
    public let error: String?
}

public struct CloudVoucherProfile: Codable, Equatable, Sendable {
    public let code: String
    public let note: String
    public let quotaSeconds: Double
    public let usedSeconds: Double
    public let remainingSeconds: Double
    public let quotaMinutes: Double
    public let usedMinutes: Double
    public let remainingMinutes: Double
    public let sessionCount: Int
    public let status: String
    public let exhausted: Bool
    public let revoked: Bool
}

private struct CloudVoucherStatusResponse: Codable {
    let ok: Bool
    let asrReady: Bool
    let voucher: CloudVoucherProfile
}

private struct CloudMeResponse: Codable {
    let ok: Bool
    let user: CloudUserProfile
}

private struct CloudErrorResponse: Codable {
    let error: String?
    let message: String?
}

public enum CloudAuthError: LocalizedError {
    case invalidURL
    case serverError(String)

    public var errorDescription: String? {
        switch self {
        case .invalidURL: return "云端服务地址无效"
        case .serverError(let msg): return msg
        }
    }
}

public enum CloudAuthClient {
    public static let baseURL = "https://typezero.mykkai.com"
    public static let cloudASRWSURL = "wss://typezero.mykkai.com/api/asr/ws"
    public static let cloudLLMBaseURL = "https://typezero.mykkai.com/api/llm/v1"

    private static let deviceIdKey = "tz_cloud_device_fingerprint_v1"

    public static var persistentDeviceId: String {
        if let existing = UserDefaults.standard.string(forKey: deviceIdKey), !existing.isEmpty {
            return existing
        }
        let fresh = "mac-" + UUID().uuidString.lowercased()
        UserDefaults.standard.set(fresh, forKey: deviceIdKey)
        return fresh
    }

    private static let session: URLSession = {
        let cfg = URLSessionConfiguration.ephemeral
        cfg.timeoutIntervalForRequest = 12.0
        cfg.timeoutIntervalForResource = 20.0
        return URLSession(configuration: cfg)
    }()

    public static func fetchCapabilities() async throws -> CloudCapabilities {
        guard let url = URL(string: "\(baseURL)/api/health") else { throw CloudAuthError.invalidURL }
        let (data, resp) = try await session.data(from: url)
        try validateHTTP(resp, data: data)
        return try JSONDecoder().decode(CloudCapabilities.self, from: data)
    }

    public static func sendEmailCode(email: String) async throws -> String {
        guard let url = URL(string: "\(baseURL)/api/auth/email/send-code") else { throw CloudAuthError.invalidURL }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONSerialization.data(withJSONObject: ["email": email])
        let (data, resp) = try await session.data(for: req)
        try validateHTTP(resp, data: data)
        if let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let msg = obj["message"] as? String {
            return msg
        }
        return "验证码已发送，请查收邮箱"
    }

    public static func verifyEmailCode(email: String, code: String) async throws -> CloudAuthSuccess {
        guard let url = URL(string: "\(baseURL)/api/auth/email/verify") else { throw CloudAuthError.invalidURL }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONSerialization.data(withJSONObject: [
            "email": email,
            "code": code,
            "deviceId": persistentDeviceId,
            "platform": "macos"
        ])
        let (data, resp) = try await session.data(for: req)
        try validateHTTP(resp, data: data)
        return try JSONDecoder().decode(CloudAuthSuccess.self, from: data)
    }

    public static func startGoogleLogin() async throws -> CloudGoogleStartResponse {
        guard let url = URL(string: "\(baseURL)/api/auth/google/start") else { throw CloudAuthError.invalidURL }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONSerialization.data(withJSONObject: [
            "deviceId": persistentDeviceId,
            "platform": "macos"
        ])
        let (data, resp) = try await session.data(for: req)
        try validateHTTP(resp, data: data)
        return try JSONDecoder().decode(CloudGoogleStartResponse.self, from: data)
    }

    public static func pollGoogleLogin(sessionId: String) async throws -> CloudGooglePollResponse {
        guard let encoded = sessionId.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "\(baseURL)/api/auth/google/poll?session=\(encoded)") else {
            throw CloudAuthError.invalidURL
        }
        let (data, resp) = try await session.data(from: url)
        if let http = resp as? HTTPURLResponse, http.statusCode == 404 {
            return CloudGooglePollResponse(status: "expired", token: nil, user: nil, grantedTrial: nil, error: "登录会话已过期")
        }
        if let decoded = try? JSONDecoder().decode(CloudGooglePollResponse.self, from: data) {
            return decoded
        }
        try validateHTTP(resp, data: data)
        throw CloudAuthError.serverError("Google 登录状态解析失败")
    }

    public static func normalizedVoucherCode(_ raw: String) -> String {
        raw.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
    }

    public static func isVoucherCode(_ raw: String) -> Bool {
        let clean = normalizedVoucherCode(raw)
        guard clean.hasPrefix("TZ-"), clean.count >= 10 else { return false }
        return clean.allSatisfy { $0.isASCII && ($0.isUppercase || $0.isNumber || $0 == "-") }
    }

    public static func fetchVoucherStatus(code: String) async throws -> (asrReady: Bool, voucher: CloudVoucherProfile) {
        let clean = normalizedVoucherCode(code)
        guard isVoucherCode(clean) else {
            throw CloudAuthError.serverError("兑换码格式无效（应类似 TZ-XXXX-XXXX）")
        }
        guard let url = URL(string: "\(baseURL)/api/voucher/status") else { throw CloudAuthError.invalidURL }
        var req = URLRequest(url: url)
        req.setValue("Bearer \(clean)", forHTTPHeaderField: "Authorization")
        let (data, resp) = try await session.data(for: req)
        try validateHTTP(resp, data: data)
        let decoded = try JSONDecoder().decode(CloudVoucherStatusResponse.self, from: data)
        return (decoded.asrReady, decoded.voucher)
    }

    public static func fetchProfile(token: String) async throws -> CloudUserProfile {
        guard let url = URL(string: "\(baseURL)/api/me") else { throw CloudAuthError.invalidURL }
        var req = URLRequest(url: url)
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        let (data, resp) = try await session.data(for: req)
        try validateHTTP(resp, data: data)
        let decoded = try JSONDecoder().decode(CloudMeResponse.self, from: data)
        return decoded.user
    }

    private static func validateHTTP(_ response: URLResponse, data: Data) throws {
        guard let http = response as? HTTPURLResponse else {
            throw CloudAuthError.serverError("无法连接 TypeZero 云端服务")
        }
        guard (200...299).contains(http.statusCode) else {
            if let errObj = try? JSONDecoder().decode(CloudErrorResponse.self, from: data),
               let msg = errObj.error ?? errObj.message, !msg.isEmpty {
                throw CloudAuthError.serverError(msg)
            }
            throw CloudAuthError.serverError("服务返回 HTTP \(http.statusCode)")
        }
    }
}

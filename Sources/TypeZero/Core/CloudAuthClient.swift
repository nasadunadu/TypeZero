import Foundation
import CryptoKit
import IOKit

public struct CloudTrialSummary: Codable, Equatable, Sendable {
    public let status: String // "active" | "low" | "exhausted" | "expired" | "not_granted"
    public let canUseAsr: Bool?
    public let canUseLlm: Bool?
    public let remainingPercent: Int
    public let daysRemaining: Int?
    public let expiresAt: String?
    public let asrUsedMinutes: Double
    public let asrQuotaMinutes: Int
    public let asrRemainingMinutes: Double
    public let llmUsedCount: Int
    public let llmQuotaCount: Int
    public let llmRemainingCount: Int

    public var isUsable: Bool {
        if let asr = canUseAsr { return asr }
        return status == "active" || status == "low"
    }

    public var isLow: Bool {
        status == "low"
    }

    public var isEnded: Bool {
        status == "exhausted" || status == "expired"
    }

    public var isExpired: Bool {
        status == "expired"
    }
}

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
    public let createdAt: String?
    public let trial: CloudTrialSummary?

    enum CodingKeys: String, CodingKey {
        case id, email, balanceCny, balanceMicroCny, totalUsedCny
        case asrSecondsUsed, llmRequestsUsed, trialGranted, isBanned, createdAt, trial
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        email = try c.decode(String.self, forKey: .email)
        balanceCny = try c.decode(Double.self, forKey: .balanceCny)
        balanceMicroCny = try c.decodeIfPresent(Int64.self, forKey: .balanceMicroCny)
        totalUsedCny = try c.decode(Double.self, forKey: .totalUsedCny)
        asrSecondsUsed = try c.decode(Int.self, forKey: .asrSecondsUsed)
        llmRequestsUsed = try c.decode(Int.self, forKey: .llmRequestsUsed)
        trialGranted = try c.decode(Bool.self, forKey: .trialGranted)
        isBanned = try c.decode(Bool.self, forKey: .isBanned)
        if let str = try? c.decodeIfPresent(String.self, forKey: .createdAt) {
            createdAt = str
        } else if let ts = try? c.decodeIfPresent(Int64.self, forKey: .createdAt) {
            createdAt = String(ts)
        } else {
            createdAt = nil
        }
        trial = try c.decodeIfPresent(CloudTrialSummary.self, forKey: .trial)
    }

    /// Unified semantic trial view — uses server `trial` payload when present and gracefully falls back for older gateways.
    public var effectiveTrial: CloudTrialSummary {
        if let trial { return trial }
        if !trialGranted && balanceCny <= 0 {
            return CloudTrialSummary(
                status: "not_granted", canUseAsr: false, canUseLlm: false,
                remainingPercent: 0, daysRemaining: 0, expiresAt: nil,
                asrUsedMinutes: Double(asrSecondsUsed) / 60.0, asrQuotaMinutes: 300, asrRemainingMinutes: 0,
                llmUsedCount: llmRequestsUsed, llmQuotaCount: 1500, llmRemainingCount: 0
            )
        }
        let totalCny = max(balanceCny + totalUsedCny, 3.0)
        let pct = balanceCny <= 0 ? 0 : max(1, min(100, Int((balanceCny / totalCny * 100.0).rounded())))
        let usedMin = Double(asrSecondsUsed) / 60.0
        let remMin = max(0, 300.0 - usedMin)
        let remLlm = max(0, 1500 - llmRequestsUsed)
        let st = (balanceCny <= 0 || isBanned) ? "exhausted" : (pct <= 20 ? "low" : "active")
        return CloudTrialSummary(
            status: st, canUseAsr: balanceCny > 0 && !isBanned, canUseLlm: balanceCny > 0 && !isBanned,
            remainingPercent: pct, daysRemaining: nil, expiresAt: nil,
            asrUsedMinutes: usedMin, asrQuotaMinutes: 300, asrRemainingMinutes: remMin,
            llmUsedCount: llmRequestsUsed, llmQuotaCount: 1500, llmRemainingCount: remLlm
        )
    }
}

public struct CloudCapabilities: Codable, Equatable, Sendable {
    public let ok: Bool
    public let googleOAuthEnabled: Bool
    public let smtpEnabled: Bool
    public let volcAsrReady: Bool
    public let deepseekReady: Bool
    public let cloudEngineReady: Bool?
    public let trialSignupEnabled: Bool
    public let trialBonusCny: Double
    public let trialDurationDays: Int?
    public let trialAsrMinutes: Int?
    public let trialLlmCount: Int?
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

    // Official website BYOK onboarding guides (deep-link anchors)
    public static let byokGuideURL = URL(string: "https://typezero.mykkai.com/guide/")!
    public static let doubaoGuideURL = URL(string: "https://typezero.mykkai.com/guide/#doubao")!
    public static let deepseekGuideURL = URL(string: "https://typezero.mykkai.com/guide/#deepseek")!
    public static let byokFAQURL = URL(string: "https://typezero.mykkai.com/guide/#faq")!

    private static let deviceIdKey = "tz_cloud_device_fingerprint_v1"

    /// Stable, one-way hashed hardware fingerprint (`IOPlatformUUID` -> SHA-256) to prevent repeated free-trial farming
    /// by deleting UserDefaults. Falls back to persisted random UUID only if hardware UUID is unavailable.
    public static var persistentDeviceId: String {
        if let hwUUID = readHardwarePlatformUUID(), !hwUUID.isEmpty {
            let digest = SHA256.hash(data: Data("typezero-mac-hw-v2:\(hwUUID)".utf8))
            let hex = digest.map { String(format: "%02x", $0) }.joined()
            return "mac-hw-" + String(hex.prefix(40))
        }
        if let existing = UserDefaults.standard.string(forKey: deviceIdKey), !existing.isEmpty {
            return existing
        }
        let fresh = "mac-" + UUID().uuidString.lowercased()
        UserDefaults.standard.set(fresh, forKey: deviceIdKey)
        return fresh
    }

    private static func readHardwarePlatformUUID() -> String? {
        let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("IOPlatformExpertDevice"))
        guard service != 0 else { return nil }
        defer { IOObjectRelease(service) }
        guard let prop = IORegistryEntryCreateCFProperty(service, kIOPlatformUUIDKey as CFString, kCFAllocatorDefault, 0)?.takeRetainedValue() as? String else {
            return nil
        }
        return prop.trimmingCharacters(in: .whitespacesAndNewlines)
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

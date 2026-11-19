import Foundation
import Security

public enum KeychainHelper {
    private static let service = "io.github.typezero.macos"
    private static let legacyAccount = "llm_api_key"
    private static let volcSpeechAccount = "volc_speech_api_key"

    public static func saveVolcSpeechAPIKey(_ key: String) {
        let cleaned = key.trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))
        deleteSlot(volcSpeechAccount)
        guard !cleaned.isEmpty, let data = cleaned.data(using: .utf8) else { return }
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: volcSpeechAccount,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
        ]
        SecItemAdd(query as CFDictionary, nil)
    }

    public static func loadVolcSpeechAPIKey() -> String {
        return readSlot(volcSpeechAccount) ?? ""
    }

    public static func providerSlot(for provider: LLMProviderOption) -> String {
        switch provider {
        case .deepseek: return "deepseek_api_key"
        case .volcengine: return "ark_api_key"
        case .dashscope: return "dashscope_api_key"
        case .custom: return "custom_api_key"
        }
    }

    public static func providerSlot(for baseURL: String) -> String {
        return providerSlot(for: LLMProviderOption.infer(from: baseURL))
    }

    public static func hasSavedAPIKey(for provider: LLMProviderOption) -> Bool {
        return !loadAPIKey(for: provider).trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    public static func saveAPIKey(_ key: String, for provider: LLMProviderOption) {
        saveAPIKeyInSlot(key, slot: providerSlot(for: provider))
    }

    public static func loadAPIKey(for provider: LLMProviderOption) -> String {
        if let envKey = ProcessInfo.processInfo.environment["TYPEZERO_API_KEY"], !envKey.isEmpty {
            return envKey
        }
        let slot = providerSlot(for: provider)
        if let val = readSlot(slot), !val.isEmpty {
            return val
        }
        if slot == "deepseek_api_key", let legacy = readSlot(legacyAccount), !legacy.isEmpty {
            saveAPIKeyInSlot(legacy, slot: slot)
            return legacy
        }
        return ""
    }

    public static func saveAPIKey(_ key: String, for baseURL: String = "https://api.deepseek.com/v1") {
        saveAPIKeyInSlot(key, slot: providerSlot(for: baseURL))
    }

    private static func saveAPIKeyInSlot(_ key: String, slot: String) {
        var cleaned = key.trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))
        if cleaned.lowercased().hasPrefix("bearer ") {
            cleaned = String(cleaned.dropFirst(7)).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        deleteSlot(slot)
        guard !cleaned.isEmpty, let data = cleaned.data(using: .utf8) else { return }

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: slot,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
        ]
        SecItemAdd(query as CFDictionary, nil)
    }

    public static func loadAPIKey(for baseURL: String = "https://api.deepseek.com/v1") -> String {
        return loadAPIKey(for: LLMProviderOption.infer(from: baseURL))
    }

    private static func readSlot(_ account: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess,
              let data = result as? Data,
              let str = String(data: data, encoding: .utf8) else {
            return nil
        }
        return str
    }

    private static func deleteSlot(_ account: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(query as CFDictionary)
    }
}

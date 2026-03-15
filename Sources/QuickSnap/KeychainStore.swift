import Foundation
import Security

enum KeychainStore {
    private static let service = "com.quicksnap.ai"
    private static let openAIAccount = "openai_api_key"

    static func saveOpenAIKey(_ value: String) throws {
        let data = Data(value.utf8)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: openAIAccount
        ]

        SecItemDelete(query as CFDictionary)

        let addQuery: [String: Any] = query.merging([
            kSecValueData as String: data
        ]) { _, new in new }

        let status = SecItemAdd(addQuery as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw KeychainStoreError.saveFailed(status)
        }
    }

    static func loadOpenAIKey() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: openAIAccount,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess,
              let data = item as? Data,
              let string = String(data: data, encoding: .utf8) else {
            return nil
        }
        return string
    }

    static func deleteOpenAIKey() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: openAIAccount
        ]
        SecItemDelete(query as CFDictionary)
    }
}

enum KeychainStoreError: Error {
    case saveFailed(OSStatus)
}

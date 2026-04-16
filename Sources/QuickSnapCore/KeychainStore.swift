import Foundation
import Security

enum KeychainStore {
    private static let service = "com.quicksnap.credentials"

    enum Account {
        static let openAI = "openai_api_key"
        static let githubPAT = "github_pat"
        static let jiraToken = "jira_api_token"
    }

    static func save(_ value: String, account: String) throws {
        let data = Data(value.utf8)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
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

    static func load(account: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
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

    static func delete(account: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(query as CFDictionary)
    }

    static func saveOpenAIKey(_ value: String) throws {
        try save(value, account: Account.openAI)
    }

    static func loadOpenAIKey() -> String? {
        load(account: Account.openAI)
    }

    static func deleteOpenAIKey() {
        delete(account: Account.openAI)
    }

    static func saveGitHubPAT(_ value: String) throws {
        try save(value, account: Account.githubPAT)
    }

    static func loadGitHubPAT() -> String? {
        load(account: Account.githubPAT)
    }

    static func deleteGitHubPAT() {
        delete(account: Account.githubPAT)
    }

    static func saveJiraToken(_ value: String) throws {
        try save(value, account: Account.jiraToken)
    }

    static func loadJiraToken() -> String? {
        load(account: Account.jiraToken)
    }

    static func deleteJiraToken() {
        delete(account: Account.jiraToken)
    }
}

enum KeychainStoreError: Error {
    case saveFailed(OSStatus)
}

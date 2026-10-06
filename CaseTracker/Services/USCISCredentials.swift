import Foundation
import Security

/// USCIS API client ID and secret, stored in the Keychain.
struct USCISCredentials: Equatable {
    var clientId: String
    var clientSecret: String

    private static let service = "com.pushkarravi.CaseTracker.uscis"
    private static let clientIdAccount = "clientId"
    private static let clientSecretAccount = "clientSecret"

    static func load() -> USCISCredentials? {
        guard let id = read(clientIdAccount), !id.isEmpty,
              let secret = read(clientSecretAccount), !secret.isEmpty
        else { return nil }
        return USCISCredentials(clientId: id, clientSecret: secret)
    }

    static var isConfigured: Bool { load() != nil }

    func save() {
        Self.write(clientId, account: Self.clientIdAccount)
        Self.write(clientSecret, account: Self.clientSecretAccount)
    }

    static func clear() {
        write(nil, account: clientIdAccount)
        write(nil, account: clientSecretAccount)
    }

    // MARK: - Keychain

    private static func baseQuery(_ account: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
    }

    private static func read(_ account: String) -> String? {
        var query = baseQuery(account)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data
        else { return nil }
        return String(data: data, encoding: .utf8)
    }

    private static func write(_ value: String?, account: String) {
        SecItemDelete(baseQuery(account) as CFDictionary)
        guard let value, !value.isEmpty else { return }
        var query = baseQuery(account)
        query[kSecValueData as String] = Data(value.utf8)
        // Background refresh can run while the phone is locked, after the first unlock.
        query[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        SecItemAdd(query as CFDictionary, nil)
    }
}

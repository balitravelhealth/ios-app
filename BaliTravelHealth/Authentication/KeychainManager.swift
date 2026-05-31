import Foundation
import Security

final class KeychainManager: Sendable {
    static let shared = KeychainManager()
    private init() {}

    enum Key: String, Sendable {
        case userID = "com.balitravelhealth.auth.userID"
        case userName = "com.balitravelhealth.auth.userName"
        case userEmail = "com.balitravelhealth.auth.userEmail"
        case provider = "com.balitravelhealth.auth.provider"
        case sessionToken = "com.balitravelhealth.auth.sessionToken"
        case refreshToken = "com.balitravelhealth.auth.refreshToken"
        case accessTokenExpiresAt = "com.balitravelhealth.auth.accessTokenExpiresAt"
    }

    @discardableResult
    func save(_ value: String, for key: Key) -> Bool {
        guard let data = value.data(using: .utf8) else { return false }
        delete(key)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key.rawValue,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]
        return SecItemAdd(query as CFDictionary, nil) == errSecSuccess
    }

    func get(_ key: Key) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key.rawValue,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    @discardableResult
    func delete(_ key: Key) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key.rawValue
        ]
        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }

    func clearAll() {
        for key in [Key.userID, .userName, .userEmail, .provider, .sessionToken, .refreshToken, .accessTokenExpiresAt] {
            delete(key)
        }
    }
}

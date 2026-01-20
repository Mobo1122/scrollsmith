import Foundation
import Security

/// Service for securely storing authentication tokens in the iOS Keychain.
///
/// Tokens are stored with `.whenUnlockedThisDeviceOnly` accessibility,
/// meaning they're only available when the device is unlocked and
/// won't be included in backups or transferred to new devices.
actor KeychainService {
    static let shared = KeychainService()

    private let service = "com.scrollsmith.auth"
    private let accessTokenKey = "access_token"
    private let refreshTokenKey = "refresh_token"

    private init() {}

    // MARK: - Token Storage

    /// Save both access and refresh tokens to the Keychain.
    func saveTokens(_ tokens: AuthTokens) throws {
        try save(tokens.accessToken, forKey: accessTokenKey)
        try save(tokens.refreshToken, forKey: refreshTokenKey)
    }

    /// Get the current access token, if any.
    func getAccessToken() -> String? {
        get(forKey: accessTokenKey)
    }

    /// Get the current refresh token, if any.
    func getRefreshToken() -> String? {
        get(forKey: refreshTokenKey)
    }

    /// Check if user has stored tokens (is logged in).
    func hasTokens() -> Bool {
        getAccessToken() != nil && getRefreshToken() != nil
    }

    /// Clear all stored tokens (logout).
    func clearTokens() throws {
        try delete(forKey: accessTokenKey)
        try delete(forKey: refreshTokenKey)
    }

    // MARK: - Private Helpers

    private func save(_ value: String, forKey key: String) throws {
        guard let data = value.data(using: .utf8) else {
            throw KeychainError.encodingFailed
        }

        // Delete existing item first (update = delete + add)
        try? delete(forKey: key)

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
        ]

        let status = SecItemAdd(query as CFDictionary, nil)

        guard status == errSecSuccess else {
            throw KeychainError.saveFailed(status)
        }
    }

    private func get(forKey key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess,
              let data = result as? Data,
              let string = String(data: data, encoding: .utf8) else {
            return nil
        }

        return string
    }

    private func delete(forKey key: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
        ]

        let status = SecItemDelete(query as CFDictionary)

        // errSecItemNotFound is OK - item didn't exist
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.deleteFailed(status)
        }
    }
}

// MARK: - Errors

enum KeychainError: LocalizedError {
    case encodingFailed
    case saveFailed(OSStatus)
    case deleteFailed(OSStatus)

    var errorDescription: String? {
        switch self {
        case .encodingFailed:
            return "Failed to encode value for Keychain"
        case .saveFailed(let status):
            return "Failed to save to Keychain: \(status)"
        case .deleteFailed(let status):
            return "Failed to delete from Keychain: \(status)"
        }
    }
}

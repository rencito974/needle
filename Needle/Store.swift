import Foundation
import Security

enum Store {
    private static let key = "spotify.token"

    private static var query: [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "needle",
            kSecAttrAccount as String: key,
        ]
    }

    static func token() -> Token? {
        guard let data = read() else { return nil }
        return try? JSONDecoder().decode(Token.self, from: data)
    }

    static func save(_ token: Token?) {
        guard let token, let data = try? JSONEncoder().encode(token) else {
            remove()
            return
        }
        write(data)
    }

    private static func read() -> Data? {
        var lookup = query
        lookup[kSecReturnData as String] = true
        lookup[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: AnyObject?
        if SecItemCopyMatching(lookup as CFDictionary, &result) == errSecSuccess, let data = result as? Data {
            return data
        }
        return UserDefaults.standard.data(forKey: key)
    }

    private static func write(_ data: Data) {
        SecItemDelete(query as CFDictionary)
        var item = query
        item[kSecValueData as String] = data
        item[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        if SecItemAdd(item as CFDictionary, nil) == errSecSuccess {
            UserDefaults.standard.removeObject(forKey: key)
        } else {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    private static func remove() {
        SecItemDelete(query as CFDictionary)
        UserDefaults.standard.removeObject(forKey: key)
    }
}

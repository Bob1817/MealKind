import Foundation
import Security

struct AccountAuthConfig: Sendable {
    var baseURL: URL?

    static var appDefault: AccountAuthConfig {
        let rawValue = Bundle.main.object(forInfoDictionaryKey: "PersistenceEndpoint") as? String
        return AccountAuthConfig(baseURL: rawValue.flatMap(URL.init(string:)))
    }
}

struct AccountAuthService {
    typealias DataLoader = @MainActor (URLRequest) async throws -> (Data, URLResponse)

    private let config: AccountAuthConfig
    private let dataLoader: DataLoader
    private let keychain: MealKindKeychain
    private let store: UserDefaults

    init(
        config: AccountAuthConfig = .appDefault,
        keychain: MealKindKeychain = .standard,
        store: UserDefaults = .standard,
        dataLoader: @escaping DataLoader = { request in
            try await URLSession.shared.data(for: request)
        }
    ) {
        self.config = config
        self.keychain = keychain
        self.store = store
        self.dataLoader = dataLoader
    }

    @MainActor
    func register(email: String, password: String, name: String?, language: AppLanguage) async throws -> AccountSession {
        try await authenticate(
            path: "api/client/register",
            request: AccountAuthRequest(
                email: email,
                password: password,
                name: name,
                locale: language.localeIdentifier,
                installId: installId()
            )
        )
    }

    @MainActor
    func login(email: String, password: String, language: AppLanguage) async throws -> AccountSession {
        try await authenticate(
            path: "api/client/login",
            request: AccountAuthRequest(
                email: email,
                password: password,
                name: nil,
                locale: language.localeIdentifier,
                installId: installId()
            )
        )
    }

    @MainActor
    func signOut() {
        try? keychain.delete(Keys.token)
        store.removeObject(forKey: Keys.token)
        store.removeObject(forKey: Keys.userId)
        store.removeObject(forKey: Keys.email)
    }

    @MainActor
    var isSignedIn: Bool {
        (try? keychain.string(Keys.token))?.isEmpty == false || store.string(forKey: Keys.token)?.isEmpty == false
    }

    @MainActor
    var currentEmail: String? {
        store.string(forKey: Keys.email)
    }

    @MainActor
    private func authenticate(path: String, request: AccountAuthRequest) async throws -> AccountSession {
        guard let baseURL = config.baseURL else { throw AccountAuthError.missingEndpoint }
        var urlRequest = URLRequest(url: baseURL.appending(path: path))
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.httpBody = try JSONEncoder.mealKind.encode(request)

        let (data, response) = try await dataLoader(urlRequest)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AccountAuthError.badResponse
        }
        guard 200..<300 ~= httpResponse.statusCode else {
            let message = (try? JSONDecoder.mealKind.decode(AccountErrorResponse.self, from: data).error) ?? "Unable to sign in"
            throw AccountAuthError.server(message)
        }

        let session = try JSONDecoder.mealKind.decode(AccountSession.self, from: data)
        try keychain.set(session.token, for: Keys.token)
        store.set(session.token, forKey: Keys.token)
        store.set(session.user.id, forKey: Keys.userId)
        store.set(session.user.email, forKey: Keys.email)
        return session
    }

    private func installId() -> String {
        if let existing = store.string(forKey: Keys.installId), existing.isEmpty == false {
            return existing
        }
        let value = UUID().uuidString
        store.set(value, forKey: Keys.installId)
        return value
    }

    private enum Keys {
        static let installId = "mealkind.persistence.installId"
        static let token = "mealkind.persistence.token"
        static let userId = "mealkind.persistence.userId"
        static let email = "mealkind.account.email"
    }
}

struct AccountSession: Decodable, Sendable {
    var token: String
    var user: AccountUser
}

struct AccountUser: Decodable, Sendable {
    var id: String
    var name: String?
    var email: String?
    var locale: String?
}

private struct AccountAuthRequest: Encodable {
    var email: String
    var password: String
    var name: String?
    var locale: String
    var installId: String
}

private struct AccountErrorResponse: Decodable {
    var error: String
}

enum AccountAuthError: LocalizedError {
    case missingEndpoint
    case badResponse
    case server(String)

    var errorDescription: String? {
        switch self {
        case .missingEndpoint:
            return "Account endpoint is not configured."
        case .badResponse:
            return "The server response was invalid."
        case .server(let message):
            return message
        }
    }
}

struct MealKindKeychain {
    var service = "com.mealkind.app"

    static let standard = MealKindKeychain()

    func set(_ value: String, for account: String) throws {
        let data = Data(value.utf8)
        try? delete(account)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: data
        ]
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else { throw AccountAuthError.badResponse }
    }

    func string(_ account: String) throws -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecMatchLimit as String: kSecMatchLimitOne,
            kSecReturnData as String: true
        ]
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess, let data = item as? Data else { throw AccountAuthError.badResponse }
        return String(data: data, encoding: .utf8)
    }

    func delete(_ account: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else { throw AccountAuthError.badResponse }
    }
}

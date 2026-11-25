import AuthenticationServices
import CryptoKit
import Foundation
import UIKit

struct Token: Codable {
    var access: String
    var refresh: String
    var expires: Date
}

enum AuthError: Error {
    case cancelled
    case signedOut
    case rejected
}

private struct TokenReply: Decodable {
    let access_token: String
    let refresh_token: String?
    let expires_in: Int
}

private final class Anchor: NSObject, ASWebAuthenticationPresentationContextProviding {
    let window: UIWindow

    init(window: UIWindow) {
        self.window = window
    }

    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        window
    }
}

@MainActor
@Observable
final class Auth {
    private(set) var token: Token?

    @ObservationIgnored private var refreshing: Task<Token, Error>?
    @ObservationIgnored private var session: ASWebAuthenticationSession?
    @ObservationIgnored private var anchor: Anchor?

    var signedIn: Bool { token != nil }

    init() {
        token = Store.token()
    }

    func signIn() async throws {
        let verifier = Self.verifier()
        let state = UUID().uuidString
        var parts = URLComponents(string: "https://accounts.spotify.com/authorize")!
        parts.queryItems = [
            URLQueryItem(name: "client_id", value: Config.clientID),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "redirect_uri", value: Config.redirectURI),
            URLQueryItem(name: "code_challenge_method", value: "S256"),
            URLQueryItem(name: "code_challenge", value: Self.challenge(verifier)),
            URLQueryItem(name: "state", value: state),
            URLQueryItem(name: "scope", value: Config.scopes.joined(separator: " ")),
        ]
        let callback = try await present(parts.url!)
        let items = URLComponents(url: callback, resolvingAgainstBaseURL: false)?.queryItems ?? []
        func value(_ name: String) -> String? {
            items.first(where: { $0.name == name })?.value
        }
        guard value("state") == state, let code = value("code") else {
            throw AuthError.rejected
        }
        let fresh = try await exchange([
            "grant_type": "authorization_code",
            "code": code,
            "redirect_uri": Config.redirectURI,
            "client_id": Config.clientID,
            "code_verifier": verifier,
        ], fallback: nil)
        set(fresh)
    }

    func signOut() {
        set(nil)
    }

    func accessToken(force: Bool = false) async throws -> String {
        guard let token else { throw AuthError.signedOut }
        if !force, token.expires > Date() {
            return token.access
        }
        if let refreshing {
            return try await refreshing.value.access
        }
        let refresh = token.refresh
        let task = Task {
            try await self.exchange([
                "grant_type": "refresh_token",
                "refresh_token": refresh,
                "client_id": Config.clientID,
            ], fallback: refresh)
        }
        refreshing = task
        defer { refreshing = nil }
        do {
            let fresh = try await task.value
            set(fresh)
            return fresh.access
        } catch AuthError.rejected {
            set(nil)
            throw AuthError.signedOut
        }
    }

    private func set(_ value: Token?) {
        token = value
        Store.save(value)
    }

    private func present(_ url: URL) async throws -> URL {
        let window = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first(where: \.isKeyWindow) ?? UIWindow()
        let anchor = Anchor(window: window)
        self.anchor = anchor
        return try await withCheckedThrowingContinuation { continuation in
            let session = ASWebAuthenticationSession(url: url, callbackURLScheme: Config.scheme) { callback, error in
                if let callback {
                    continuation.resume(returning: callback)
                } else if let error = error as? ASWebAuthenticationSessionError, error.code == .canceledLogin {
                    continuation.resume(throwing: AuthError.cancelled)
                } else {
                    continuation.resume(throwing: error ?? AuthError.rejected)
                }
            }
            session.presentationContextProvider = anchor
            self.session = session
            session.start()
        }
    }

    private func exchange(_ form: [String: String], fallback: String?) async throws -> Token {
        var request = URLRequest(url: URL(string: "https://accounts.spotify.com/api/token")!)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = form
            .map { "\($0.key)=\(Self.escape($0.value))" }
            .joined(separator: "&")
            .data(using: .utf8)
        let (data, response) = try await URLSession.shared.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        if status != 200 {
            if (400..<500).contains(status) && status != 429 {
                throw AuthError.rejected
            }
            throw URLError(.badServerResponse)
        }
        let reply = try JSONDecoder().decode(TokenReply.self, from: data)
        guard let refresh = reply.refresh_token ?? fallback else {
            throw AuthError.rejected
        }
        return Token(
            access: reply.access_token,
            refresh: refresh,
            expires: Date().addingTimeInterval(TimeInterval(reply.expires_in - 120))
        )
    }

    private static func escape(_ value: String) -> String {
        let allowed = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-._~")
        return value.addingPercentEncoding(withAllowedCharacters: allowed) ?? value
    }

    private static func verifier() -> String {
        let letters = Array("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-._~")
        return String((0..<64).map { _ in letters.randomElement()! })
    }

    private static func challenge(_ verifier: String) -> String {
        let hash = SHA256.hash(data: Data(verifier.utf8))
        return Data(hash).base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}

import Foundation

enum USCISEnvironment: String, CaseIterable, Identifiable {
    case sandbox
    case production

    static let storageKey = "uscisEnvironment"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .sandbox: "Sandbox"
        case .production: "Production"
        }
    }

    var baseURL: URL {
        switch self {
        case .sandbox: URL(string: "https://api-int.uscis.gov")!
        case .production: URL(string: "https://api.uscis.gov")!
        }
    }

    static var current: USCISEnvironment {
        UserDefaults.standard.string(forKey: storageKey).flatMap(USCISEnvironment.init) ?? .sandbox
    }
}

enum USCISError: LocalizedError, Equatable {
    case notConfigured
    case invalidCredentials
    case caseNotFound(String?)
    case rateLimited
    case http(Int, String?)
    case invalidResponse
    case network(String)

    var errorDescription: String? {
        switch self {
        case .notConfigured:
            "Add your USCIS API credentials in Settings."
        case .invalidCredentials:
            "USCIS rejected the API credentials. Check them in Settings."
        case .caseNotFound(let message):
            message.map { "Case not found: \($0)" } ?? "USCIS has no case with this receipt number."
        case .rateLimited:
            "Too many requests to USCIS. Try again in a little while."
        case .http(let code, let message):
            "USCIS returned an error (\(code))" + (message.map { ": \($0)" } ?? ".")
        case .invalidResponse:
            "USCIS returned a response the app couldn't read."
        case .network(let message):
            message
        }
    }
}

/// Talks to the official USCIS Case Status API (developer.uscis.gov).
/// Auth is OAuth 2.0 client credentials; tokens last ~30 minutes and are cached in memory.
actor USCISClient {
    static let shared = USCISClient()

    private struct Token {
        let value: String
        let expiresAt: Date
        let environment: USCISEnvironment
        let clientId: String
    }

    private let session: URLSession
    private var token: Token?

    init(session: URLSession = .shared) {
        self.session = session
    }

    func fetchStatus(receiptNumber: String) async throws -> CaseStatusResult {
        let receipt = ReceiptNumber.normalize(receiptNumber)
        let environment = USCISEnvironment.current
        guard let credentials = USCISCredentials.load() else { throw USCISError.notConfigured }

        var (data, response) = try await caseStatusRequest(receipt, environment: environment, credentials: credentials)
        if response.statusCode == 401 {
            // Token may have been revoked or expired early; retry once with a fresh one.
            token = nil
            (data, response) = try await caseStatusRequest(receipt, environment: environment, credentials: credentials)
        }

        switch response.statusCode {
        case 200:
            return try USCISResponseParser.parse(data, receiptNumber: receipt)
        case 401, 403:
            token = nil
            throw USCISError.invalidCredentials
        case 404:
            throw USCISError.caseNotFound(USCISResponseParser.errorMessage(from: data))
        case 429:
            throw USCISError.rateLimited
        default:
            throw USCISError.http(response.statusCode, USCISResponseParser.errorMessage(from: data))
        }
    }

    /// Requests a fresh token to confirm the stored credentials work.
    func testConnection() async throws {
        guard let credentials = USCISCredentials.load() else { throw USCISError.notConfigured }
        token = nil
        _ = try await accessToken(environment: .current, credentials: credentials)
    }

    func clearToken() {
        token = nil
    }

    // MARK: - Private

    private func caseStatusRequest(
        _ receipt: String,
        environment: USCISEnvironment,
        credentials: USCISCredentials
    ) async throws -> (Data, HTTPURLResponse) {
        let accessToken = try await accessToken(environment: environment, credentials: credentials)
        var request = URLRequest(url: environment.baseURL.appending(path: "case-status/\(receipt)"))
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        return try await send(request)
    }

    private func accessToken(environment: USCISEnvironment, credentials: USCISCredentials) async throws -> String {
        if let token, token.environment == environment, token.clientId == credentials.clientId,
           token.expiresAt > Date.now.addingTimeInterval(60) {
            return token.value
        }

        var request = URLRequest(url: environment.baseURL.appending(path: "oauth/accesstoken"))
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        var form = URLComponents()
        form.queryItems = [
            URLQueryItem(name: "grant_type", value: "client_credentials"),
            URLQueryItem(name: "client_id", value: credentials.clientId),
            URLQueryItem(name: "client_secret", value: credentials.clientSecret),
        ]
        request.httpBody = form.percentEncodedQuery?.data(using: .utf8)

        let (data, response) = try await send(request)
        switch response.statusCode {
        case 200: break
        case 400, 401, 403: throw USCISError.invalidCredentials
        case 429: throw USCISError.rateLimited
        default: throw USCISError.http(response.statusCode, USCISResponseParser.errorMessage(from: data))
        }

        struct TokenResponse: Decodable {
            let accessToken: String
            let expiresIn: String?

            enum CodingKeys: String, CodingKey {
                case accessToken = "access_token"
                case expiresIn = "expires_in"
            }
        }
        guard let decoded = try? JSONDecoder().decode(TokenResponse.self, from: data) else {
            throw USCISError.invalidResponse
        }
        let lifetime = decoded.expiresIn.flatMap(TimeInterval.init) ?? 1_799
        token = Token(
            value: decoded.accessToken,
            expiresAt: .now.addingTimeInterval(lifetime),
            environment: environment,
            clientId: credentials.clientId
        )
        return decoded.accessToken
    }

    private func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse else { throw USCISError.invalidResponse }
            return (data, http)
        } catch let error as USCISError {
            throw error
        } catch {
            throw USCISError.network(error.localizedDescription)
        }
    }
}

// APIClient.swift
// iOS equivalent of Android's ApiClient.kt
// Uses modern Swift async/await + URLSession — no third-party networking library needed.

import Foundation

// MARK: - Configuration

enum APIConfig {
    static let baseURL = "https://boanalyst.com"  // Same backend as Android

    // SECURITY: Maximum response size accepted (4 MB).
    // Prevents memory exhaustion from unexpectedly large server responses.
    static let maxResponseBytes = 4 * 1024 * 1024  // 4 MB

    // SECURITY: Maximum token length we'll accept from OAuth deep-links or server.
    // A real JWT is ~500–900 bytes; anything larger is suspicious.
    static let maxTokenLength = 2048
}

// MARK: - API Errors

enum APIError: LocalizedError {
    case invalidURL
    case noData
    case decodingError(Error)
    case serverError(Int, String?)
    case unauthorized
    case networkError(Error)
    case responseTooLarge

    var errorDescription: String? {
        switch self {
        case .invalidURL:            return "Invalid URL"
        case .noData:                return "No data received"
        case .decodingError:        return "Response format error"  // Don't leak decode internals
        case .serverError(let code, _):
            // SECURITY: Never return raw server error messages to the UI —
            // they could contain stack traces, DB errors, or internal paths.
            switch code {
            case 400: return "Invalid request. Please check your input."
            case 401: return "Session expired. Please sign in again."
            case 403: return "You don't have permission to do this."
            case 404: return "Resource not found."
            case 409: return "A conflict occurred. Please try again."
            case 429: return "Too many requests. Please slow down."
            case 500...599: return "Server error. Please try again later."
            default:  return "Something went wrong. Please try again."
            }
        case .unauthorized:          return "Session expired. Please sign in again."
        case .networkError:         return "Unable to connect. Please check your internet."
        case .responseTooLarge:     return "Server response was too large."
        }
    }
}

// MARK: - API Client

final class APIClient {
    static let shared = APIClient()
    private init() {}

    private let userAgent = "BoAnalyst iOS App / 1.0 (Build 5; Sandbox Compatible)"

    private let session: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 60
        // SECURITY: Don't cache authenticated API responses
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        config.urlCache = nil
        // SECURITY: Disable cookies — we use Bearer tokens exclusively
        config.httpCookieAcceptPolicy = .never
        config.httpShouldSetCookies = false
        return URLSession(configuration: config)
    }()

    // JWT token — read from Keychain on every request (never cached in memory)
    private var authToken: String? {
        KeychainManager.shared.getToken()
    }

    // MARK: - Core Request Method

    func request<T: Decodable>(
        _ endpoint: APIEndpoint,
        responseType: T.Type
    ) async throws -> T {
        let urlRequest = try buildRequest(for: endpoint)

        do {
            let (data, response) = try await session.data(for: urlRequest)
            guard let httpResponse = response as? HTTPURLResponse else {
                throw APIError.noData
            }

            // SECURITY: Reject oversized responses before decoding
            if data.count > APIConfig.maxResponseBytes {
                throw APIError.responseTooLarge
            }

            switch httpResponse.statusCode {
            case 200...299:
                do {
                    return try JSONDecoder().decode(T.self, from: data)
                } catch {
                    throw APIError.decodingError(error)
                }
            case 401:
                throw APIError.unauthorized
            default:
                throw APIError.serverError(httpResponse.statusCode, nil)
                // SECURITY: nil msg — never pass raw server message to the error type
            }
        } catch let error as APIError {
            throw error
        } catch {
            throw APIError.networkError(error)
        }
    }

    // MARK: - Raw JSON Request (returns [String: Any])
    // Used by auth endpoints where the Codable decode would be too strict.

    func requestRaw(_ endpoint: APIEndpoint) async throws -> [String: Any] {
        let urlRequest = try buildRequest(for: endpoint)

        do {
            let (data, response) = try await session.data(for: urlRequest)
            guard let httpResponse = response as? HTTPURLResponse else {
                throw APIError.noData
            }

            // SECURITY: Reject oversized responses
            if data.count > APIConfig.maxResponseBytes {
                throw APIError.responseTooLarge
            }

            switch httpResponse.statusCode {
            case 200...299:
                if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    return json
                }
                return ["success": false]
            case 401:
                throw APIError.unauthorized
            default:
                throw APIError.serverError(httpResponse.statusCode, nil)
            }
        } catch let error as APIError {
            throw error
        } catch {
            throw APIError.networkError(error)
        }
    }

    // MARK: - Private: Build URLRequest

    private func buildRequest(for endpoint: APIEndpoint) throws -> URLRequest {
        guard var components = URLComponents(string: APIConfig.baseURL + endpoint.path) else {
            throw APIError.invalidURL
        }
        if let queryItems = endpoint.queryItems, !queryItems.isEmpty {
            // SECURITY: Sanitize query values — strip any null bytes
            components.queryItems = queryItems.map {
                URLQueryItem(name: $0.name,
                             value: $0.value?.replacingOccurrences(of: "\0", with: ""))
            }
        }
        guard let url = components.url else { throw APIError.invalidURL }

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = endpoint.method.rawValue

        // SECURITY: Platform header — lets server apply iOS-specific behaviour
        urlRequest.setValue("ios", forHTTPHeaderField: "X-App-Client")
        urlRequest.setValue("application/json", forHTTPHeaderField: "Accept")

        if let token = authToken {
            // SECURITY: Only attach token if it looks like a valid JWT (3 dot-separated Base64 segments)
            if isValidTokenFormat(token) {
                urlRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            }
        }

        if let multipart = endpoint.multipartData {
            let boundary = UUID().uuidString
            urlRequest.setValue("multipart/form-data; boundary=\(boundary)",
                               forHTTPHeaderField: "Content-Type")
            urlRequest.httpBody = multipart.build(boundary: boundary)
        } else if let body = endpoint.body {
            urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
            urlRequest.httpBody = body
        }

        return urlRequest
    }

    // SECURITY: Basic structural validation for JWT format before sending.
    // A real JWT looks like: base64url.base64url.base64url
    private func isValidTokenFormat(_ token: String) -> Bool {
        guard token.count <= APIConfig.maxTokenLength else { return false }
        let parts = token.components(separatedBy: ".")
        return parts.count == 3 && parts.allSatisfy { !$0.isEmpty }
    }
}

// MARK: - HTTP Method

enum HTTPMethod: String {
    case GET, POST, PUT, PATCH, DELETE
}

// MARK: - Multipart Form Data Helper

struct MultipartFormData {
    struct Part {
        let name: String
        let data: Data
        let filename: String?
        let mimeType: String?
    }

    var parts: [Part] = []

    mutating func append(name: String, string: String) {
        parts.append(Part(name: name, data: Data(string.utf8), filename: nil, mimeType: nil))
    }

    mutating func append(name: String, data: Data, filename: String, mimeType: String) {
        parts.append(Part(name: name, data: data, filename: filename, mimeType: mimeType))
    }

    func build(boundary: String) -> Data {
        var body = Data()
        for part in parts {
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            if let filename = part.filename, let mime = part.mimeType {
                body.append("Content-Disposition: form-data; name=\"\(part.name)\"; filename=\"\(filename)\"\r\n".data(using: .utf8)!)
                body.append("Content-Type: \(mime)\r\n\r\n".data(using: .utf8)!)
            } else {
                body.append("Content-Disposition: form-data; name=\"\(part.name)\"\r\n\r\n".data(using: .utf8)!)
            }
            body.append(part.data)
            body.append("\r\n".data(using: .utf8)!)
        }
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        return body
    }
}

// MARK: - Keychain Manager (replaces Android SecurePrefs)

final class KeychainManager {
    static let shared = KeychainManager()
    private init() {}

    // SECURITY: Use a unique service name so items are scoped to this app only.
    // Without kSecAttrService, the keychain item is accessible by any app
    // with the same kSecAttrAccount on a jailbroken device.
    private let service = "com.boanalyst.app.keychain"
    private let tokenKey = "jwt_access_token"

    func saveToken(_ token: String) {
        // SECURITY: Validate token before persisting — reject obviously invalid values
        guard !token.isEmpty, token.count <= APIConfig.maxTokenLength else { return }
        guard let data = token.data(using: .utf8) else { return }

        // SECURITY: kSecAttrAccessibleWhenUnlockedThisDeviceOnly —
        //   • Token is ONLY accessible when device is unlocked
        //   • NOT included in iCloud Keychain or iTunes backups
        //   • Deleted when device is restored (mirrors Android Keystore)
        deleteToken() // Always delete first to avoid duplicate entry errors
        let query: [String: Any] = [
            kSecClass as String:             kSecClassGenericPassword,
            kSecAttrService as String:       service,
            kSecAttrAccount as String:       tokenKey,
            kSecAttrAccessible as String:    kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
            kSecValueData as String:         data
        ]
        let status = SecItemAdd(query as CFDictionary, nil)
        if status != errSecSuccess {
            // Silent fail — user will just see "not authenticated" and have to log in again
        }
    }

    func getToken() -> String? {
        let query: [String: Any] = [
            kSecClass as String:       kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: tokenKey,
            kSecReturnData as String:  true,
            kSecMatchLimit as String:  kSecMatchLimitOne
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess,
              let data = result as? Data,
              let token = String(data: data, encoding: .utf8),
              token.count <= APIConfig.maxTokenLength else {
            return nil
        }
        return token
    }

    func deleteToken() {
        let query: [String: Any] = [
            kSecClass as String:       kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: tokenKey
        ]
        SecItemDelete(query as CFDictionary)
    }

    func hasToken() -> Bool {
        getToken() != nil
    }
}

// APIClient.swift
// iOS equivalent of Android's ApiClient.kt
// Uses modern Swift async/await + URLSession — no third-party networking library needed.

import Foundation

// MARK: - Configuration

enum APIConfig {
    static let baseURL = "https://boanalyst.com"  // Same backend as Android
}

// MARK: - API Errors

enum APIError: LocalizedError {
    case invalidURL
    case noData
    case decodingError(Error)
    case serverError(Int, String?)
    case unauthorized
    case networkError(Error)

    var errorDescription: String? {
        switch self {
        case .invalidURL:            return "Invalid URL"
        case .noData:                return "No data received"
        case .decodingError(let e): return "Decode error: \(e.localizedDescription)"
        case .serverError(let code, let msg): return "Server error \(code): \(msg ?? "")"
        case .unauthorized:          return "Unauthorized — please log in again"
        case .networkError(let e):  return e.localizedDescription
        }
    }
}

// MARK: - API Client

final class APIClient {
    static let shared = APIClient()
    private init() {}

    private let session: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        // SECURITY: Don't cache authenticated API responses (mirrors Android retryOnConnectionFailure=false)
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        config.urlCache = nil
        return URLSession(configuration: config)
    }()

    // JWT token — mirrors Android's SecurePrefs token storage
    private var authToken: String? {
        KeychainManager.shared.getToken()
    }

    // MARK: - Core Request Method

    func request<T: Decodable>(
        _ endpoint: APIEndpoint,
        responseType: T.Type
    ) async throws -> T {
        // Build URL, appending query items if present
        guard var components = URLComponents(string: APIConfig.baseURL + endpoint.path) else {
            throw APIError.invalidURL
        }
        if let queryItems = endpoint.queryItems, !queryItems.isEmpty {
            components.queryItems = queryItems
        }
        guard let url = components.url else {
            throw APIError.invalidURL
        }

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = endpoint.method.rawValue

        // SECURITY: Platform header — mirrors Android's X-App-Client: android
        // Server uses this to distinguish iOS vs Android OAuth redirect behaviour
        urlRequest.setValue("ios", forHTTPHeaderField: "X-App-Client")
        urlRequest.setValue("application/json", forHTTPHeaderField: "Accept")

        if let token = authToken {
            urlRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        // Multipart takes priority — don't set JSON content-type alongside it
        if let multipart = endpoint.multipartData {
            let boundary = UUID().uuidString
            urlRequest.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
            urlRequest.httpBody = multipart.build(boundary: boundary)
        } else if let body = endpoint.body {
            urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
            urlRequest.httpBody = body
        }

        do {
            let (data, response) = try await session.data(for: urlRequest)
            guard let httpResponse = response as? HTTPURLResponse else {
                throw APIError.noData
            }

            switch httpResponse.statusCode {
            case 200...299:
                do {
                    let decoder = JSONDecoder()
                    return try decoder.decode(T.self, from: data)
                } catch {
                    throw APIError.decodingError(error)
                }
            case 401:
                throw APIError.unauthorized
            default:
                let message = String(data: data, encoding: .utf8)
                throw APIError.serverError(httpResponse.statusCode, message)
            }
        } catch let error as APIError {
            throw error
        } catch {
            throw APIError.networkError(error)
        }
    }

    // MARK: - Raw JSON Request (returns [String: Any] — avoids Codable decode failures)
    // Used by auth endpoints where server may return slightly inconsistent field types.

    func requestRaw(_ endpoint: APIEndpoint) async throws -> [String: Any] {
        guard var components = URLComponents(string: APIConfig.baseURL + endpoint.path) else {
            throw APIError.invalidURL
        }
        if let queryItems = endpoint.queryItems, !queryItems.isEmpty {
            components.queryItems = queryItems
        }
        guard let url = components.url else { throw APIError.invalidURL }

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = endpoint.method.rawValue
        urlRequest.setValue("ios", forHTTPHeaderField: "X-App-Client")
        urlRequest.setValue("application/json", forHTTPHeaderField: "Accept")
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")

        if let token = authToken {
            urlRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        if let body = endpoint.body {
            urlRequest.httpBody = body
        }

        do {
            let (data, response) = try await session.data(for: urlRequest)
            guard let httpResponse = response as? HTTPURLResponse else { throw APIError.noData }

            switch httpResponse.statusCode {
            case 200...299:
                if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    return json
                }
                // Even if JSON parse fails, return empty dict with success:false
                return ["success": false, "message": "Server response could not be parsed"]
            case 401:
                throw APIError.unauthorized
            default:
                let body = (try? JSONSerialization.jsonObject(with: data) as? [String: Any])
                let message = body?["message"] as? String ?? String(data: data, encoding: .utf8)
                throw APIError.serverError(httpResponse.statusCode, message)
            }
        } catch let error as APIError {
            throw error
        } catch {
            throw APIError.networkError(error)
        }
    }
}

// MARK: - HTTP Method

enum HTTPMethod: String {
    case GET, POST, PUT, DELETE
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

    private let tokenKey = "com.boanalyst.jwt"

    func saveToken(_ token: String) {
        let data = Data(token.utf8)
        // SECURITY: kSecAttrAccessibleWhenUnlockedThisDeviceOnly prevents JWT from
        // being included in iCloud Keychain backups — mirrors Android Keystore behaviour.
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: tokenKey,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
            kSecValueData as String: data
        ]
        SecItemDelete(query as CFDictionary)
        SecItemAdd(query as CFDictionary, nil)
    }

    func getToken() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: tokenKey,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: AnyObject?
        SecItemCopyMatching(query as CFDictionary, &result)
        guard let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    func deleteToken() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: tokenKey
        ]
        SecItemDelete(query as CFDictionary)
    }

    func hasToken() -> Bool {
        getToken() != nil
    }
}

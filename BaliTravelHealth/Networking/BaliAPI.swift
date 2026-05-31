import Foundation
import UIKit

// MARK: - Base configuration

enum BaliAPI {
    static let baseURL = URL(string: "https://backend.balihealth.me")!

    static let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.keyDecodingStrategy = .convertFromSnakeCase
        d.dateDecodingStrategy = .iso8601
        return d
    }()

    static let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.keyEncodingStrategy = .convertToSnakeCase
        e.dateEncodingStrategy = .iso8601
        return e
    }()

    static func url(_ path: String, queryItems: [URLQueryItem] = []) -> URL {
        var components = URLComponents(
            url: baseURL.appendingPathComponent(path),
            resolvingAgainstBaseURL: false
        )!
        if !queryItems.isEmpty {
            components.queryItems = queryItems
        }
        return components.url!
    }

    /// Unauthenticated request (public endpoints).
    static func request(_ path: String,
                        method: String = "GET",
                        queryItems: [URLQueryItem] = []) -> URLRequest {
        var req = URLRequest(url: url(path, queryItems: queryItems))
        req.httpMethod = method
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        req.applyAppUserAgent()
        return req
    }

    /// Authenticated request — attaches Bearer token if available.
    static func authedRequest(_ path: String,
                              method: String = "GET",
                              queryItems: [URLQueryItem] = []) -> URLRequest {
        var req = request(path, method: method, queryItems: queryItems)
        if let token = KeychainManager.shared.get(.sessionToken) {
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        return req
    }

    /// Executes a request. On 401, attempts a token refresh and retries once.
    static func perform(_ request: URLRequest) async throws -> (Data, Int) {
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw BaliAPIError.malformedResponse
        }

        if http.statusCode == 401 {
            let refreshed: Bool
            do {
                refreshed = try await BaliAuthAPIClient.shared.refreshToken()
            } catch {
                KeychainManager.shared.clearAll()
                throw BaliAPIError.unauthorized
            }

            if refreshed {
                var retried = request
                if let token = KeychainManager.shared.get(.sessionToken) {
                    retried.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
                }
                let (retryData, retryResponse) = try await URLSession.shared.data(for: retried)
                guard let retryHTTP = retryResponse as? HTTPURLResponse else {
                    throw BaliAPIError.malformedResponse
                }
                return (retryData, retryHTTP.statusCode)
            }
            KeychainManager.shared.clearAll()
            throw BaliAPIError.unauthorized
        }

        return (data, http.statusCode)
    }

    static func perform<T: Decodable>(_ request: URLRequest, as type: T.Type) async throws -> T {
        let (data, status) = try await perform(request)
        guard (200..<300).contains(status) else {
            throw BaliAPIError.from(data: data, status: status)
        }
        do {
            return try decode(type, from: data)
        } catch let error as BaliAPIError {
            throw error
        } catch {
            throw BaliAPIError.decoding(Self.describeDecodingError(error))
        }
    }

    static func performArray<T: Decodable>(_ request: URLRequest, of type: T.Type) async throws -> [T] {
        let (data, status) = try await perform(request)
        guard (200..<300).contains(status) else {
            throw BaliAPIError.from(data: data, status: status)
        }
        do {
            return try decodeArray(type, from: data)
        } catch let error as BaliAPIError {
            throw error
        } catch {
            throw BaliAPIError.decoding(Self.describeDecodingError(error))
        }
    }

    static func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        if let wrapped = try? decoder.decode(DataWrapper<T>.self, from: data) {
            return wrapped.data
        }
        do {
            return try decoder.decode(T.self, from: data)
        } catch let error as BaliAPIError {
            throw error
        } catch {
            throw BaliAPIError.decoding(Self.describeDecodingError(error))
        }
    }

    static func decodeArray<T: Decodable>(_ type: T.Type, from data: Data) throws -> [T] {
        if let page = try? decoder.decode(Page<T>.self, from: data) {
            return page.data
        }
        if let wrapped = try? decoder.decode(DataWrapper<[T]>.self, from: data) {
            return wrapped.data
        }
        do {
            return try decoder.decode([T].self, from: data)
        } catch let error as BaliAPIError {
            throw error
        } catch {
            throw BaliAPIError.decoding(Self.describeDecodingError(error))
        }
    }

    static func deviceInfo() -> String {
        let d = UIDevice.current
        return "\(d.name) / iOS \(d.systemVersion)"
    }

    static func describeDecodingError(_ error: Error) -> String {
        guard let decodingError = error as? DecodingError else {
            return error.localizedDescription
        }

        func path(_ codingPath: [CodingKey]) -> String {
            let value = codingPath.map(\.stringValue).joined(separator: ".")
            return value.isEmpty ? "<root>" : value
        }

        switch decodingError {
        case .keyNotFound(let key, let context):
            return "Missing field '\(key.stringValue)' at \(path(context.codingPath))."
        case .valueNotFound(_, let context):
            return "Missing value at \(path(context.codingPath)): \(context.debugDescription)"
        case .typeMismatch(_, let context):
            return "Invalid value at \(path(context.codingPath)): \(context.debugDescription)"
        case .dataCorrupted(let context):
            return "Invalid response data at \(path(context.codingPath)): \(context.debugDescription)"
        @unknown default:
            return decodingError.localizedDescription
        }
    }
}

// MARK: - Generic wrapper for { "data": T } responses

struct DataWrapper<T: Decodable>: Decodable {
    let data: T
}

struct DataEnvelope<T: Decodable>: Decodable {
    let data: T
}

struct Page<T: Decodable>: Decodable {
    let data: [T]
    let total: Int?
    let page: Int?
    let limit: Int?
}

// MARK: - Error type

enum BaliAPIError: Error, LocalizedError {
    case malformedResponse
    case unauthorized
    case notFound
    case conflict(String)
    case server(status: Int, message: String)
    case unavailable
    case decoding(String)

    static func from(data: Data, status: Int) -> BaliAPIError {
        let message = (try? JSONDecoder().decode([String: String].self, from: data))?["error"]
            ?? String(data: data, encoding: .utf8)
            ?? "Request failed"
        switch status {
        case 401: return .unauthorized
        case 404: return .notFound
        case 409: return .conflict(message)
        case 503: return .unavailable
        default: return .server(status: status, message: message)
        }
    }

    var errorDescription: String? {
        switch self {
        case .malformedResponse: return "Unexpected server response"
        case .unauthorized: return "Session expired. Please sign in again."
        case .notFound: return "Data not found"
        case .conflict(let msg): return msg
        case .server(_, let msg): return msg
        case .unavailable: return "Service temporarily unavailable. Try again later."
        case .decoding(let msg): return msg
        }
    }
}

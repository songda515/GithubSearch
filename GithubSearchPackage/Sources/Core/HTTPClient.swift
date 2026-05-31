import ComposableArchitecture
import Foundation

/// HTTP verb for an ``Endpoint``.
public enum HTTPMethod: String, Sendable {
    case get = "GET"
    case post = "POST"
    case put = "PUT"
    case delete = "DELETE"
}

/// A network endpoint: base URL + path + method + query/headers. Carries everything
/// needed to build a `URLRequest`; building fails loudly with ``NetworkError/invalidURL``.
public struct Endpoint: Sendable {
    public var baseURL: String
    public var path: String
    public var method: HTTPMethod
    public var queryItems: [URLQueryItem]
    public var headers: [String: String]

    public init(
        baseURL: String,
        path: String = "",
        method: HTTPMethod = .get,
        queryItems: [URLQueryItem] = [],
        headers: [String: String] = [:]
    ) {
        self.baseURL = baseURL
        self.path = path
        self.method = method
        self.queryItems = queryItems
        self.headers = headers
    }

    /// Build the `URLRequest`, or throw ``NetworkError/invalidURL`` if the URL is malformed.
    public func urlRequest() throws -> URLRequest {
        guard var components = URLComponents(string: baseURL + path) else {
            throw NetworkError.invalidURL
        }
        if !queryItems.isEmpty { components.queryItems = queryItems }
        guard let url = components.url else { throw NetworkError.invalidURL }
        var request = URLRequest(url: url)
        request.httpMethod = method.rawValue
        for (field, value) in headers {
            request.setValue(value, forHTTPHeaderField: field)
        }
        return request
    }
}

/// Network failures, flattened so associated values stay `Equatable`/`Sendable`.
public enum NetworkError: Error, Equatable, Sendable {
    /// The endpoint could not be turned into a valid URL.
    case invalidURL
    /// The response was not an `HTTPURLResponse`.
    case invalidResponse
    /// A non-2xx HTTP status was returned.
    case httpStatus(Int)
    /// The underlying transport failed (offline, timeout, …). Description only.
    case transport(String)
    /// The body could not be decoded into the requested type. Description only.
    case decoding(String)
}

/// Generic, screen-agnostic HTTP client. Features build their own ``Endpoint`` and
/// request a `Decodable` value; this client never knows API specifics.
@DependencyClient
public struct HTTPClient: Sendable {
    /// Perform the request and return the raw body + HTTP response. Maps failures to
    /// ``NetworkError`` (invalidURL/invalidResponse/httpStatus/transport).
    public var data: @Sendable (_ endpoint: Endpoint) async throws -> (Data, HTTPURLResponse)
}

public extension HTTPClient {
    /// Fetch and decode `T` from the endpoint. Decoding failures map to
    /// ``NetworkError/decoding(_:)``. (Generic, so it lives outside the stored closure.)
    func request<T: Decodable>(
        _ endpoint: Endpoint,
        as _: T.Type = T.self,
        decoder: JSONDecoder = JSONDecoder()
    ) async throws -> T {
        let (data, _) = try await self.data(endpoint)
        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            throw NetworkError.decoding(String(describing: error))
        }
    }
}

extension HTTPClient: DependencyKey {
    public static let liveValue = HTTPClient { endpoint in
        let request = try endpoint.urlRequest()
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse else {
                throw NetworkError.invalidResponse
            }
            guard (200..<300).contains(http.statusCode) else {
                throw NetworkError.httpStatus(http.statusCode)
            }
            return (data, http)
        } catch let error as NetworkError {
            throw error
        } catch {
            throw NetworkError.transport(String(describing: error))
        }
    }

    /// Deterministic stub for previews: an empty JSON object + 200. Feature previews
    /// override this with their own canned payloads.
    public static var previewValue: HTTPClient {
        HTTPClient { endpoint in
            let url = (try? endpoint.urlRequest().url) ?? URL(string: "https://example.com")!
            let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (Data("{}".utf8), response)
        }
    }
    // testValue is auto-synthesized as "unimplemented" by @DependencyClient.
}

public extension DependencyValues {
    var httpClient: HTTPClient {
        get { self[HTTPClient.self] }
        set { self[HTTPClient.self] = newValue }
    }
}

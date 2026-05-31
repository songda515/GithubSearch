import ComposableArchitecture
import Foundation
import Testing

@testable import Core

/// Unit tests for the generic `HTTPClient`: endpoint building, decoding, and
/// `NetworkError` mapping. The `data` closure is stubbed so decoding/mapping run
/// through the real `request(_:as:)` path without touching the network.
struct HTTPClientTests {
    private struct Sample: Decodable, Equatable {
        let id: Int
        let name: String
    }

    private func response(_ status: Int) -> HTTPURLResponse {
        HTTPURLResponse(
            url: URL(string: "https://api.example.com")!,
            statusCode: status,
            httpVersion: nil,
            headerFields: nil
        )!
    }

    private var endpoint: Endpoint {
        Endpoint(baseURL: "https://api.example.com", path: "/thing")
    }

    @Test
    func requestDecodesBody() async throws {
        let json = Data(#"{"id":7,"name":"swift"}"#.utf8)
        let client = HTTPClient { _ in (json, self.response(200)) }

        let value: Sample = try await client.request(self.endpoint)
        #expect(value == Sample(id: 7, name: "swift"))
    }

    @Test
    func decodingFailureMapsToDecodingError() async {
        let broken = Data(#"{"id":"not-an-int"}"#.utf8)
        let client = HTTPClient { _ in (broken, self.response(200)) }

        await #expect(throws: NetworkError.self) {
            let _: Sample = try await client.request(self.endpoint)
        }
        do {
            let _: Sample = try await client.request(self.endpoint)
            Issue.record("expected decoding error")
        } catch let error as NetworkError {
            guard case .decoding = error else {
                Issue.record("expected .decoding, got \(error)")
                return
            }
        } catch {
            Issue.record("expected NetworkError, got \(error)")
        }
    }

    @Test
    func invalidURLThrows() throws {
        // A space in the host makes URLComponents.url nil.
        let endpoint = Endpoint(baseURL: "https://bad host", path: "/x")
        #expect(throws: NetworkError.invalidURL) {
            _ = try endpoint.urlRequest()
        }
    }

    @Test
    func endpointBuildsRequestWithQueryAndHeaders() throws {
        let endpoint = Endpoint(
            baseURL: "https://api.example.com",
            path: "/search",
            method: .get,
            queryItems: [URLQueryItem(name: "q", value: "swift"), URLQueryItem(name: "page", value: "2")],
            headers: ["Accept": "application/json"]
        )
        let request = try endpoint.urlRequest()

        #expect(request.httpMethod == "GET")
        #expect(request.value(forHTTPHeaderField: "Accept") == "application/json")
        let url = try #require(request.url)
        #expect(url.absoluteString.contains("q=swift"))
        #expect(url.absoluteString.contains("page=2"))
        #expect(url.absoluteString.hasPrefix("https://api.example.com/search?"))
    }

    @Test
    func networkErrorEquality() {
        #expect(NetworkError.httpStatus(404) == .httpStatus(404))
        #expect(NetworkError.httpStatus(404) != .httpStatus(500))
        #expect(NetworkError.invalidURL != .invalidResponse)
    }
}

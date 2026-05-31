import Core
import Foundation

/// GitHub repository search API specifics. The generic `HTTPClient` (Core) stays
/// API-agnostic; this file owns the endpoint, the wire DTO, and the DTO→domain mapping.
/// (docs/specs/search-result/spec.md §5)
enum GitHubSearchAPI {
    /// Fixed page size (spec P1).
    static let perPage = 30
    /// GitHub search returns at most 1000 results regardless of total_count (spec P4).
    static let maxResults = 1000

    /// `GET /search/repositories?q=&page=&per_page=30` with required GitHub headers.
    static func repositories(query: String, page: Int) -> Endpoint {
        Endpoint(
            baseURL: "https://api.github.com",
            path: "/search/repositories",
            method: .get,
            queryItems: [
                URLQueryItem(name: "q", value: query),
                URLQueryItem(name: "page", value: String(page)),
                URLQueryItem(name: "per_page", value: String(perPage)),
            ],
            headers: [
                "Accept": "application/vnd.github+json",
                "X-GitHub-Api-Version": "2022-11-28",
            ]
        )
    }
}

/// Wire model for the 200 response. Tolerant: only `id` is required so partial rows
/// still decode (spec E5); missing fields map to safe defaults during domain mapping.
struct GitHubSearchResponse: Decodable, Equatable, Sendable {
    let totalCount: Int
    let items: [Repo]

    enum CodingKeys: String, CodingKey {
        case totalCount = "total_count"
        case items
    }

    struct Repo: Decodable, Equatable, Sendable {
        let id: Int
        let name: String?
        let htmlURL: String?
        let owner: Owner?

        enum CodingKeys: String, CodingKey {
            case id, name, owner
            case htmlURL = "html_url"
        }

        struct Owner: Decodable, Equatable, Sendable {
            let login: String?
            let avatarURL: String?

            enum CodingKeys: String, CodingKey {
                case login
                case avatarURL = "avatar_url"
            }
        }
    }
}

extension RepositoryItem {
    /// Map a wire `Repo` to the domain model, defaulting missing fields (spec E5).
    init(_ repo: GitHubSearchResponse.Repo) {
        self.init(
            id: repo.id,
            thumbnail: repo.owner?.avatarURL.flatMap(URL.init(string:)),
            title: repo.name ?? "",
            description: repo.owner?.login ?? "",
            landingUrl: repo.htmlURL.flatMap(URL.init(string:))
        )
    }
}

extension RepositoryPage {
    init(_ response: GitHubSearchResponse) {
        self.init(items: response.items.map(RepositoryItem.init), totalCount: response.totalCount)
    }
}

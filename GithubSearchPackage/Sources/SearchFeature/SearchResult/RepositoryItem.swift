import Foundation

/// A repository row shown in the search results, mapped from the GitHub search API.
/// `id` is the stable identity used by `IdentifiedArrayOf` to dedup across pages (spec P5).
public struct RepositoryItem: Equatable, Identifiable, Sendable {
    public let id: Int
    /// Owner avatar (`owner.avatar_url`). Optional — missing/invalid falls back to a placeholder (E4).
    public let thumbnail: URL?
    /// Repository name (`name`), shown bold.
    public let title: String
    /// Owner login (`owner.login`), shown gray.
    public let description: String
    /// Repository web URL (`html_url`) opened in the web view.
    public let landingUrl: URL?

    public init(id: Int, thumbnail: URL?, title: String, description: String, landingUrl: URL?) {
        self.id = id
        self.thumbnail = thumbnail
        self.title = title
        self.description = description
        self.landingUrl = landingUrl
    }
}

/// One page of search results, in domain terms. Carried by actions so the GitHub DTO
/// stays an internal decoding detail.
public struct RepositoryPage: Equatable, Sendable {
    public var items: [RepositoryItem]
    public var totalCount: Int

    public init(items: [RepositoryItem], totalCount: Int) {
        self.items = items
        self.totalCount = totalCount
    }
}

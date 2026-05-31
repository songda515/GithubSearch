import Foundation

/// A persisted recent search entry. `query` is unique by policy (P5: dedup by query),
/// so it doubles as the stable identity. `date` drives reverse-chronological ordering (P3).
public struct SearchRecentItem: Codable, Equatable, Identifiable, Sendable {
    public var query: String
    public var date: Date

    public init(query: String, date: Date) {
        self.query = query
        self.date = date
    }

    public var id: String { query }
}

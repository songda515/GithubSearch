import ComposableArchitecture
import Core
import Foundation
import Testing

@testable import SearchFeature

/// Reducer tests for the search results screen (docs/specs/search-result/spec.md §8).
/// The `httpClient.data` closure is stubbed with canned GitHub JSON so the real
/// decode + DTO→domain mapping runs end to end.
@MainActor
struct SearchResultFeatureTests {
    // MARK: Helpers

    /// Canned `/search/repositories` 200 body for `ids`, mapped deterministically.
    private func searchJSON(totalCount: Int, ids: [Int]) -> Data {
        let items = ids.map { id in
            """
            {"id":\(id),"name":"repo\(id)","html_url":"https://github.com/owner\(id)/repo\(id)",\
            "owner":{"login":"owner\(id)","avatar_url":"https://avatars/\(id).png"}}
            """
        }.joined(separator: ",")
        return Data(#"{"total_count":\#(totalCount),"items":[\#(items)]}"#.utf8)
    }

    /// The `RepositoryItem` `searchJSON(ids:)` decodes/maps to for `id`.
    private func item(_ id: Int) -> RepositoryItem {
        RepositoryItem(
            id: id,
            thumbnail: URL(string: "https://avatars/\(id).png"),
            title: "repo\(id)",
            description: "owner\(id)",
            landingUrl: URL(string: "https://github.com/owner\(id)/repo\(id)")
        )
    }

    private nonisolated func ok(_ data: Data) -> (Data, HTTPURLResponse) {
        let response = HTTPURLResponse(
            url: URL(string: "https://api.github.com")!,
            statusCode: 200,
            httpVersion: nil,
            headerFields: nil
        )!
        return (data, response)
    }

    private func page(_ ids: [Int], totalCount: Int) -> RepositoryPage {
        RepositoryPage(items: ids.map(item), totalCount: totalCount)
    }

    // MARK: R1/P2/R3/R2 — first page loads

    @Test
    func searchLoadsFirstPage() async {
        let data = searchJSON(totalCount: 100, ids: Array(1...30))
        let store = TestStore(initialState: SearchResultFeature.State()) {
            SearchResultFeature()
        } withDependencies: {
            $0.httpClient.data = { @Sendable _ in self.ok(data) }
        }

        await store.send(.searchRequested("swift")) {
            $0.query = "swift"
            $0.currentPage = 1
            $0.phase = .loading
        }
        await store.receive(.searchResponse(.success(page(Array(1...30), totalCount: 100)))) {
            $0.totalCount = 100
            $0.items.append(contentsOf: (1...30).map(self.item))
            $0.hasNextPage = true   // 1*30 = 30 < min(100, 1000)
            $0.phase = .loaded
        }
    }

    // MARK: R7/E1 — zero results → empty

    @Test
    func emptyResultsShowEmptyPhase() async {
        let data = searchJSON(totalCount: 0, ids: [])
        let store = TestStore(initialState: SearchResultFeature.State()) {
            SearchResultFeature()
        } withDependencies: {
            $0.httpClient.data = { @Sendable _ in self.ok(data) }
        }

        await store.send(.searchRequested("zzzznotarepo")) {
            $0.query = "zzzznotarepo"
            $0.currentPage = 1
            $0.phase = .loading
        }
        await store.receive(.searchResponse(.success(page([], totalCount: 0)))) {
            $0.totalCount = 0
            $0.hasNextPage = false
            $0.phase = .empty
        }
    }

    // MARK: R7/E3 — network error → error

    @Test
    func networkErrorShowsErrorPhase() async {
        let store = TestStore(initialState: SearchResultFeature.State()) {
            SearchResultFeature()
        } withDependencies: {
            $0.httpClient.data = { @Sendable _ in throw NetworkError.httpStatus(403) }
        }

        await store.send(.searchRequested("swift")) {
            $0.query = "swift"
            $0.currentPage = 1
            $0.phase = .loading
        }
        await store.receive(.searchResponse(.failure(.httpStatus(403)))) {
            $0.phase = .error
        }
    }

    // MARK: R6/P3 — reachedBottom appends next page

    @Test
    func reachedBottomLoadsNextPageAndAppends() async {
        let data1 = searchJSON(totalCount: 100, ids: Array(1...30))
        let data2 = searchJSON(totalCount: 100, ids: Array(31...60))
        let store = TestStore(initialState: SearchResultFeature.State()) {
            SearchResultFeature()
        } withDependencies: {
            $0.httpClient.data = { @Sendable endpoint in
                let page = endpoint.queryItems.first { $0.name == "page" }?.value
                return self.ok(page == "2" ? data2 : data1)
            }
        }

        await store.send(.searchRequested("swift")) {
            $0.query = "swift"
            $0.currentPage = 1
            $0.phase = .loading
        }
        await store.receive(.searchResponse(.success(page(Array(1...30), totalCount: 100)))) {
            $0.totalCount = 100
            $0.items.append(contentsOf: (1...30).map(self.item))
            $0.hasNextPage = true
            $0.phase = .loaded
        }
        await store.send(.reachedBottom) {
            $0.isLoadingNextPage = true
        }
        await store.receive(.nextPageResponse(.success(page(Array(31...60), totalCount: 100)))) {
            $0.isLoadingNextPage = false
            $0.currentPage = 2
            $0.items.append(contentsOf: (31...60).map(self.item))
            $0.hasNextPage = true   // 2*30 = 60 < 100
        }
    }

    // MARK: P5 — duplicate ids across pages are de-duplicated

    @Test
    func nextPageDeduplicatesById() async {
        let data1 = searchJSON(totalCount: 100, ids: Array(1...30))
        let data2 = searchJSON(totalCount: 100, ids: Array(25...54))   // overlap 25...30
        let store = TestStore(initialState: SearchResultFeature.State()) {
            SearchResultFeature()
        } withDependencies: {
            $0.httpClient.data = { @Sendable endpoint in
                let page = endpoint.queryItems.first { $0.name == "page" }?.value
                return self.ok(page == "2" ? data2 : data1)
            }
        }

        await store.send(.searchRequested("swift")) {
            $0.query = "swift"
            $0.currentPage = 1
            $0.phase = .loading
        }
        await store.receive(.searchResponse(.success(page(Array(1...30), totalCount: 100)))) {
            $0.totalCount = 100
            $0.items.append(contentsOf: (1...30).map(self.item))
            $0.hasNextPage = true
            $0.phase = .loaded
        }
        await store.send(.reachedBottom) {
            $0.isLoadingNextPage = true
        }
        await store.receive(.nextPageResponse(.success(page(Array(25...54), totalCount: 100)))) {
            $0.isLoadingNextPage = false
            $0.currentPage = 2
            $0.items.append(contentsOf: (25...54).map(self.item))   // dedups 25...30
            $0.hasNextPage = true
        }
        #expect(store.state.items.count == 54)   // 1...54 unique
    }

    // MARK: E2/P4 — no next page → reachedBottom is a no-op

    @Test
    func reachedBottomNoOpWhenNoNextPage() async {
        let store = TestStore(
            initialState: SearchResultFeature.State(
                query: "swift",
                items: [item(1)],
                totalCount: 1,
                currentPage: 1,
                hasNextPage: false,
                phase: .loaded
            )
        ) {
            SearchResultFeature()
        }

        await store.send(.reachedBottom)   // guarded — no effect, no state change
    }

    // MARK: E6/P8 — load-more in flight → reachedBottom is a no-op

    @Test
    func reachedBottomNoOpWhileLoadingNextPage() async {
        let store = TestStore(
            initialState: SearchResultFeature.State(
                query: "swift",
                items: [item(1)],
                totalCount: 100,
                currentPage: 1,
                hasNextPage: true,
                isLoadingNextPage: true,
                phase: .loaded
            )
        ) {
            SearchResultFeature()
        }

        await store.send(.reachedBottom)   // guarded by isLoadingNextPage
    }

    // MARK: E7/P9 — new search while loading cancels in flight + resets

    @Test
    func newSearchWhileLoadingCancelsAndResets() async {
        let store = TestStore(initialState: SearchResultFeature.State()) {
            SearchResultFeature()
        } withDependencies: {
            $0.httpClient.data = { @Sendable _ in try await Task.never() }
        }

        await store.send(.searchRequested("a")) {
            $0.query = "a"
            $0.currentPage = 1
            $0.phase = .loading
        }
        // cancelInFlight cancels the first request; only the query changes.
        await store.send(.searchRequested("b")) {
            $0.query = "b"
        }
        // searchCleared cancels the suspended effect and resets.
        await store.send(.searchCleared) {
            $0 = SearchResultFeature.State()
        }
    }

    // MARK: R5 — searchCleared resets

    @Test
    func searchClearedResets() async {
        let store = TestStore(
            initialState: SearchResultFeature.State(
                query: "swift",
                items: [item(1)],
                totalCount: 1,
                currentPage: 1,
                phase: .loaded
            )
        ) {
            SearchResultFeature()
        }

        await store.send(.searchCleared) {
            $0 = SearchResultFeature.State()
        }
    }

    // MARK: R4 — row tap delegates selection

    @Test
    func rowTapDelegatesSelection() async {
        let selected = item(1)
        let store = TestStore(
            initialState: SearchResultFeature.State(items: [selected], phase: .loaded)
        ) {
            SearchResultFeature()
        }

        await store.send(.rowTapped(selected))
        await store.receive(.delegate(.repositorySelected(selected)))
    }
}

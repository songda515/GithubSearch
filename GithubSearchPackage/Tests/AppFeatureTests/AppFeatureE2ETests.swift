import ComposableArchitecture
import Core
import Foundation
import SearchFeature
import Testing

@testable import AppFeature

/// End-to-end (full-flow) integration tests driven from the `AppFeature` composition root.
/// Unlike the per-feature tests (which stub empty results), these walk the WHOLE journey —
/// search input → recent save → **populated** results → web view push — in one exhaustive
/// `TestStore` flow with deterministic stubbed clients. (docs/specs/e2e/spec.md §8)
///
/// `AppFeature.Action` isn't `Equatable`, so received actions are matched by case key path
/// (`\.search.result.searchResponse`) — same style as `AppFeatureTests` — and the payload is
/// asserted indirectly via the resulting state (items / phase / destination).
@MainActor
struct AppFeatureE2ETests {

    // MARK: - Fixtures

    /// Frozen clock so saved recent-search timestamps are deterministic.
    private let now = Date(timeIntervalSince1970: 1_000)

    /// Wire JSON for one repo, shaped like the GitHub search API (search-result spec §5).
    private nonisolated func repoJSON(id: Int, name: String) -> String {
        """
        {"id":\(id),"name":"\(name)","html_url":"https://github.com/apple/\(name)",\
        "owner":{"login":"apple","avatar_url":"https://avatars.githubusercontent.com/u/\(id)"}}
        """
    }

    /// The domain item the reducer should derive from `repoJSON(id:name:)`.
    private nonisolated func repoItem(id: Int, name: String) -> RepositoryItem {
        RepositoryItem(
            id: id,
            thumbnail: URL(string: "https://avatars.githubusercontent.com/u/\(id)"),
            title: name,
            description: "apple",
            landingUrl: URL(string: "https://github.com/apple/\(name)")
        )
    }

    /// A full `/search/repositories` 200 body for the given repos.
    private nonisolated func searchJSON(_ repos: [(id: Int, name: String)], totalCount: Int) -> String {
        let items = repos.map { repoJSON(id: $0.id, name: $0.name) }.joined(separator: ",")
        return "{\"total_count\":\(totalCount),\"items\":[\(items)]}"
    }

    /// `httpClient.data` stub returning a fixed 200 body regardless of page.
    private nonisolated func cannedClient(_ json: String) -> @Sendable (Endpoint) async throws -> (Data, HTTPURLResponse) {
        { @Sendable _ in (Data(json.utf8), Self.ok) }
    }

    /// Page-aware stub: `page=2` → `page2`, otherwise `page1`.
    private nonisolated func pagedClient(page1: String, page2: String) -> @Sendable (Endpoint) async throws -> (Data, HTTPURLResponse) {
        { @Sendable endpoint in
            let page = endpoint.queryItems.first { $0.name == "page" }?.value
            return (Data((page == "2" ? page2 : page1).utf8), Self.ok)
        }
    }

    /// `httpClient.data` stub that always fails.
    private nonisolated func failingClient(_ error: NetworkError) -> @Sendable (Endpoint) async throws -> (Data, HTTPURLResponse) {
        { @Sendable _ in throw error }
    }

    private nonisolated static var ok: HTTPURLResponse {
        HTTPURLResponse(url: URL(string: "https://api.github.com")!, statusCode: 200, httpVersion: nil, headerFields: nil)!
    }

    // MARK: - E2E-1 (R1): submit → save recent → loaded results → web view push

    @Test
    func fullJourney_submit_to_results_to_webView() async {
        let item1 = repoItem(id: 1, name: "swift")
        let item2 = repoItem(id: 2, name: "swift-syntax")
        let json = searchJSON([(1, "swift"), (2, "swift-syntax")], totalCount: 2)

        let store = TestStore(
            initialState: AppFeature.State(search: SearchFeature.State(query: "swift"))
        ) {
            AppFeature()
        } withDependencies: {
            $0.userDefaults = .previewValue
            $0.date = .constant(now)
            $0.httpClient.data = cannedClient(json)
        }

        // 제출 → 결과 로드보다 최근 검색어 저장이 선행(search P7).
        await store.send(.search(.searchSubmitted))
        await store.receive(\.search.recent.saveQuery) {
            $0.search.recent.items = [SearchRecentItem(query: "swift", date: now)]
        }
        await store.receive(\.search.result.searchRequested) {
            $0.search.result.query = "swift"
            $0.search.result.currentPage = 1
            $0.search.result.phase = .loading
        }
        // 실데이터 결과 loaded(decode+매핑이 items 로 반영됨).
        await store.receive(\.search.result.searchResponse) {
            $0.search.result.totalCount = 2
            $0.search.result.items = [item1, item2]
            $0.search.result.phase = .loaded
        }
        #expect(store.state.search.isShowingResults)

        // 행 선택 → 웹뷰 push(webview P1).
        await store.send(.search(.result(.rowTapped(item1))))
        await store.receive(\.search.result.delegate) {
            $0.search.destination = WebViewFeature.State(
                title: "swift",
                url: URL(string: "https://github.com/apple/swift")!
            )
        }
    }

    // MARK: - E2E-2 (R2): recent selection → save → loaded results → web view push

    @Test
    func recentSelection_journey_to_webView() async {
        let item1 = repoItem(id: 1, name: "swift")
        let item2 = repoItem(id: 2, name: "swift-syntax")
        let json = searchJSON([(1, "swift"), (2, "swift-syntax")], totalCount: 2)

        let store = TestStore(initialState: AppFeature.State()) {
            AppFeature()
        } withDependencies: {
            $0.userDefaults = .previewValue
            $0.date = .constant(now)
            $0.httpClient.data = cannedClient(json)
        }

        await store.send(.search(.recent(.delegate(.selected("swift"))))) {
            $0.search.query = "swift"
        }
        await store.receive(\.search.recent.saveQuery) {
            $0.search.recent.items = [SearchRecentItem(query: "swift", date: now)]
        }
        await store.receive(\.search.result.searchRequested) {
            $0.search.result.query = "swift"
            $0.search.result.currentPage = 1
            $0.search.result.phase = .loading
        }
        await store.receive(\.search.result.searchResponse) {
            $0.search.result.totalCount = 2
            $0.search.result.items = [item1, item2]
            $0.search.result.phase = .loaded
        }

        await store.send(.search(.result(.rowTapped(item2))))
        await store.receive(\.search.result.delegate) {
            $0.search.destination = WebViewFeature.State(
                title: "swift-syntax",
                url: URL(string: "https://github.com/apple/swift-syntax")!
            )
        }
    }

    // MARK: - E2E-3 (R3/E4): editing results returns to input (cancel resets results)

    @Test
    func editingResults_returnsToInput() async {
        let store = TestStore(
            initialState: AppFeature.State(
                search: SearchFeature.State(
                    query: "swift",
                    result: SearchResultFeature.State(query: "swift", phase: .loaded)
                )
            )
        ) {
            AppFeature()
        }
        #expect(store.state.search.isShowingResults)

        await store.send(.search(.binding(.set(\.query, "")))) {
            $0.search.query = ""
        }
        await store.receive(\.search.result.searchCleared) {
            $0.search.result = SearchResultFeature.State()
        }
        await store.receive(\.search.recent.queryChanged)
        #expect(!store.state.search.isShowingResults)
    }

    // MARK: - E2E-4a (R4/E2): empty results → .empty, recent still saved

    @Test
    func submit_emptyResults_savesRecent_andEmptyPhase() async {
        let json = searchJSON([], totalCount: 0)
        let store = TestStore(initialState: AppFeature.State(search: SearchFeature.State(query: "swift"))) {
            AppFeature()
        } withDependencies: {
            $0.userDefaults = .previewValue
            $0.date = .constant(now)
            $0.httpClient.data = cannedClient(json)
        }

        await store.send(.search(.searchSubmitted))
        await store.receive(\.search.recent.saveQuery) {
            $0.search.recent.items = [SearchRecentItem(query: "swift", date: now)]
        }
        await store.receive(\.search.result.searchRequested) {
            $0.search.result.query = "swift"
            $0.search.result.currentPage = 1
            $0.search.result.phase = .loading
        }
        await store.receive(\.search.result.searchResponse) {
            $0.search.result.phase = .empty
        }
        #expect(store.state.search.recent.items == [SearchRecentItem(query: "swift", date: now)])
        #expect(store.state.search.result.phase == .empty)
    }

    // MARK: - E2E-4b (R4/E3): network error → .error, recent still saved

    @Test
    func submit_networkError_savesRecent_andErrorPhase() async {
        let store = TestStore(initialState: AppFeature.State(search: SearchFeature.State(query: "swift"))) {
            AppFeature()
        } withDependencies: {
            $0.userDefaults = .previewValue
            $0.date = .constant(now)
            $0.httpClient.data = failingClient(.httpStatus(503))
        }

        await store.send(.search(.searchSubmitted))
        await store.receive(\.search.recent.saveQuery) {
            $0.search.recent.items = [SearchRecentItem(query: "swift", date: now)]
        }
        await store.receive(\.search.result.searchRequested) {
            $0.search.result.query = "swift"
            $0.search.result.currentPage = 1
            $0.search.result.phase = .loading
        }
        await store.receive(\.search.result.searchResponse) {
            $0.search.result.phase = .error
        }
        #expect(store.state.search.recent.items == [SearchRecentItem(query: "swift", date: now)])
        #expect(store.state.search.result.phase == .error)
    }

    // MARK: - E2E-5 (R5): loaded → 70% rowAppeared → next page prefetched & appended

    @Test
    func loaded_prefetchesNextPage_at70Percent() async {
        let page1 = (1...10).map { repoItem(id: $0, name: "repo\($0)") }
        let page2 = (11...20).map { repoItem(id: $0, name: "repo\($0)") }
        let json1 = searchJSON((1...10).map { (id: $0, name: "repo\($0)") }, totalCount: 100)
        let json2 = searchJSON((11...20).map { (id: $0, name: "repo\($0)") }, totalCount: 100)

        let store = TestStore(initialState: AppFeature.State(search: SearchFeature.State(query: "swift"))) {
            AppFeature()
        } withDependencies: {
            $0.userDefaults = .previewValue
            $0.date = .constant(now)
            $0.httpClient.data = pagedClient(page1: json1, page2: json2)
        }

        await store.send(.search(.searchSubmitted))
        await store.receive(\.search.recent.saveQuery) {
            $0.search.recent.items = [SearchRecentItem(query: "swift", date: now)]
        }
        await store.receive(\.search.result.searchRequested) {
            $0.search.result.query = "swift"
            $0.search.result.currentPage = 1
            $0.search.result.phase = .loading
        }
        await store.receive(\.search.result.searchResponse) {
            $0.search.result.totalCount = 100
            $0.search.result.items.append(contentsOf: page1)
            $0.search.result.hasNextPage = true
            $0.search.result.phase = .loaded
        }

        // 현재 목록(10)의 70% 지점(index 7)에 도달 → 다음 페이지 prefetch (search-result R8/P10).
        await store.send(.search(.result(.rowAppeared(page1[7])))) {
            $0.search.result.isLoadingNextPage = true
        }
        await store.receive(\.search.result.nextPageResponse) {
            $0.search.result.isLoadingNextPage = false
            $0.search.result.currentPage = 2
            $0.search.result.items.append(contentsOf: page2)
        }
    }
}

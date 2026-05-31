import ComposableArchitecture
import Core
import Foundation
import Testing

@testable import SearchFeature

/// Reducer tests for the search screen shell (docs/specs/search/spec.md §8) plus the
/// composition wiring: recent save-before-search (search-recent R7/R8), results trigger,
/// cancel→reset, and web view push (search-result R1/R4/R5).
@MainActor
struct SearchFeatureTests {
    /// `httpClient` stub returning an empty result set — keeps these wiring tests light
    /// (detailed result behavior lives in `SearchResultFeatureTests`).
    private nonisolated func emptyResults() -> @Sendable (Endpoint) async throws -> (Data, HTTPURLResponse) {
        { @Sendable _ in
            (
                Data(#"{"total_count":0,"items":[]}"#.utf8),
                HTTPURLResponse(
                    url: URL(string: "https://api.github.com")!,
                    statusCode: 200,
                    httpVersion: nil,
                    headerFields: nil
                )!
            )
        }
    }

    // R4: 입력 시 query 가 실시간 갱신된다.
    @Test
    func typingUpdatesQuery() async {
        let store = TestStore(initialState: SearchFeature.State()) {
            SearchFeature()
        }

        await store.send(.binding(.set(\.query, "swift"))) {
            $0.query = "swift"
        }
        // idle 에서 타이핑은 결과를 건드리지 않고 자식에 query 만 전달(P4).
        await store.receive(.recent(.queryChanged("swift"))) {
            $0.recent.query = "swift"
        }
    }

    // E1 / P1: 공백만 입력하면 검색어 없음과 동일하다.
    @Test
    func whitespaceOnlyQueryHasNoActiveSearch() {
        let state = SearchFeature.State(query: "   ")
        #expect(state.sanitizedQuery == "")
        #expect(state.hasActiveSearch == false)
    }

    // E2: 앞뒤 공백은 trim 되어 유효 검색어가 된다.
    @Test
    func surroundingWhitespaceIsTrimmed() {
        let state = SearchFeature.State(query: "  swift  ")
        #expect(state.sanitizedQuery == "swift")
        #expect(state.hasActiveSearch == true)
    }

    // E4 / cancel (R5): query 를 빈 문자열로 set 하면 검색 비활성 + 결과 리셋.
    @Test
    func cancelClearsActiveSearchAndResults() async {
        let store = TestStore(
            initialState: SearchFeature.State(
                query: "swift",
                result: SearchResultFeature.State(query: "swift", phase: .loaded)
            )
        ) {
            SearchFeature()
        }

        await store.send(.binding(.set(\.query, ""))) {
            $0.query = ""
        }
        await store.receive(.result(.searchCleared)) {
            $0.result = SearchResultFeature.State()
        }
        await store.receive(.recent(.queryChanged("")))
        #expect(store.state.hasActiveSearch == false)
        #expect(store.state.isShowingResults == false)
    }

    // P4 / isShowingResults: 결과가 뜬 상태에서 재타이핑 → 결과 idle 리셋(자동완성으로 복귀).
    @Test
    func editingResultsReturnsToInput() async {
        let store = TestStore(
            initialState: SearchFeature.State(
                query: "swift",
                result: SearchResultFeature.State(query: "swift", phase: .loaded)
            )
        ) {
            SearchFeature()
        }
        #expect(store.state.isShowingResults == true)

        await store.send(.binding(.set(\.query, "swiftu"))) {
            $0.query = "swiftu"
        }
        await store.receive(.result(.searchCleared)) {
            $0.result = SearchResultFeature.State()
        }
        await store.receive(.recent(.queryChanged("swiftu"))) {
            $0.recent.query = "swiftu"
        }
        #expect(store.state.isShowingResults == false)
    }

    // P4: 결과가 이미 그 검색어로 떠 있으면(제출 직후 동일 텍스트 re-commit) 결과 유지(리셋 안 함).
    @Test
    func bindingWithSearchedQueryKeepsResults() async {
        let store = TestStore(
            initialState: SearchFeature.State(
                query: "swift",
                result: SearchResultFeature.State(query: "swift", phase: .loaded)
            )
        ) {
            SearchFeature()
        }

        await store.send(.binding(.set(\.query, "swift")))   // 동일 텍스트
        await store.receive(.recent(.queryChanged("swift"))) {
            $0.recent.query = "swift"
        }
        // searchCleared 미발생 → 결과 유지.
        #expect(store.state.isShowingResults == true)
    }

    // R7 / P7: 검색 확정 → 결과 로드보다 먼저 최근 검색어 저장, 그 다음 결과 요청.
    @Test
    func submitSavesRecentThenRequestsResults() async {
        let now = Date(timeIntervalSince1970: 7)
        let store = TestStore(initialState: SearchFeature.State(query: "swift")) {
            SearchFeature()
        } withDependencies: {
            $0.userDefaults = .previewValue
            $0.date = .constant(now)
            $0.httpClient.data = emptyResults()
        }

        await store.send(.searchSubmitted)
        await store.receive(.recent(.saveQuery("swift"))) {
            $0.recent.items = [SearchRecentItem(query: "swift", date: now)]
        }
        await store.receive(.result(.searchRequested("swift"))) {
            $0.result.query = "swift"
            $0.result.currentPage = 1
            $0.result.phase = .loading
        }
        await store.receive(.result(.searchResponse(.success(RepositoryPage(items: [], totalCount: 0))))) {
            $0.result.phase = .empty
        }
        // P3: 엔터 → 즉시 결과 표시.
        #expect(store.state.isShowingResults == true)
    }

    // 빈/공백 검색 확정은 아무 동작도 하지 않는다.
    @Test
    func submitWithBlankDoesNothing() async {
        let store = TestStore(initialState: SearchFeature.State(query: "   ")) {
            SearchFeature()
        } withDependencies: {
            $0.userDefaults = .previewValue
        }

        await store.send(.searchSubmitted)
    }

    // R8 / R7: 최근 검색어 선택 → query 반영 + 저장(이동 선행) → 결과 요청.
    @Test
    func recentSelectionSetsQuerySavesThenRequestsResults() async {
        let now = Date(timeIntervalSince1970: 9)
        let store = TestStore(initialState: SearchFeature.State()) {
            SearchFeature()
        } withDependencies: {
            $0.userDefaults = .previewValue
            $0.date = .constant(now)
            $0.httpClient.data = emptyResults()
        }

        await store.send(.recent(.delegate(.selected("swift")))) {
            $0.query = "swift"
        }
        await store.receive(.recent(.saveQuery("swift"))) {
            $0.recent.items = [SearchRecentItem(query: "swift", date: now)]
        }
        await store.receive(.result(.searchRequested("swift"))) {
            $0.result.query = "swift"
            $0.result.currentPage = 1
            $0.result.phase = .loading
        }
        await store.receive(.result(.searchResponse(.success(RepositoryPage(items: [], totalCount: 0))))) {
            $0.result.phase = .empty
        }
    }

    // R4: 결과 행 선택 → 유효 url 이면 웹뷰를 push 한다.
    @Test
    func resultSelectionPushesWebView() async {
        let item = RepositoryItem(
            id: 1,
            thumbnail: nil,
            title: "swift",
            description: "apple",
            landingUrl: URL(string: "https://github.com/apple/swift")
        )
        let store = TestStore(initialState: SearchFeature.State()) {
            SearchFeature()
        }

        await store.send(.result(.delegate(.repositorySelected(item)))) {
            $0.destination = WebViewFeature.State(title: "swift", url: URL(string: "https://github.com/apple/swift")!)
        }
    }

    // webview P1: landingUrl 이 없으면 push 하지 않는다.
    @Test
    func resultSelectionWithoutURLDoesNotPush() async {
        let item = RepositoryItem(id: 1, thumbnail: nil, title: "swift", description: "apple", landingUrl: nil)
        let store = TestStore(initialState: SearchFeature.State()) {
            SearchFeature()
        }

        await store.send(.result(.delegate(.repositorySelected(item))))
        #expect(store.state.destination == nil)
    }
}

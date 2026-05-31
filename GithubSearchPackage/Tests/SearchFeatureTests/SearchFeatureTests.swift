import ComposableArchitecture
import Core
import Foundation
import Testing

@testable import SearchFeature

/// Reducer tests for the search screen shell (docs/specs/search/spec.md §8) plus the
/// recent-search composition (docs/specs/search-recent/spec.md R7/R8).
@MainActor
struct SearchFeatureTests {
    // R4: 입력 시 query 가 실시간 갱신된다.
    @Test
    func typingUpdatesQuery() async {
        let store = TestStore(initialState: SearchFeature.State()) {
            SearchFeature()
        }

        await store.send(.binding(.set(\.query, "swift"))) {
            $0.query = "swift"
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

    // E4 / cancel: query 를 빈 문자열로 set 하면 검색 비활성.
    @Test
    func cancelClearsActiveSearch() async {
        let store = TestStore(initialState: SearchFeature.State(query: "swift")) {
            SearchFeature()
        }

        await store.send(.binding(.set(\.query, ""))) {
            $0.query = ""
        }
        #expect(store.state.hasActiveSearch == false)
    }

    // R7 / P7: 검색 확정 시 결과 로드보다 먼저 최근 검색어에 저장한다.
    @Test
    func submitSavesQueryToRecent() async {
        let now = Date(timeIntervalSince1970: 7)
        let store = TestStore(initialState: SearchFeature.State(query: "swift")) {
            SearchFeature()
        } withDependencies: {
            $0.userDefaults = .previewValue
            $0.date = .constant(now)
        }

        await store.send(.searchSubmitted)
        await store.receive(.recent(.saveQuery("swift"))) {
            $0.recent.items = [SearchRecentItem(query: "swift", date: now)]
        }
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

    // R8 / R7: 최근 검색어 선택 → query 반영 + 저장(이동 선행).
    @Test
    func recentSelectionSetsQueryAndSaves() async {
        let now = Date(timeIntervalSince1970: 9)
        let store = TestStore(initialState: SearchFeature.State()) {
            SearchFeature()
        } withDependencies: {
            $0.userDefaults = .previewValue
            $0.date = .constant(now)
        }

        await store.send(.recent(.delegate(.selected("swift")))) {
            $0.query = "swift"
        }
        await store.receive(.recent(.saveQuery("swift"))) {
            $0.recent.items = [SearchRecentItem(query: "swift", date: now)]
        }
    }
}

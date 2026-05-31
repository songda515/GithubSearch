import ComposableArchitecture
import Testing

@testable import SearchFeature

/// Reducer tests for the search screen shell (Task 4). Maps 1:1 to
/// docs/specs/search/spec.md §8 수용 기준. View-layer behavior (large title,
/// title collapse, cancel button) is verified by screenshot, not here.
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

    // R5 / P2: 검색 확정 시 query 가 유지되고 상태·이펙트 변화가 없다.
    @Test
    func submitKeepsQueryWithNoEffect() async {
        let store = TestStore(initialState: SearchFeature.State(query: "swift")) {
            SearchFeature()
        }

        // TestStore 는 상태 변화/이펙트가 없음을 exhaustive 하게 검증한다.
        await store.send(.searchSubmitted)
        #expect(store.state.query == "swift")
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

    // E4: cancel(query 를 빈 문자열로) 시 Idle 로 복귀한다.
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
}

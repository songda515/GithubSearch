import ComposableArchitecture
import Testing

@testable import AppFeature

/// Reducer tests use TCA's `TestStore` (exhaustive by default) with Swift Testing.
@MainActor
struct AppFeatureTests {
    // 합성: 루트가 검색 화면(child)으로 query 바인딩을 전달한다.
    @Test
    func forwardsQueryToSearchChild() async {
        let store = TestStore(initialState: AppFeature.State()) {
            AppFeature()
        }

        await store.send(.search(.binding(.set(\.query, "swift")))) {
            $0.search.query = "swift"
        }
        // idle 에서 타이핑은 자식에 query 만 전달(Task 7, search P4).
        await store.receive(\.search.recent.queryChanged) {
            $0.search.recent.query = "swift"
        }
    }
}

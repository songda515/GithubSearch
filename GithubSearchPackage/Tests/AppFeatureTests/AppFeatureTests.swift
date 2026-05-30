import ComposableArchitecture
import Testing

@testable import AppFeature

/// Reducer tests use TCA's `TestStore` (exhaustive by default) with Swift Testing.
@MainActor
struct AppFeatureTests {
    @Test
    func onAppear_doesNothing() async {
        let store = TestStore(initialState: AppFeature.State()) {
            AppFeature()
        }

        // No state mutation and no effects expected — TestStore asserts this exhaustively.
        await store.send(.onAppear)
    }
}

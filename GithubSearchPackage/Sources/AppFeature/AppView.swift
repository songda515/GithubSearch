import ComposableArchitecture
import SearchFeature
import SwiftUI

/// Root view. Renders the scoped search screen. The thin app shell calls
/// `AppView.make()` without needing to import TCA.
public struct AppView: View {
    let store: StoreOf<AppFeature>

    public init(store: StoreOf<AppFeature>) {
        self.store = store
    }

    public var body: some View {
        SearchView(store: store.scope(state: \.search, action: \.search))
    }
}

public extension AppView {
    /// Convenience factory so the thin app shell does not need to import TCA.
    static func make() -> AppView {
        AppView(
            store: Store(initialState: AppFeature.State()) {
                AppFeature()
            }
        )
    }
}

#Preview {
    AppView.make()
}

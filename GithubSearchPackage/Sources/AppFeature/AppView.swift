import ComposableArchitecture
import SwiftUI

/// Root view. Pattern for every screen: a SwiftUI `View` driven by a
/// `StoreOf<SomeFeature>`. State is observed automatically via `@ObservableState`.
public struct AppView: View {
    let store: StoreOf<AppFeature>

    public init(store: StoreOf<AppFeature>) {
        self.store = store
    }

    public var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "globe")
                .imageScale(.large)
                .foregroundStyle(.tint)
            Text("GithubSearch")
                .font(.headline)
            Text("SwiftUI + TCA harness ready")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding()
        .onAppear { store.send(.onAppear) }
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

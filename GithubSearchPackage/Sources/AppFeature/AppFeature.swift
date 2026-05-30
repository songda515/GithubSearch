import ComposableArchitecture

/// Root feature. Every screen in the app is a `@Reducer` paired with a SwiftUI
/// `View`. This is intentionally minimal — it only proves the TCA wiring builds.
/// Add child features via `Scope` / `ifLet` / `forEach` as the app grows.
@Reducer
public struct AppFeature {
    @ObservableState
    public struct State: Equatable {
        public init() {}
    }

    public enum Action {
        case onAppear
    }

    public init() {}

    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .onAppear:
                return .none
            }
        }
    }
}

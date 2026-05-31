import ComposableArchitecture
import SearchFeature

/// App composition root. Hosts each screen's feature via `Scope`. Currently the
/// app is the search screen; add siblings here as the app grows.
@Reducer
public struct AppFeature {
    @ObservableState
    public struct State: Equatable {
        public var search: SearchFeature.State

        public init(search: SearchFeature.State = .init()) {
            self.search = search
        }
    }

    public enum Action {
        case search(SearchFeature.Action)
    }

    public init() {}

    public var body: some ReducerOf<Self> {
        Scope(state: \.search, action: \.search) {
            SearchFeature()
        }
    }
}

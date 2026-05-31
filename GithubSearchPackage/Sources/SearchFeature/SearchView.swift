import ComposableArchitecture
import SwiftUI

/// Search screen shell. Large navigation title + a `.searchable` bar. When there is no
/// active query the content is the recent-searches list; the results area arrives in
/// Task 6. Title collapse and the Cancel button are `.searchable` built-ins.
public struct SearchView: View {
    @Bindable var store: StoreOf<SearchFeature>

    public init(store: StoreOf<SearchFeature>) {
        self.store = store
    }

    public var body: some View {
        NavigationStack {
            Group {
                if store.hasActiveSearch {
                    SearchResultView(store: store.scope(state: \.result, action: \.result))
                } else {
                    SearchRecentView(store: store.scope(state: \.recent, action: \.recent))
                }
            }
            .navigationTitle("Search")
            .searchable(text: $store.query, prompt: "저장소 검색")
            .onSubmit(of: .search) {
                store.send(.searchSubmitted)
            }
            .navigationDestination(
                item: $store.scope(state: \.destination, action: \.destination)
            ) { webViewStore in
                WebView(store: webViewStore)
            }
        }
    }
}

public extension SearchView {
    /// Convenience factory for previews / standalone hosting.
    static func make() -> SearchView {
        SearchView(
            store: Store(initialState: SearchFeature.State()) {
                SearchFeature()
            }
        )
    }
}

#Preview {
    SearchView.make()
}

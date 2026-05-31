import ComposableArchitecture
import SwiftUI

/// Search screen shell. Large navigation title + a `.searchable` bar over an
/// (currently empty) content area. Title collapse and the Cancel button are
/// `.searchable`'s built-in behavior. Recent/results fill the content in Task 5/6.
public struct SearchView: View {
    @Bindable var store: StoreOf<SearchFeature>

    public init(store: StoreOf<SearchFeature>) {
        self.store = store
    }

    public var body: some View {
        NavigationStack {
            // 하단 컨텐츠 영역: 현재는 빈 영역.
            Color.clear
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .navigationTitle("Search")
                .searchable(text: $store.query, prompt: "저장소 검색")
                .onSubmit(of: .search) {
                    store.send(.searchSubmitted)
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

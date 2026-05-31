import ComposableArchitecture
import SwiftUI

/// 최근 검색어 목록. 항목 탭 → 검색 전환 위임, row 의 close → 개별 삭제, 전체 삭제 → 확인 Alert.
/// 비어 있으면 empty view. (docs/specs/search-recent/spec.md)
public struct SearchRecentView: View {
    @Bindable var store: StoreOf<SearchRecentFeature>

    public init(store: StoreOf<SearchRecentFeature>) {
        self.store = store
    }

    public var body: some View {
        Group {
            if store.isEmpty {
                ContentUnavailableView("최근 검색어가 없습니다", systemImage: "clock.arrow.circlepath")
            } else {
                List {
                    Section {
                        ForEach(store.items) { item in
                            HStack {
                                Button(item.query) { store.send(.itemTapped(item)) }
                                    .buttonStyle(.plain)
                                Spacer()
                                Button {
                                    store.send(.deleteButtonTapped(item))
                                } label: {
                                    Image(systemName: "xmark")
                                        .foregroundStyle(.secondary)
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel("삭제")
                            }
                        }
                    } header: {
                        HStack {
                            Text("최근 검색")
                            Spacer()
                            Button("전체삭제", role: .destructive) {
                                store.send(.deleteAllButtonTapped)
                            }
                        }
                    }
                }
            }
        }
        .task { await store.send(.task).finish() }
        .alert($store.scope(state: \.alert, action: \.alert))
    }
}

public extension SearchRecentView {
    static func make() -> SearchRecentView {
        SearchRecentView(
            store: Store(initialState: SearchRecentFeature.State()) {
                SearchRecentFeature()
            }
        )
    }
}

#Preview {
    SearchRecentView.make()
}

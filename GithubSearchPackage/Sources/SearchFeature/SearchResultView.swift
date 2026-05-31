import ComposableArchitecture
import Kingfisher
import SwiftUI

/// 검색 결과 목록. `{개수}개 저장소` 헤더 + 원형 아바타·이름(bold)·소유자(gray) 행, 빈/에러 화면,
/// 마지막 행 도달 시 load-more. (docs/specs/search-result/spec.md §3)
public struct SearchResultView: View {
    let store: StoreOf<SearchResultFeature>

    public init(store: StoreOf<SearchResultFeature>) {
        self.store = store
    }

    public var body: some View {
        switch store.phase {
        case .idle, .loading:
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)

        case .empty:
            ContentUnavailableView(
                "검색 결과 없음",
                systemImage: "magnifyingglass",
                description: Text("다른 검색어로 시도해 보세요.")
            )

        case .error:
            ContentUnavailableView {
                Label("네트워크 오류", systemImage: "wifi.slash")
            } description: {
                Text("잠시 후 다시 시도해 주세요.")
            } actions: {
                Button("다시 시도") { store.send(.searchRequested(store.query)) }
            }

        case .loaded:
            List {
                Section {
                    ForEach(store.items) { item in
                        Button { store.send(.rowTapped(item)) } label: {
                            row(item)
                        }
                        .buttonStyle(.plain)
                        .onAppear {
                            // 마지막 행 도달 시 다음 페이지 load-more (R6).
                            if item.id == store.items.last?.id {
                                store.send(.reachedBottom)
                            }
                        }
                    }
                } header: {
                    Text("\(store.totalCount)개 저장소")
                }
            }
            .listStyle(.plain)
        }
    }

    private func row(_ item: RepositoryItem) -> some View {
        HStack(spacing: 12) {
            KFImage(item.thumbnail)
                .placeholder { Circle().fill(Color.gray.opacity(0.3)) }   // E4 아바타 로드 실패
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 44, height: 44)
                .clipShape(Circle())
            VStack(alignment: .leading, spacing: 2) {
                Text(item.title)                        // 이름 (bold/black)
                    .font(.body.bold())
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                Text(item.description)                  // 소유자 (normal/gray)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
        }
    }
}

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
            if store.isFiltering {
                autocomplete          // 입력 중 → 자동완성 (R9–R11)
            } else {
                recentList            // 빈 query → 최근 검색어
            }
        }
        .task { await store.send(.task).finish() }
        .alert($store.scope(state: \.alert, action: \.alert))
    }

    /// 최근 검색어 목록(개별/전체 삭제 + 헤더). query 가 비어 있을 때.
    @ViewBuilder
    private var recentList: some View {
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

    /// 자동완성 목록. 최근 검색어 UI 와 다른 레이아웃(R11): 헤더·삭제 없음, `{검색어 하이라이트} {날짜 MM.dd}`.
    @ViewBuilder
    private var autocomplete: some View {
        if store.suggestions.isEmpty {
            ContentUnavailableView("검색어 없음", systemImage: "magnifyingglass")   // E6
        } else {
            List {
                ForEach(store.suggestions) { item in
                    Button {
                        store.send(.suggestionTapped(item))
                    } label: {
                        HStack {
                            highlighted(item.query, query: store.query)             // R10
                            Spacer()
                            Text(item.date.formatted(Self.monthDay))                // R10/P13 MM.dd
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .listStyle(.plain)
        }
    }

    /// 일치 부분 bold, 그 외 normal (R10). 대소문자 무시.
    private func highlighted(_ text: String, query: String) -> Text {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty, let range = text.range(of: q, options: .caseInsensitive) else {
            return Text(text)
        }
        return Text(text[text.startIndex..<range.lowerBound])
            + Text(text[range]).bold()
            + Text(text[range.upperBound...])
    }

    /// `MM.dd` 고정 포맷. Sendable 값 타입(P13).
    private static let monthDay = Date.VerbatimFormatStyle(
        format: "\(month: .twoDigits).\(day: .twoDigits)",
        timeZone: .current,
        calendar: .current
    )
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

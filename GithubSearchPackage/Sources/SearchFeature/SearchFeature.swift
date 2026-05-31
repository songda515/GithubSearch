import ComposableArchitecture
import Foundation

/// Search screen shell. Owns the search `query` + trim policy, and hosts the recent
/// searches child. On submit / recent selection it saves the query to recent searches
/// **before** results load (spec R7/P7). Result navigation + WebView destination come
/// in Task 6. (docs/specs/search/spec.md)
@Reducer
public struct SearchFeature {
    @ObservableState
    public struct State: Equatable {
        /// Search input bound to `.searchable`.
        public var query: String
        /// 최근 검색어 child.
        public var recent: SearchRecentFeature.State

        public init(query: String = "", recent: SearchRecentFeature.State = .init()) {
            self.query = query
            self.recent = recent
        }

        /// 유효 검색어. 앞뒤 공백·개행을 제거한 값. 빈 문자열이면 "검색어 없음"과 동일 (spec P1).
        public var sanitizedQuery: String {
            query.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        /// trim 후 검색어가 존재하는가.
        public var hasActiveSearch: Bool { !sanitizedQuery.isEmpty }
    }

    public enum Action: BindableAction, Equatable {
        /// `query` 업데이트 및 cancel(빈 문자열 set).
        case binding(BindingAction<State>)
        /// 검색 확정 (`.onSubmit(of: .search)`).
        case searchSubmitted
        case recent(SearchRecentFeature.Action)
    }

    public init() {}

    public var body: some ReducerOf<Self> {
        BindingReducer()
        Scope(state: \.recent, action: \.recent) {
            SearchRecentFeature()
        }
        Reduce { state, action in
            switch action {
            case .binding:
                return .none

            case .searchSubmitted:
                // 검색 확정 시 결과 로드보다 먼저 최근 검색어 저장(P7). 결과 이동은 Task 6.
                let query = state.sanitizedQuery
                guard !query.isEmpty else { return .none }
                return .send(.recent(.saveQuery(query)))

            case let .recent(.delegate(.selected(query))):
                // 최근 검색어 선택 → 검색어 반영 + 저장(이동 선행). 결과 이동은 Task 6.
                state.query = query
                return .send(.recent(.saveQuery(query)))

            case .recent:
                return .none
            }
        }
    }
}

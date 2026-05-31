import ComposableArchitecture
import Foundation

/// Search screen shell (Task 4: structure only). Owns the search `query` and the
/// trim policy. Child composition (recent/result) and the WebView destination are
/// added in Task 5/6 per docs/specs/search/spec.md.
@Reducer
public struct SearchFeature {
    @ObservableState
    public struct State: Equatable {
        /// Search input bound to `.searchable`.
        public var query: String

        public init(query: String = "") {
            self.query = query
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
    }

    public init() {}

    public var body: some ReducerOf<Self> {
        BindingReducer()
        Reduce { state, action in
            switch action {
            case .binding:
                return .none
            case .searchSubmitted:
                // 구조 단계: query 유지(P2), 부수효과 없음(P3). 결과 호출은 Task 6.
                return .none
            }
        }
    }
}

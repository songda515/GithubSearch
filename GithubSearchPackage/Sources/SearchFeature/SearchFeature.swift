import ComposableArchitecture
import Foundation

/// Search screen shell. Owns the search `query` + trim policy, and hosts the recent
/// searches and results children. On submit / recent selection it saves the query to
/// recent searches **before** results load (spec R7/P7), then requests results.
/// Selecting a result row pushes a `WebViewFeature` destination. (docs/specs/search/spec.md)
@Reducer
public struct SearchFeature {
    @ObservableState
    public struct State: Equatable {
        /// Search input bound to `.searchable`.
        public var query: String
        /// 최근 검색어 child.
        public var recent: SearchRecentFeature.State
        /// 검색 결과 child.
        public var result: SearchResultFeature.State
        /// 웹뷰 push destination(단일 destination 이라 enum 래퍼 없이 직접 present).
        @Presents public var destination: WebViewFeature.State?

        public init(
            query: String = "",
            recent: SearchRecentFeature.State = .init(),
            result: SearchResultFeature.State = .init(),
            destination: WebViewFeature.State? = nil
        ) {
            self.query = query
            self.recent = recent
            self.result = result
            self.destination = destination
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
        case result(SearchResultFeature.Action)
        case destination(PresentationAction<WebViewFeature.Action>)
    }

    public init() {}

    public var body: some ReducerOf<Self> {
        BindingReducer()
        Scope(state: \.recent, action: \.recent) {
            SearchRecentFeature()
        }
        Scope(state: \.result, action: \.result) {
            SearchResultFeature()
        }
        Reduce { state, action in
            switch action {
            case .binding:
                // 취소/클리어로 검색어가 비면 결과를 리셋한다(R5/E7).
                if state.sanitizedQuery.isEmpty {
                    return .send(.result(.searchCleared))
                }
                return .none

            case .searchSubmitted:
                // 결과 로드보다 먼저 최근 검색어 저장(P7), 그 다음 결과 요청.
                let query = state.sanitizedQuery
                guard !query.isEmpty else { return .none }
                return .concatenate(
                    .send(.recent(.saveQuery(query))),
                    .send(.result(.searchRequested(query)))
                )

            case let .recent(.delegate(.selected(query))):
                // 최근 검색어 선택 → 검색어 반영 + 저장(이동 선행) → 결과 요청.
                state.query = query
                return .concatenate(
                    .send(.recent(.saveQuery(query))),
                    .send(.result(.searchRequested(query)))
                )

            case let .result(.delegate(.repositorySelected(item))):
                // 유효 url 일 때만 웹뷰 push(webview P1).
                guard let url = item.landingUrl else { return .none }
                state.destination = WebViewFeature.State(title: item.title, url: url)
                return .none

            case .recent, .result, .destination:
                return .none
            }
        }
        .ifLet(\.$destination, action: \.destination) {
            WebViewFeature()
        }
    }
}

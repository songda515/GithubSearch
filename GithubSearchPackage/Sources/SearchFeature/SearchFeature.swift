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

        /// 본문이 검색 결과를 보여주는가. 결과가 idle 이 아니면(검색 요청됨) 결과, 아니면 입력 영역
        /// (최근/자동완성). 타이핑(`binding`)은 결과를 idle 로 되돌린다 (search §3, P4).
        public var isShowingResults: Bool { result.phase != .idle }
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
                // 타이핑(입력 중)은 결과를 idle 로 되돌리고 자식에 query 를 전달한다 → 입력 영역(최근/자동완성).
                // 단, 결과가 이미 그 검색어로 떠 있으면(제출 직후 동일 텍스트 re-commit) 결과를 유지한다.
                // 결과 진입은 엔터/선택에서만 (P4, R5/E7).
                if state.isShowingResults && state.sanitizedQuery == state.result.query {
                    return .send(.recent(.queryChanged(state.query)))
                }
                return .concatenate(
                    .send(.result(.searchCleared)),
                    .send(.recent(.queryChanged(state.query)))
                )

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

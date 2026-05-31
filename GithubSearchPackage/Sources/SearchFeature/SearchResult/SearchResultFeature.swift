import ComposableArchitecture
import Core
import Foundation

/// 검색 결과 화면. 상위에서 전달받은 `query` 로 GitHub 저장소를 검색해 목록으로 보여주고,
/// 마지막 행 도달 시 다음 페이지를 이어 붙인다(기본 load-more). 항목 선택 시 웹뷰 이동을
/// 상위 `SearchFeature` 에 위임한다. (docs/specs/search-result/spec.md)
@Reducer
public struct SearchResultFeature {
    @ObservableState
    public struct State: Equatable {
        /// 상위에서 하향 전달된 검색어.
        public var query: String
        /// 결과 항목(`id` 식별자로 페이지 간 중복 제거, P5).
        public var items: IdentifiedArrayOf<RepositoryItem>
        /// 헤더에 표시할 저장소 총개수(R3).
        public var totalCount: Int
        /// 마지막으로 로드한 페이지(1-based).
        public var currentPage: Int
        /// 다음 페이지 존재 여부(P4).
        public var hasNextPage: Bool
        /// load-more 진행 중 가드(P8, E6).
        public var isLoadingNextPage: Bool
        /// 화면 표시 상태.
        public var phase: Phase

        public init(
            query: String = "",
            items: IdentifiedArrayOf<RepositoryItem> = [],
            totalCount: Int = 0,
            currentPage: Int = 0,
            hasNextPage: Bool = false,
            isLoadingNextPage: Bool = false,
            phase: Phase = .idle
        ) {
            self.query = query
            self.items = items
            self.totalCount = totalCount
            self.currentPage = currentPage
            self.hasNextPage = hasNextPage
            self.isLoadingNextPage = isLoadingNextPage
            self.phase = phase
        }

        public enum Phase: Equatable, Sendable {
            case idle, loading, loaded, empty, error
        }
    }

    public enum Action: Equatable {
        /// 새 검색: 리셋 후 첫 페이지 요청(상위 트리거, P2·P9).
        case searchRequested(String)
        /// 첫 페이지 결과.
        case searchResponse(Result<RepositoryPage, NetworkError>)
        /// 마지막 행 표시 → load-more(P3·P4·P8).
        case reachedBottom
        /// 다음 페이지 결과(append, P5).
        case nextPageResponse(Result<RepositoryPage, NetworkError>)
        /// 취소/검색어 클리어 → in-flight 취소 + 리셋(R5·E7).
        case searchCleared
        /// 행 선택 → 웹뷰 이동 위임(R4).
        case rowTapped(RepositoryItem)
        case delegate(Delegate)

        public enum Delegate: Equatable { case repositorySelected(RepositoryItem) }
    }

    private enum CancelID { case search }

    @Dependency(\.httpClient) var httpClient

    public init() {}

    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case let .searchRequested(query):
                state.query = query
                state.items = []
                state.totalCount = 0
                state.currentPage = 1
                state.hasNextPage = false
                state.isLoadingNextPage = false
                state.phase = .loading
                return fetch(query: query, page: 1) { .searchResponse($0) }
                    .cancellable(id: CancelID.search, cancelInFlight: true)   // P9/E7

            case let .searchResponse(.success(page)):
                state.totalCount = page.totalCount
                state.items = []
                state.items.append(contentsOf: page.items)                    // P5 dedup
                state.hasNextPage = Self.hasNextPage(page: 1, totalCount: page.totalCount)
                state.phase = state.items.isEmpty ? .empty : .loaded          // E1
                return .none

            case .searchResponse(.failure):
                state.phase = .error                                          // E3
                return .none

            case .reachedBottom:
                guard state.phase == .loaded,
                      state.hasNextPage,
                      !state.isLoadingNextPage                                // E6/P8
                else { return .none }
                state.isLoadingNextPage = true
                let nextPage = state.currentPage + 1
                return fetch(query: state.query, page: nextPage) { .nextPageResponse($0) }
                    .cancellable(id: CancelID.search, cancelInFlight: false)

            case let .nextPageResponse(.success(page)):
                state.isLoadingNextPage = false
                state.currentPage += 1
                state.items.append(contentsOf: page.items)                    // P3/P5 append+dedup
                state.hasNextPage = Self.hasNextPage(page: state.currentPage, totalCount: state.totalCount)
                return .none

            case .nextPageResponse(.failure):
                // 기존 결과는 유지하고 플래그만 해제(에러 토스트는 improvement).
                state.isLoadingNextPage = false
                return .none

            case .searchCleared:
                state = State()
                return .cancel(id: CancelID.search)                           // E7/R5

            case let .rowTapped(item):
                return .send(.delegate(.repositorySelected(item)))            // R4

            case .delegate:
                return .none
            }
        }
    }

    /// Build the search effect for a page, mapping the response to a domain `RepositoryPage`.
    /// Cancellation (e.g. a newer search) is dropped silently — it must not surface as an error.
    private func fetch(
        query: String,
        page: Int,
        action: @escaping @Sendable (Result<RepositoryPage, NetworkError>) -> Action
    ) -> Effect<Action> {
        let client = httpClient   // capture the Sendable client, not the reducer
        return .run { send in
            do {
                let response: GitHubSearchResponse = try await client.request(
                    GitHubSearchAPI.repositories(query: query, page: page)
                )
                await send(action(.success(RepositoryPage(response))))
            } catch {
                guard !Task.isCancelled else { return }                       // E7
                await send(action(.failure(error.asNetworkError)))
            }
        }
    }

    /// `page * perPage < min(totalCount, 1000)` (P4).
    static func hasNextPage(page: Int, totalCount: Int) -> Bool {
        page * GitHubSearchAPI.perPage < min(totalCount, GitHubSearchAPI.maxResults)
    }
}

private extension Error {
    /// `httpClient.request` only throws `NetworkError`; this is a defensive fallback.
    var asNetworkError: NetworkError {
        (self as? NetworkError) ?? .transport(String(describing: self))
    }
}

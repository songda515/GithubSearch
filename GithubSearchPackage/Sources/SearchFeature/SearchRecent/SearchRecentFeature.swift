import ComposableArchitecture
import Core
import Foundation

/// 검색 입력 화면의 최근 검색어 영역. 표시·개별/전체 삭제·영속화를 담당한다.
/// 검색 전환(결과 화면)은 상위 `SearchFeature` 에 위임한다. (docs/specs/search-recent/spec.md)
@Reducer
public struct SearchRecentFeature {
    /// UserDefaults 저장 키.
    public static let storageKey = "recentSearches"
    /// 최근 검색어 최대 개수 (P2).
    public static let maxCount = 10

    @ObservableState
    public struct State: Equatable {
        /// 날짜 내림차순(P3)으로 유지되는 최근 검색어.
        public var items: [SearchRecentItem]
        /// 상위(`SearchFeature`)가 전달하는 입력 필터 텍스트. parent 가 SoT, child 는 자동완성 계산용 (Task 7).
        public var query: String
        @Presents public var alert: AlertState<Action.Alert>?

        public init(items: [SearchRecentItem] = [], query: String = "") {
            self.items = items
            self.query = query
        }

        public var isEmpty: Bool { items.isEmpty }

        /// 입력 중(필터 텍스트가 trim 후 비어있지 않음).
        public var isFiltering: Bool {
            !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }

        /// 자동완성 후보. 대소문자 무시 contains 매칭(P10), 날짜 내림차순 유지. 빈 query → [].
        public var suggestions: [SearchRecentItem] {
            let q = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            guard !q.isEmpty else { return [] }
            return items.filter { $0.query.lowercased().contains(q) }
        }
    }

    public enum Action: Equatable {
        /// 진입 시 영속 저장소에서 로드.
        case task
        /// 최근 검색어 선택 → 검색 전환 위임.
        case itemTapped(SearchRecentItem)
        /// 자동완성 항목 선택 → 검색 전환 위임(R12, itemTapped 와 동일 경로).
        case suggestionTapped(SearchRecentItem)
        /// 상위가 입력 변화를 전달 → 필터 텍스트 갱신(자동완성, R9).
        case queryChanged(String)
        /// 개별 삭제(row 의 close 버튼, P8).
        case deleteButtonTapped(SearchRecentItem)
        /// 전체 삭제 버튼 → 확인 Alert.
        case deleteAllButtonTapped
        case alert(PresentationAction<Alert>)
        /// 상위가 트리거: 검색어 저장(dedup/prepend/cap/persist, P4·P5·P6·P2·P7).
        case saveQuery(String)
        case delegate(Delegate)

        public enum Alert: Equatable { case confirmDeleteAll }
        public enum Delegate: Equatable { case selected(String) }
    }

    /// 전체 삭제 확인 Alert. 리듀서와 테스트가 동일 정의를 공유하도록 둔다.
    /// (computed `var` — 매 접근 새 값이라 Swift 6 동시성 안전.)
    public static var deleteAllAlert: AlertState<Action.Alert> {
        AlertState {
            TextState("최근 검색어 전체 삭제")
        } actions: {
            ButtonState(role: .destructive, action: .confirmDeleteAll) {
                TextState("전체 삭제")
            }
            ButtonState(role: .cancel) {
                TextState("취소")
            }
        } message: {
            TextState("최근 검색어를 모두 삭제할까요?")
        }
    }

    @Dependency(\.userDefaults) var userDefaults
    @Dependency(\.date) var date

    public init() {}

    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .task:
                state.items = load()
                return .none

            case let .itemTapped(item):
                return .send(.delegate(.selected(item.query)))

            case let .suggestionTapped(item):
                return .send(.delegate(.selected(item.query)))   // R12

            case let .queryChanged(query):
                state.query = query                              // R9: suggestions 파생 갱신
                return .none

            case let .deleteButtonTapped(item):
                state.items.removeAll { $0.query == item.query }
                persist(state.items)
                return .none

            case .deleteAllButtonTapped:
                state.alert = Self.deleteAllAlert
                return .none

            case .alert(.presented(.confirmDeleteAll)):
                state.items = []
                persist(state.items)
                return .none

            case .alert:
                return .none

            case let .saveQuery(query):
                let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty else { return .none }          // E4
                // P5/P11 dedup: 대소문자 무시로 기존 제거 후 새 케이싱을 맨 앞에.
                var items = state.items.filter { $0.query.lowercased() != trimmed.lowercased() }
                items.insert(SearchRecentItem(query: trimmed, date: date.now), at: 0) // P4 prepend
                if items.count > Self.maxCount {                       // P6 cap
                    items = Array(items.prefix(Self.maxCount))
                }
                state.items = items
                persist(items)                                         // P7 저장 선행
                return .none

            case .delegate:
                return .none
            }
        }
        .ifLet(\.$alert, action: \.alert)
    }

    /// 영속 저장소에서 로드 후 날짜 내림차순 정렬(P3) + 대소문자 중복 collapse(P12, 최신 유지).
    private func load() -> [SearchRecentItem] {
        guard
            let data = userDefaults.data(Self.storageKey),
            let items = try? JSONDecoder().decode([SearchRecentItem].self, from: data)
        else { return [] }
        let sorted = items.sorted { $0.date > $1.date }
        var seen = Set<String>()
        return sorted.filter { seen.insert($0.query.lowercased()).inserted }   // P12
    }

    private func persist(_ items: [SearchRecentItem]) {
        userDefaults.setData(try? JSONEncoder().encode(items), Self.storageKey)
    }
}

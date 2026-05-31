import ComposableArchitecture
import Core
import Foundation
import Testing

@testable import SearchFeature

/// Maps 1:1 to docs/specs/search-recent/spec.md §8. View-layer (empty view, section
/// title, alert presentation) is verified by screenshot, not here.
@MainActor
struct SearchRecentFeatureTests {
    private static func encoded(_ items: [SearchRecentItem]) -> Data {
        try! JSONEncoder().encode(items)
    }

    // R1 / P3: 로드 시 날짜 내림차순.
    @Test
    func taskLoadsSortedDescending() async {
        let older = SearchRecentItem(query: "a", date: Date(timeIntervalSince1970: 0))
        let newer = SearchRecentItem(query: "b", date: Date(timeIntervalSince1970: 100))
        let client = UserDefaultsClient.previewValue
        client.setData(Self.encoded([older, newer]), SearchRecentFeature.storageKey)

        let store = TestStore(initialState: SearchRecentFeature.State()) {
            SearchRecentFeature()
        } withDependencies: {
            $0.userDefaults = client
        }

        await store.send(.task) {
            $0.items = [newer, older]
        }
    }

    // P4: 새 검색어는 맨 앞.
    @Test
    func saveQueryPrependsNewest() async {
        let now = Date(timeIntervalSince1970: 1000)
        let existing = SearchRecentItem(query: "old", date: Date(timeIntervalSince1970: 0))

        let store = TestStore(initialState: SearchRecentFeature.State(items: [existing])) {
            SearchRecentFeature()
        } withDependencies: {
            $0.userDefaults = .previewValue
            $0.date = .constant(now)
        }

        await store.send(.saveQuery("new")) {
            $0.items = [SearchRecentItem(query: "new", date: now), existing]
        }
    }

    // P5 / E2: 중복 → 기존 제거 후 맨 앞 (개수 불변).
    @Test
    func saveQueryDeduplicates() async {
        let now = Date(timeIntervalSince1970: 1000)
        let a = SearchRecentItem(query: "a", date: Date(timeIntervalSince1970: 0))
        let b = SearchRecentItem(query: "b", date: Date(timeIntervalSince1970: 500))

        let store = TestStore(initialState: SearchRecentFeature.State(items: [b, a])) {
            SearchRecentFeature()
        } withDependencies: {
            $0.userDefaults = .previewValue
            $0.date = .constant(now)
        }

        await store.send(.saveQuery("a")) {
            $0.items = [SearchRecentItem(query: "a", date: now), b]
        }
    }

    // P2 / P6 / E3: 11번째 → 가장 오래된 제거, 10개 유지.
    @Test
    func saveQueryCapsAtTen() async {
        let base = Date(timeIntervalSince1970: 0)
        // q0(최신) … q9(가장 오래됨)
        let items = (0..<10).map {
            SearchRecentItem(query: "q\($0)", date: base.addingTimeInterval(Double(100 - $0)))
        }
        let now = base.addingTimeInterval(1000)

        let store = TestStore(initialState: SearchRecentFeature.State(items: items)) {
            SearchRecentFeature()
        } withDependencies: {
            $0.userDefaults = .previewValue
            $0.date = .constant(now)
        }

        let expected = Array(([SearchRecentItem(query: "new", date: now)] + items).prefix(10))
        await store.send(.saveQuery("new")) {
            $0.items = expected
        }
    }

    // E4: 공백 검색어는 무시.
    @Test
    func saveQueryIgnoresBlank() async {
        let store = TestStore(initialState: SearchRecentFeature.State()) {
            SearchRecentFeature()
        } withDependencies: {
            $0.userDefaults = .previewValue
            $0.date = .constant(Date(timeIntervalSince1970: 0))
        }

        await store.send(.saveQuery("   "))
    }

    // R4 / P8: 개별 삭제.
    @Test
    func deleteButtonRemovesItem() async {
        let a = SearchRecentItem(query: "a", date: Date(timeIntervalSince1970: 1))
        let b = SearchRecentItem(query: "b", date: Date(timeIntervalSince1970: 0))

        let store = TestStore(initialState: SearchRecentFeature.State(items: [a, b])) {
            SearchRecentFeature()
        } withDependencies: {
            $0.userDefaults = .previewValue
        }

        await store.send(.deleteButtonTapped(a)) {
            $0.items = [b]
        }
    }

    // R6 / P9: 전체 삭제 → alert → 확인 → 비움.
    @Test
    func deleteAllShowsAlertThenClears() async {
        let a = SearchRecentItem(query: "a", date: Date(timeIntervalSince1970: 0))

        let store = TestStore(initialState: SearchRecentFeature.State(items: [a])) {
            SearchRecentFeature()
        } withDependencies: {
            $0.userDefaults = .previewValue
        }

        await store.send(.deleteAllButtonTapped) {
            $0.alert = SearchRecentFeature.deleteAllAlert
        }
        await store.send(.alert(.presented(.confirmDeleteAll))) {
            $0.alert = nil
            $0.items = []
        }
    }

    // P9: alert 취소 → 변화 없음.
    @Test
    func deleteAllCancelKeepsItems() async {
        let a = SearchRecentItem(query: "a", date: Date(timeIntervalSince1970: 0))

        let store = TestStore(initialState: SearchRecentFeature.State(items: [a])) {
            SearchRecentFeature()
        } withDependencies: {
            $0.userDefaults = .previewValue
        }

        await store.send(.deleteAllButtonTapped) {
            $0.alert = SearchRecentFeature.deleteAllAlert
        }
        await store.send(.alert(.dismiss)) {
            $0.alert = nil
        }
    }

    // R8: 항목 선택 → delegate(.selected).
    @Test
    func itemTappedDelegatesSelected() async {
        let a = SearchRecentItem(query: "swift", date: Date(timeIntervalSince1970: 0))

        let store = TestStore(initialState: SearchRecentFeature.State(items: [a])) {
            SearchRecentFeature()
        } withDependencies: {
            $0.userDefaults = .previewValue
        }

        await store.send(.itemTapped(a))
        await store.receive(.delegate(.selected("swift")))
    }

    // R7 / P7 / E5 / P1: 저장 → 영속 → 새 store 로드 round-trip.
    @Test
    func saveQueryPersistsAndReloads() async {
        let client = UserDefaultsClient.previewValue
        let now = Date(timeIntervalSince1970: 42)

        let storeA = TestStore(initialState: SearchRecentFeature.State()) {
            SearchRecentFeature()
        } withDependencies: {
            $0.userDefaults = client
            $0.date = .constant(now)
        }
        await storeA.send(.saveQuery("swift")) {
            $0.items = [SearchRecentItem(query: "swift", date: now)]
        }

        let storeB = TestStore(initialState: SearchRecentFeature.State()) {
            SearchRecentFeature()
        } withDependencies: {
            $0.userDefaults = client
        }
        await storeB.send(.task) {
            $0.items = [SearchRecentItem(query: "swift", date: now)]
        }
    }
}

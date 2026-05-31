# Search Recent Spec

> 이 화면 정책의 **SSoT** 다. 동작을 바꾸려면 코드보다 **이 문서를 먼저** 고친다.
> 전체 구조는 [`../overview.md`](../overview.md), 참고 화면은 [`search_input_requirement.PNG`](search_input_requirement.PNG).

| 항목 | 값 |
|------|----|
| Feature | `search-recent` |
| 상태 | Approved (Task 5 필수 범위) |
| 관련 이슈/PR | #11 |
| 최종 수정 | 2026-05-31 |

> **이 spec 의 범위(Task 5 = 필수):** 최근 검색어 표시·개별/전체 삭제·영속화, 그리고 검색 확정/선택 시
> "검색 결과 로드보다 먼저" 저장하는 것까지. **자동완성(입력 중 추천)은 Task 7**, **검색 결과 화면으로의
> 실제 네비게이션은 Task 6** 에서 이 spec/상위에 추가한다.

---

## 1. 개요 (Overview)
- **한 줄 설명**: 검색 화면에서 `query` 가 비어 있을 때 노출되는 최근 검색어 영역. 표시·개별/전체 삭제·영속화를 담당.
- **진입 경로**: `SearchFeature` 의 자식. 검색어가 없을 때 검색 화면 본문으로 노출.
- **TCA 모듈**: `View` = `SearchRecentView`, `Reducer` = `SearchRecentFeature`.

## 2. 화면별 요구사항 (Requirements)
- **R1.** 검색어 입력 전(검색어 없음) 최근 검색어를 **최대 10개** 노출한다.
- **R2.** 최근 검색어가 없으면 **empty view** 를 제공한다.
- **R3.** "최근 검색" **section title** 을 표시한다.
- **R4.** 각 row 는 `{검색어}` 와 **개별 삭제(close) 버튼** 으로 구성된다.
- **R5.** **전체 삭제 버튼** 을 제공한다.
- **R6.** 전체 삭제 시 **Alert 로 재확인** 한다.
- **R7.** 검색 확정 / 최근 검색어 클릭 시, **검색 결과 로드보다 먼저** 검색어를 최근 검색어에 저장한다.
- **R8.** 최근 검색어 클릭 시 검색 결과로의 이동을 상위(`SearchFeature`)에 위임한다(네비게이션 자체는 Task 6).

## 3. UI 상태 (UI States)

| 상태 | 조건 | 화면 표시 |
|------|------|-----------|
| Empty | `items` 0개 | "최근 검색" 영역에 empty view, 전체 삭제 버튼 숨김 |
| List | `items` 1개 이상 | "최근 검색" title + rows(`{검색어}`+close) + 전체 삭제 버튼 |
| DeleteAll Confirm | 전체 삭제 버튼 탭 | 전체 삭제 재확인 **Alert**(취소 / 삭제) |

> empty view / section title / alert 표시는 **뷰 레이어**이므로 화면 스크린샷으로 검증(spec §8).

## 4. 엣지 케이스 (Edge cases)

| # | 상황 | 기대 동작 |
|---|------|-----------|
| E1 | 최근 검색어 0개 | empty view, 전체 삭제 버튼 미노출 |
| E2 | 중복 검색어 저장 | 기존 항목 제거 후 맨 앞에 삽입(P5) |
| E3 | 11번째 저장 | 가장 오래된 1개 제거, 최대 10개 유지(P6) |
| E4 | 빈/공백 검색어 저장 시도 | 저장하지 않음(상위가 trim 된 검색어를 전달; 빈 값은 무시) |
| E5 | 앱 재시작 | 저장된 최근 검색어를 로드해 유지(P1) |

## 5. API 명세 (API spec)
- **외부 API 없음.** 로컬 영속만 사용.
- **저장소**: `UserDefaultsClient` (Core). key = `"recentSearches"`, 값 = `[SearchRecentItem]` 의 JSON `Data`.
- 타임스탬프는 `@Dependency(\.date)` 로 주입(테스트 가능).

## 6. 정책 (Policy)
- **P1. (영속)** 최근 검색어는 `UserDefaults` 에 저장되어 앱 재시작 시 유지된다.
- **P2. (개수)** 최대 **10개** 저장.
- **P3. (정렬)** 노출은 **날짜 내림차순**(최신 우선).
- **P4. (추가)** 새 검색어는 맨 앞(최신)으로 삽입.
- **P5. (중복)** 동일 `query` 추가 시 기존 항목을 제거하고 맨 앞에 삽입.
- **P6. (초과)** 10개 초과 시 가장 오래된 항목 제거.
- **P7. (저장 선행)** 검색 확정/선택 시 **결과 로드보다 먼저** 저장(저장→이동 순서).
- **P8. (개별 삭제)** close 버튼은 해당 항목만 제거 후 영속화.
- **P9. (전체 삭제)** Alert 확인 시 전체 제거 후 영속화. 취소 시 변화 없음.

## 7. TCA 매핑 (State / Action / Client)
- **모델 `SearchRecentItem`**: `query: String`, `date: Date`. `Codable`, `Equatable`, `Identifiable`(`id == query`, P5 로 query 유일).
- **State**:
  - `items: [SearchRecentItem]` — 날짜 내림차순 유지.
  - `@Presents var alert: AlertState<Action.Alert>?` — 전체 삭제 확인.
  - 파생 `var isEmpty: Bool { items.isEmpty }`.
- **Action**:
  - `task` — 진입 시 로드.
  - `itemTapped(SearchRecentItem)` — 선택 → `delegate(.selected(query))`.
  - `deleteButtonTapped(SearchRecentItem)` — 개별 삭제(P8).
  - `deleteAllButtonTapped` — 전체 삭제 Alert present.
  - `alert(PresentationAction<Alert>)`; `enum Alert { case confirmDeleteAll }`.
  - `saveQuery(String)` — 상위가 트리거: dedup/prepend/cap/persist(P4·P5·P6·P2) 후 저장(P7).
  - `delegate(Delegate)`; `enum Delegate { case selected(String) }`.
- **Client**: `@Dependency(\.userDefaults) UserDefaultsClient`, `@Dependency(\.date)`.

## 8. 수용 기준 (Acceptance criteria)
- [ ] **R1/P3** `task` 로드 → 날짜 내림차순, 최대 10개로 노출.
- [ ] **P4** `saveQuery` → 새 항목이 맨 앞에 삽입.
- [ ] **P5/E2** 중복 `saveQuery` → 기존 제거 후 맨 앞(개수 불변).
- [ ] **P2/P6/E3** 11번째 `saveQuery` → 가장 오래된 제거, 개수 10 유지.
- [ ] **E4** 빈/공백 `saveQuery` → 무시(변화 없음).
- [ ] **R4/P8** `deleteButtonTapped` → 해당 항목 제거 + 영속화.
- [ ] **R6/P9** `deleteAllButtonTapped` → alert present; `confirmDeleteAll` → items 비움 + 영속화.
- [ ] **P9** alert 취소 → 변화 없음.
- [ ] **R8** `itemTapped` → `delegate(.selected(query))`.
- [ ] **R7/P7** `saveQuery` 가 영속화(저장 선행)됨을 client 호출로 확인.
- [ ] **E5/P1** persist round-trip: 저장 후 새 store `task` 로드가 동일 항목을 읽음.
- [ ] **R2/R3/empty/alert** → 화면 스크린샷(XcodeBuildMCP)로 검증(뷰 레이어).

## 9. 변경 이력 (Changelog)
| 날짜 | 이슈/PR | 변경 내용 |
|------|---------|-----------|
| 2026-05-31 | #5 | 골격 스캐폴딩 (섹션1만 작성) |
| 2026-05-31 | #11 | Task 5 필수 범위 구체화(요구사항·UI·엣지·정책·TCA 매핑·수용 기준) |

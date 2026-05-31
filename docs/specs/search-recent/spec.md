# Search Recent Spec

> 이 화면 정책의 **SSoT** 다. 동작을 바꾸려면 코드보다 **이 문서를 먼저** 고친다.
> 전체 구조는 [`../overview.md`](../overview.md), 참고 화면은 [`search_input_requirement.PNG`](search_input_requirement.PNG)
> (필수), [`search_input_improvement.PNG`](search_input_improvement.PNG) (자동완성 — Task 7).

| 항목 | 값 |
|------|----|
| Feature | `search-recent` |
| 상태 | Approved (Task 5 필수 + Task 7 자동완성) |
| 관련 이슈/PR | #11, #23 |
| 최종 수정 | 2026-06-01 |

> **이 spec 의 범위:** (Task 5 필수) 최근 검색어 표시·개별/전체 삭제·영속화, 검색 확정/선택 시 "검색 결과
> 로드보다 먼저" 저장. **(Task 7 자동완성)** 입력 중 최근 검색어 자동완성(대소문자 무시 contains), 자동완성
> 전용 row UI(검색어 하이라이트 + 날짜 `MM.dd.`), 저장/로드 대소문자 무시 dedup. 검색 결과 네비게이션은 Task 6.

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
- **R9. (자동완성)** 검색어 입력 중에는 최근 검색어 중 입력 텍스트가 **contains 매칭**되는 항목을 자동완성으로 노출한다.
- **R10. (자동완성 row)** 자동완성 row 는 `{검색어}` `{spacer}` `{검색 날짜}` 구성: 검색어는 **일치 텍스트 bold, 그 외 normal** 하이라이트, 날짜는 **`MM.dd.`** 포맷(예: `06.01.`, 끝에 마침표 포함, Sendable `Date.VerbatimFormatStyle`).
- **R11. (UI 구분)** 자동완성 노출 UI 와 최근 검색어 노출 UI 는 **다른 레이아웃**으로 구현한다(데이터타입 `SearchRecentItem` 은 동일 사용).
- **R12. (자동완성 선택)** 자동완성 항목 클릭 시 최근 검색어 클릭과 **동일하게** 검색 결과 화면으로 이동한다(저장 선행 → 결과).
- **R13. (엔터)** 자동완성을 선택하지 않고 검색어에서 엔터를 누르면 검색 결과 화면으로 랜딩한다(R7 흐름 유지).

## 3. UI 상태 (UI States)

| 상태 | 조건 | 화면 표시 |
|------|------|-----------|
| Empty | `query` 빈 + `items` 0개 | "최근 검색" 영역에 empty view, 전체 삭제 버튼 숨김 |
| List | `query` 빈 + `items` 1개 이상 | "최근 검색" title + rows(`{검색어}`+close) + 전체 삭제 버튼 |
| DeleteAll Confirm | 전체 삭제 버튼 탭 | 전체 삭제 재확인 **Alert**(취소 / 삭제) |
| Autocomplete | `query` 입력 중 + 매칭 1개 이상 | 자동완성 rows(`{검색어 하이라이트}` `{spacer}` `{날짜 MM.dd.}`). 헤더·삭제 버튼 없음 |
| Autocomplete-Empty | `query` 입력 중 + 매칭 0개 | "검색어 없음" view |

> 입력 중(`query` 비어있지 않음)은 List/Empty 대신 Autocomplete 계열을 노출한다. empty view / section title /
> alert / 하이라이트 표시는 **뷰 레이어**이므로 화면 스크린샷으로 검증(spec §8).

## 4. 엣지 케이스 (Edge cases)

| # | 상황 | 기대 동작 |
|---|------|-----------|
| E1 | 최근 검색어 0개 | empty view, 전체 삭제 버튼 미노출 |
| E2 | 중복 검색어 저장 | 기존 항목 제거 후 맨 앞에 삽입(P5) |
| E3 | 11번째 저장 | 가장 오래된 1개 제거, 최대 10개 유지(P6) |
| E4 | 빈/공백 검색어 저장 시도 | 저장하지 않음(상위가 trim 된 검색어를 전달; 빈 값은 무시) |
| E5 | 앱 재시작 | 저장된 최근 검색어를 로드해 유지(P1) |
| E6 | 입력 중 일치 항목 없음 | "검색어 없음" 화면 유지(자동완성 비노출) |
| E7 | 대소문자 차이(query `sw`, item `Swift`) | 자동완성에서 매칭됨(P10) |
| E8 | 공백만 입력 / 앞뒤 공백 | trim 후 빈 query 면 전체 최근 검색어로 취급, 비어있지 않으면 trim 한 값으로 매칭 |

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
- **P10. (매칭 규칙)** 자동완성 매칭은 **대소문자 무시 contains**(부분 문자열). **한글 초성 검색은 미지원.**
- **P11. (저장 dedup, 대소문자 무시)** `saveQuery` 중복 판정은 대소문자 무시. 같은(대소문자 무시) 검색어가 있으면 제거 후 **새로 입력한 케이싱**을 맨 앞에 삽입.
- **P12. (로드 collapse)** 로드 시 기존 저장 데이터의 대소문자 중복도 **collapse**(대소문자 무시로 묶어 **가장 최신 1건만** 유지). 동일 규칙으로 정확도 보정.
- **P13. (날짜 표시)** 자동완성 row 의 날짜는 **`MM.dd.`**(예: `06.01.`, 끝에 마침표 포함) 로 표시한다. Sendable 값 타입 `Date.VerbatimFormatStyle` 사용(`DateFormatter` 금지).

## 7. TCA 매핑 (State / Action / Client)
- **모델 `SearchRecentItem`**: `query: String`, `date: Date`. `Codable`, `Equatable`, `Identifiable`(`id == query`, P5 로 query 유일).
- **State**:
  - `items: [SearchRecentItem]` — 날짜 내림차순 유지.
  - `query: String` — **상위(`SearchFeature`)가 전달**하는 입력 필터 텍스트(parent 가 SoT; child 는 자동완성 계산용 복사본). 기본 `""`.
  - `@Presents var alert: AlertState<Action.Alert>?` — 전체 삭제 확인.
  - 파생 `var isEmpty: Bool { items.isEmpty }`.
  - 파생 `var isFiltering: Bool` — `query` trim 이 비어있지 않음(입력 중).
  - 파생 `var suggestions: [SearchRecentItem]` — `query` trim+lowercased 가 빈 경우 `[]`, 아니면 `items` 중 대소문자 무시 contains 매칭(날짜 내림차순 유지, P10).
- **Action**:
  - `task` — 진입 시 로드(P12 collapse 포함).
  - `itemTapped(SearchRecentItem)` — 최근 검색어 선택 → `delegate(.selected(query))`.
  - `suggestionTapped(SearchRecentItem)` — 자동완성 선택 → `delegate(.selected(item.query))` (R12, itemTapped 와 동일 위임).
  - `queryChanged(String)` — 상위가 입력 변화를 전달 → `state.query` 갱신(suggestions 파생 갱신).
  - `deleteButtonTapped` / `deleteAllButtonTapped` / `alert` — 기존(삭제·Alert).
  - `saveQuery(String)` — 상위 트리거: **대소문자 무시 dedup**(P11)/prepend/cap/persist 후 저장(P7).
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
- [ ] **R9/P10** `queryChanged` → `query` 갱신, `suggestions` 가 대소문자 무시 contains 매칭(날짜 내림차순).
- [ ] **E6** 매칭 0개 → `suggestions == []`, `isFiltering == true`.
- [ ] **E7** query `sw` + item `Swift` → `suggestions` 에 포함.
- [ ] **E8** `query == "   "` → `isFiltering == false`, `suggestions == []`.
- [ ] **R12** `suggestionTapped(item)` → `delegate(.selected(item.query))`.
- [ ] **P11** `saveQuery` 대소문자 dedup: `Swift` 저장 후 `swift` 저장 → 1개, query == `swift`(신규 케이싱).
- [ ] **P12** load collapse: 저장소에 `Swift`/`swift`(다른 날짜) 2건 → `task` 로드 시 1개(최신 유지).
- [ ] **R10/R11/Autocomplete/검색어 없음** → 화면 스크린샷(`/verify-screen`)로 검증(뷰 레이어).

## 9. 변경 이력 (Changelog)
| 날짜 | 이슈/PR | 변경 내용 |
|------|---------|-----------|
| 2026-05-31 | #5 | 골격 스캐폴딩 (섹션1만 작성) |
| 2026-05-31 | #11 | Task 5 필수 범위 구체화(요구사항·UI·엣지·정책·TCA 매핑·수용 기준) |
| 2026-06-01 | #23 | Task 7 자동완성 추가(R9–R13, Autocomplete UI 상태, E6–E8, P10–P13 대소문자 무시 매칭·dedup·collapse·`MM.dd.`, child `query`/`suggestions`/`queryChanged`/`suggestionTapped`); 날짜 포맷 `MM.dd.`(끝 마침표) 로 정정 |

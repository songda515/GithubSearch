# Search Spec

> 이 화면 정책의 **SSoT** 다. 동작을 바꾸려면 코드보다 **이 문서를 먼저** 고친다.
> 전체 구조는 [`../overview.md`](../overview.md) 참고.

| 항목 | 값 |
|------|----|
| Feature | `search` |
| 상태 | Approved (Task 4 구조 범위) |
| 관련 이슈/PR | #7 |
| 최종 수정 | 2026-05-31 |

> **이 spec 의 범위(Task 4 = 구조):** title · search bar · 하단 컨텐츠 영역(현재 빈 영역)과
> 검색어(query) 상태/trim 정책만 다룬다. 자식(`SearchRecentFeature`/`SearchResultFeature`) 합성,
> 결과 호출, `WebViewFeature` destination 연결은 **Task 5/6 에서 이 spec 에 추가**한다.

---

## 1. 개요 (Overview)
- **한 줄 설명**: 검색 화면 셸. navigation title 과 검색 입력(search bar)을 호스트하고 하단에 컨텐츠 영역(현재 빈 영역)을 둔다. 검색어 상태와 trim 정책을 소유한다.
- **진입 경로**: 앱 진입점(루트 화면). `AppFeature` 가 `Scope` 로 합성.
- **TCA 모듈**: `View` = `SearchView`, `Reducer` = `SearchFeature`.

## 2. 화면별 요구사항 (Requirements)
- **R1.** 화면은 title, search bar, 하단 컨텐츠 영역(현재는 빈 영역)으로 구성된다.
- **R2.** 진입 시 large title `"Search"` 를 표시한다.
- **R3.** search bar 는 입력 전 placeholder `"저장소 검색"` 을 표시한다.
- **R4.** 사용자가 입력하면 `query` 가 실시간으로 업데이트된다.
- **R5.** 검색을 확정(제출)하면 `query` 가 유지된다.
- **R6.** 입력 중·확정 후 cancel(취소)이 가능하며, 취소하면 `query` 가 비워진다.

## 3. UI 상태 (UI States)

| 상태 | 조건 | 화면 표시 |
|------|------|-----------|
| 진입 / Idle | `query` 비어 있음, search 비활성 | large title `"Search"`, placeholder `"저장소 검색"`, 하단 빈 영역 |
| 입력 중 / Active | search bar 포커스·입력 | title **collapse**, 입력 `query` 표시, **cancel** 버튼 노출 |
| 확정 / Submitted | 검색 제출됨 | `query` 유지, cancel 가능, 하단 빈 영역(결과는 Task 6) |

> **title collapse** 와 **cancel 버튼**은 SwiftUI `.searchable` 의 기본 동작(뷰 레이어)이다. 리듀서는
> `query` 와 제출만 소유하며, 이 두 표시는 `TestStore` 가 아니라 **화면 스크린샷**으로 검증한다.

## 4. 엣지 케이스 (Edge cases)

| # | 상황 | 기대 동작 |
|---|------|-----------|
| E1 | 공백만 입력 (`"   "`) | trim 후 빈 문자열 → "검색어 없음"과 동일. `sanitizedQuery == ""`, `hasActiveSearch == false` |
| E2 | 앞뒤 공백 (`"  swift  "`) | trim 하여 유효 검색어 `"swift"`. `hasActiveSearch == true` |
| E3 | 빈/공백 상태에서 제출 | 검색어 없음 — no-op (상태·이펙트 변화 없음) |
| E4 | cancel | `query` 를 `""` 로 초기화, Idle 복귀 |

## 5. API 명세 (API spec)
- **없음.** 구조 단계이므로 이 화면은 외부 API 를 호출하지 않는다. (GitHub 검색 API 는 `search-result` spec / Task 6 에서 정의)

## 6. 정책 (Policy)
- **P1. (trim)** `query` 유효성은 앞뒤 공백·개행 제거(`whitespacesAndNewlines`) 후 판단한다. trim 후 빈 문자열은 검색어 없음과 동일하게 취급한다.
- **P2. (query 유지)** 검색 확정 시 사용자가 입력한 `query` 문자열은 **그대로 유지**한다(표시용 변형 없음). 검색에 쓰는 유효 검색어는 파생 프로퍼티 `sanitizedQuery` 로만 노출한다.
- **P3. (구조 한정)** 본 화면은 검색 결과 호출·네비게이션을 하지 않는다(Task 6). 제출 액션은 상태 정규화 외 부수효과가 없다.

## 7. TCA 매핑 (State / Action / Client)
- **State**:
  - `query: String` — 검색 입력(`.searchable` 바인딩). 기본 `""`.
  - `var sanitizedQuery: String` — 파생: `query` 의 앞뒤 공백 제거값 (P1).
  - `var hasActiveSearch: Bool` — 파생: `!sanitizedQuery.isEmpty`.
- **Action**:
  - `binding(BindingAction<State>)` — `query` 업데이트 및 cancel(빈 문자열 set).
  - `searchSubmitted` — 검색 확정(`.onSubmit(of: .search)`).
- **Client**: 없음.

## 8. 수용 기준 (Acceptance criteria)
- [ ] **R4** → 테스트: `binding`으로 `query` 업데이트 시 `state.query` 가 갱신된다.
- [ ] **R5 / P2** → 테스트: `searchSubmitted` 시 `query` 가 유지되고 상태·이펙트 변화가 없다.
- [ ] **E1 / P1** → 테스트: `query = "   "` 이면 `sanitizedQuery == ""` 이고 `hasActiveSearch == false`.
- [ ] **E2** → 테스트: `query = "  swift  "` 이면 `sanitizedQuery == "swift"` 이고 `hasActiveSearch == true`.
- [ ] **E4** → 테스트: cancel(=`query` 를 `""` 로 set) 후 `hasActiveSearch == false` (Idle).
- [ ] **R2 / R3 / 입력 중 collapse** → 화면 스크린샷(XcodeBuildMCP)으로 검증(뷰 레이어).

## 9. 변경 이력 (Changelog)
| 날짜 | 이슈/PR | 변경 내용 |
|------|---------|-----------|
| 2026-05-31 | #5 | 골격 스캐폴딩 (섹션1만 작성) |
| 2026-05-31 | #7 | Task 4 구조 구현용 구체화 (요구사항·UI 상태·엣지케이스·정책·TCA 매핑·수용 기준) |

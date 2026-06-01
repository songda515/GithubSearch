# E2E (Full-Flow Integration) Spec

> 이 문서는 **교차기능 통합(E2E)** 의 SSoT 다. 개별 화면 정책이 아니라, 화면들이 합성 루트(`AppFeature`)에서
> **하나의 사용자 여정**으로 올바르게 이어지는가(seam) 를 정의한다. 화면별 정책은 각
> [`search`](../search/spec.md) · [`search-recent`](../search-recent/spec.md) ·
> [`search-result`](../search-result/spec.md) · [`webview`](../webview/spec.md) spec 이 SSoT.

| 항목 | 값 |
|------|----|
| Feature | `e2e` |
| 상태 | Approved (Task 9) |
| 관련 이슈/PR | #27 |
| 최종 수정 | 2026-06-01 |

> **범위:** `AppFeature` 합성 루트에서 **검색 입력 → 최근 검색어 저장 → 실데이터 결과 → 웹뷰 push** 전 구간을
> 한 `TestStore` 흐름으로 검증하는 **결정적 통합 테스트**. 화면 표시(뷰 레이어)는 3개 iOS 버전 시뮬레이터에서
> `/verify-screen` 으로 별도 확인한다. 신규 정책/프로덕션 코드 없음 — 기존 동작의 통합 검증.

---

## 1. 개요 (Overview)
- **한 줄 설명**: 검색 화면의 전체 사용자 여정(입력→최근→결과→웹뷰)이 합성 루트에서 끊김 없이 이어지는지 검증.
- **진입 경로**: `AppFeature` → `SearchFeature`(루트) → `SearchRecentFeature`/`SearchResultFeature`(자식) →
  `WebViewFeature`(destination).
- **TCA 모듈**: 신규 모듈 없음. `AppFeatureTests` 타깃의 `AppFeatureE2ETests` 가 합성 루트를 구동한다.

## 2. 요구사항 (Requirements)
- **R1.** 검색 제출 시 **결과 로드보다 최근 검색어 저장이 선행**되고, 실데이터 결과가 `loaded` 로 표시된 뒤
  행 선택으로 **웹뷰가 push** 된다. (search P7 · search-result R1/R4 · webview P1 의 통합)
- **R2.** 최근 검색어 선택도 동일하게 query 반영 → 저장 선행 → 결과 → 웹뷰로 이어진다.
- **R3.** 결과 표시 중 검색어를 비우면(취소) 결과가 리셋되고 입력(최근) 화면으로 복귀한다.
- **R4.** 빈 결과/네트워크 에러에서도 최근 검색어 저장은 유지되며 각각 empty/error 로 귀결된다.
- **R5.** 결과 목록에서 70% 지점 도달 시 다음 페이지가 이어 붙는다(prefetch 합성 경로).

## 3. UI 상태 (UI States)
합성 루트의 본문 전환만 다룬다(개별 상태는 각 화면 spec).

| 상태 | 조건 | 화면 표시 |
|------|------|-----------|
| 입력(최근/자동완성) | `isShowingResults == false` | `SearchRecentView` |
| 결과 | `result.phase != .idle && sanitizedQuery == result.query` | `SearchResultView` |
| 웹뷰 | `destination != nil` | `WebView`(push) |

> 위 전환은 `SearchFeature.isShowingResults` 파생값과 `navigationDestination` 으로 구동(뷰 레이어). 3버전
> 시뮬레이터 캡처로 확인(§8).

## 4. 엣지 케이스 (Edge cases)

| # | 상황 | 기대 동작 |
|---|------|-----------|
| E1 | 빈/공백만 제출 | 아무 effect 없음(저장·요청 안 함) |
| E2 | 결과 0건 | `phase=.empty`, 최근 검색어는 저장됨 |
| E3 | 네트워크 에러 | `phase=.error`, 최근 검색어는 저장됨 |
| E4 | 결과 표시 중 검색어 편집/취소 | in-flight 취소 + 결과 리셋 → 입력 화면 복귀 |
| E5 | `landingUrl` 무효한 행 선택 | 웹뷰 미present |

## 5. API 명세 (API spec)
- 외부 API 없음(신규). [`search-result`](../search-result/spec.md) §5 의 GitHub 검색 API
  (`GET /search/repositories`)를 그대로 사용하며, E2E 에서는 `httpClient` 를 **결정적 스텁**(canned JSON)으로
  주입한다(실네트워크 미사용).

## 6. 정책 (Policy)
- **P1.** E2E 는 **결정적**이어야 한다 — `httpClient`(canned), `userDefaults`(`.previewValue`), `date`(`.constant`)
  를 `withDependencies` 로 고정한다.
- **P2.** 신규 프로덕션 코드를 추가하지 않는다. 합성 루트의 **기존 동작 통합**만 단언한다.
- **P3.** 화면 표시 검증은 reducer 가 아니라 3버전 시뮬레이터 `/verify-screen` 으로 한다.

## 7. TCA 매핑 (State / Action / Client)
- **State**: `AppFeature.State`(=`search`). 자식/destination 은 기존 정의 그대로.
- **Action**: `.search(...)` 로 래핑된 기존 액션(`searchSubmitted`, `recent.saveQuery`, `recent.delegate.selected`,
  `result.searchRequested`/`searchResponse`/`rowTapped`/`rowAppeared`/`nextPageResponse`/`searchCleared`,
  `result.delegate.repositorySelected`, `binding`).
- **Client**: 신규 없음. 테스트에서 `httpClient.data` 를 canned 응답으로 스텁.

## 8. 수용 기준 (Acceptance criteria)
각 항목은 `AppFeatureE2ETests` 의 `@Test` 1개와 1:1. (호스트 `swift test` GREEN)

- [ ] **E2E-1 (R1)** 제출 → `recent.saveQuery` 선행 → `result.searchRequested`(loading) →
      `searchResponse(.success(items))` → `phase=.loaded`·items/`totalCount` 반영 → 행 선택 →
      `destination = WebViewFeature.State(title,url)`.
- [ ] **E2E-2 (R2)** 최근 검색어 선택 → query 반영 → 저장 선행 → 결과 loaded → 행 선택 → 웹뷰.
- [ ] **E2E-3 (R3/E4)** 결과 표시 중 query="" → `result.searchCleared`(리셋) → `isShowingResults=false`.
- [ ] **E2E-4a (R4/E2)** 제출 → 빈 결과 → `phase=.empty`, 최근 저장 유지.
- [ ] **E2E-4b (R4/E3)** 제출 → 에러 → `phase=.error`, 최근 저장 유지.
- [ ] **E2E-5 (R5)** loaded(가득 찬 페이지) → 70% 행 `rowAppeared` → `nextPageResponse` append.
- [ ] **3버전 표시 검증** Search/최근검색어 화면을 iOS 17.5/18.0/26.3 시뮬레이터에서 `/verify-screen` 캡처
      (결과·웹뷰는 실네트워크 의존이라 best-effort).

## 9. 변경 이력 (Changelog)
| 날짜 | 이슈/PR | 변경 내용 |
|------|---------|-----------|
| 2026-06-01 | #27 | 최초 작성 — E2E 통합 시나리오 + 3버전 화면검증 수용 기준 (Task 9) |

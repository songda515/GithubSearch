# Search Result Spec

> 이 화면 정책의 **SSoT** 다. 동작을 바꾸려면 코드보다 **이 문서를 먼저** 고친다.
> 전체 구조는 [`../overview.md`](../overview.md), 참고 화면은 [`search_result_requirement.PNG`](search_result_requirement.PNG).

| 항목 | 값 |
|------|----|
| Feature | `search-result` |
| 상태 | Approved (Task 6 필수 범위) |
| 관련 이슈/PR | #19 |
| 최종 수정 | 2026-06-01 |

> **이 spec 의 범위(Task 6 = 필수):** 전달받은 검색어로 GitHub 저장소 검색 결과 목록 표시, 저장소 개수
> 섹션 타이틀, 결과 0건/네트워크 에러 화면, 행 선택 시 웹뷰 이동 위임, **기본 load-more**(마지막 행 도달 시
> 다음 페이지 append)까지. **다음 페이지 prefetch(미리 호출)·페이지 로딩 스피너·정렬/필터 보강은 Task 8**.

---

## 1. 개요 (Overview)
- **한 줄 설명**: 전달받은 검색어에 대한 저장소 검색 결과 목록. 항목 선택 시 웹뷰 이동을 요청한다.
- **진입 경로**: `SearchFeature` 의 자식. 검색이 확정되면 검색 화면 본문으로 노출.
- **TCA 모듈**: `View` = `SearchResultView`, `Reducer` = `SearchResultFeature`.
- **위임/의존성**: 검색어는 **상위 `SearchFeature` 에서 하향 전달**받음. 항목 선택 시 **웹뷰 이동(destination)은 `SearchFeature` 에 위임**. 검색 API 호출은 범용 **`HTTPClient`**(Core) 주입. (구조 계약은 overview §3 참고)

## 2. 화면별 요구사항 (Requirements)
- **R1.** 검색 확정(`searchSubmitted`) 또는 최근 검색어 선택으로 결과 화면에 진입한다(검색어는 상위에서 전달).
- **R2.** 결과 목록의 각 row 는 **원형 아바타** + **이름(bold/black)** + **소유자 로그인(normal/gray)** 로 구성된다. 이름·설명은 **한 줄 말줄임**.
- **R3.** 섹션 타이틀로 **`{저장소 총개수}개 저장소`** 를 표시한다(`total_count`).
- **R4.** row 를 탭하면 해당 저장소 `landingUrl(html_url)` 로 **웹뷰 이동을 상위에 위임**한다.
- **R5.** search bar 에서 **취소(cancel)** 하면 검색 입력 화면으로 돌아가고, **결과 상태는 리셋**된다.
- **R6.** 목록 **마지막 행 도달 시 다음 페이지를 load-more** 하여 이어 붙인다.
- **R7.** **결과 0건**과 **네트워크 에러**를 위한 화면을 각각 제공한다.

## 3. UI 상태 (UI States)

| 상태 | 조건 | 화면 표시 |
|------|------|-----------|
| Idle | 검색 전(상위가 미노출) | 결과 화면 미표시(검색 입력 화면이 노출) |
| Loading | 첫 페이지 요청 중 | `ProgressView` |
| Loaded | 성공, `items` 1개 이상 | `{total_count}개 저장소` 헤더 + rows(아바타·이름·소유자) |
| Empty | 성공이나 `total_count == 0` | "검색 결과 없음" empty view |
| Error | 요청 실패(네트워크/HTTP/디코딩) | 에러 안내 + 재시도 |

> 헤더·행 표시(원형 아바타·bold 이름·gray 소유자·말줄임)·empty/error 화면은 **뷰 레이어**이므로 화면 스크린샷으로 검증(spec §8).

## 4. 엣지 케이스 (Edge cases)

| # | 상황 | 기대 동작 |
|---|------|-----------|
| E1 | 결과 0건 (`total_count == 0`) | Empty 화면(검색 결과 없음), 행/헤더 미표시 |
| E2 | 다음 페이지 없음(마지막 페이지/1000건 캡) | load-more 중단(`hasNextPage == false`), 추가 요청 안 함(P4) |
| E3 | 네트워크/HTTP/디코딩 에러 | Error 화면, 결과 미표시 |
| E4 | 아바타 이미지 로드 실패 | Kingfisher placeholder(원형)로 대체, 행은 정상 표시 |
| E5 | row 데이터 일부 누락(설명 등) | 안전 기본값(빈 문자열/placeholder)으로 표시(디코딩은 누락 허용) |
| E6 | load-more 중복 호출(로딩 중 재진입) | `isLoadingNextPage` 플래그로 가드 — 추가 요청 안 함 |
| E7 | 로딩 중 검색어 변경(취소/재검색) | 기존 in-flight 요청 취소 + 기존 결과 리셋(P2) |

## 5. API 명세 (API spec)

### `searchRepositories` — `GET https://api.github.com/search/repositories`
- **요청 파라미터**

  | 이름 | 타입 | 필수 | 설명 |
  |------|------|------|------|
  | `q` | String | Y | 검색어(전달받은 `query`). 최대 256자 |
  | `page` | Int | N | 1-based 페이지(기본 1) |
  | `per_page` | Int | N | 페이지 크기(기본 30, 최대 100). 본 화면은 **30** 고정(P1) |

- **요청 헤더**: `Accept: application/vnd.github+json`, `X-GitHub-Api-Version: 2022-11-28`. 미인증 호출(P7).
- **응답 (200)** — envelope:
  ```json
  { "total_count": 12345, "incomplete_results": false, "items": [ { "id": 1296269, "name": "Hello-World", "html_url": "https://github.com/octocat/Hello-World", "owner": { "login": "octocat", "avatar_url": "https://.../octocat.png" } } ] }
  ```
  - `RepositoryItem` 매핑: `id` ← `id`, `thumbnail` ← `owner.avatar_url`, `title` ← `name`, `description` ← `owner.login`, `landingUrl` ← `html_url`.
- **에러 코드**: `422` 검증 실패(빈/과도한 `q`), `403`·`429` rate limit(미인증 검색 10req/min), `503` 일시 장애. → 모두 Error 화면(E3).
- **페이지네이션**: 다음 페이지 존재 = `page * per_page < min(total_count, 1000)`. GitHub 검색은 **최대 1000건**(초과 페이지는 `items: []`).

## 6. 정책 (Policy)
- **P1. (페이지 크기)** `per_page = 30` 고정.
- **P2. (새 검색 리셋)** 새 검색 시작 시 `page = 1`, 기존 `items`/`totalCount`/in-flight 이펙트를 리셋한다.
- **P3. (다음 페이지)** load-more 는 `currentPage + 1` 을 요청해 결과를 **이어 붙인다**.
- **P4. (다음 페이지 존재)** `hasNextPage = currentPage * 30 < min(totalCount, 1000)`. `false` 면 load-more 안 함.
- **P5. (중복 제거)** 결과는 `id` 를 식별자로 하는 `IdentifiedArrayOf<RepositoryItem>` 로 보관 — 페이지 간 중복 `id` 는 제거된다.
- **P6. (저장 선행)** 검색 확정/선택 시 최근 검색어 저장(search-recent P7)이 결과 요청보다 **선행**한다(상위 `SearchFeature` 책임).
- **P7. (미인증)** 토큰 없이 호출(미인증 rate limit 적용).
- **P8. (load-more 가드)** load-more 진행 중에는 `isLoadingNextPage` 플래그로 추가 요청을 막는다(E6).
- **P9. (요청 취소)** 검색어 변경/취소 시 in-flight 요청을 취소한다(`cancelInFlight`, E7).

## 7. TCA 매핑 (State / Action / Client)
- **모델 `RepositoryItem`**: `id: Int`, `thumbnail: URL?`, `title: String`, `description: String`, `landingUrl: URL?`. `Equatable`, `Identifiable`(`id`), `Sendable`.
- **DTO(SearchFeature 내, GitHub 특화)**: `GitHubSearchResponse { totalCount, incompleteResults, items: [Repo] }`, `Repo { id, name, htmlURL, owner }`, `Owner { login, avatarURL }`. snake_case 디코딩. `Repo → RepositoryItem` 매핑.
- **State**:
  - `query: String` — 상위에서 하향 전달된 검색어.
  - `items: IdentifiedArrayOf<RepositoryItem>` — `id` 식별자(P5).
  - `totalCount: Int` — 헤더 표시(R3).
  - `currentPage: Int` — 마지막으로 로드한 페이지.
  - `hasNextPage: Bool` — 파생/세팅(P4).
  - `isLoadingNextPage: Bool` — load-more 가드(P8).
  - `phase: Phase` — `idle | loading | loaded | empty | error`(UI 상태).
- **Action**:
  - `searchRequested(String)` — 새 검색: 리셋(P2) → 첫 페이지 fetch(`cancelInFlight`, P9).
  - `searchResponse(Result<GitHubSearchResponse, NetworkError>)` — 첫 페이지 결과.
  - `reachedBottom` — 마지막 행 표시 → load-more(P3·P4·P8).
  - `nextPageResponse(Result<GitHubSearchResponse, NetworkError>)` — 다음 페이지 결과(append, P5).
  - `searchCleared` — 취소/클리어 → 요청 취소 + 리셋(R5·E7).
  - `rowTapped(RepositoryItem)` — 행 선택 → `delegate(.repositorySelected(item))`.
  - `delegate(Delegate)`; `enum Delegate { case repositorySelected(RepositoryItem) }`.
- **Client**: `@Dependency(\.httpClient) HTTPClient`(Core, 범용). GitHub endpoint 빌더는 SearchFeature 내.

## 8. 수용 기준 (Acceptance criteria)
- [ ] **R1/P2** `searchRequested` → `phase == .loading`, 기존 결과 리셋, 첫 페이지 요청.
- [ ] **R3** 성공 응답 → `totalCount` 가 응답값과 일치, `phase == .loaded`.
- [ ] **R2/P5** 성공 응답 → `items` 가 DTO→`RepositoryItem` 매핑값(아바타/이름/소유자/url)과 일치, `id` 식별.
- [ ] **R7/E1** `total_count == 0` 응답 → `phase == .empty`, `items` 비어 있음.
- [ ] **R7/E3** 실패 응답(`NetworkError`) → `phase == .error`.
- [ ] **R6/P3** `reachedBottom`(hasNextPage) → `currentPage+1` 요청 → `items` append(개수 증가).
- [ ] **P5** 다음 페이지에 중복 `id` 포함 → 중복 제거(개수 = 고유 id 수).
- [ ] **E2/P4** `hasNextPage == false` 에서 `reachedBottom` → no-op(요청 없음).
- [ ] **E6/P8** load-more 진행 중 `reachedBottom` 재진입 → 추가 요청 없음.
- [ ] **E7/P9** 로딩 중 `searchRequested`(새 검색) → 기존 요청 취소 + page1 리셋.
- [ ] **R5** `searchCleared` → in-flight 취소 + state 리셋(`phase == .idle`, items 비움).
- [ ] **R4** `rowTapped` → `delegate(.repositorySelected(item))`.
- [ ] **HTTPClient(Core)** decode 성공/`invalidURL`/`httpStatus`/`decoding` 매핑 → CoreTests.
- [ ] **R2/R3/E1/E3/E4 표시 / row→webview / 취소→복귀** → 화면 스크린샷(`/verify-screen`)으로 검증(뷰 레이어).

## 9. 변경 이력 (Changelog)
| 날짜 | 이슈/PR | 변경 내용 |
|------|---------|-----------|
| 2026-05-31 | #5 | 골격 스캐폴딩 (섹션1만 작성) |
| 2026-06-01 | #19 | Task 6 필수 범위 구체화(요구사항·UI·엣지·API·정책·TCA 매핑·수용 기준), 기본 load-more 포함, 참고 이미지 이동 |

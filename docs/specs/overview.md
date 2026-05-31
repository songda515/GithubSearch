# GithubSearch — 전체 구조 (Architecture Overview)

> 이 문서는 **앱 전체 구조의 SSoT**다. 화면별 상세 정책을 정의하기 **전에** 전체 골격(화면 맵·
> Feature 트리·위임 계약·Core 모듈·모듈 레이아웃)을 먼저 고정한다.
>
> **이 문서가 담지 않는 것:** 화면별 **요구사항 · 엣지케이스 · API 명세 · 정책**. 이는 화면별
> `docs/specs/<feature>/spec.md` 의 몫이며 [다음 스텝](#7-다음-스텝--task-분해)에서 채운다.
> 여기서 다루는 위임/데이터 흐름은 "어느 Feature가 무엇을 소유하고 누구에게 위임하는가"라는
> **구조 계약**까지이며, 그 안의 구체 규칙(디바운스·검증·정렬·페이지네이션 등)은 화면별 spec 소관이다.

| 항목 | 값 |
|------|----|
| 범위 | 앱 전체 아키텍처 overview (화면별 spec 의 상위 인덱스) |
| 상태 | Draft |
| 관련 이슈/PR | #5 |
| 최종 수정 | 2026-05-31 |

---

## 1. 목적 (Purpose)

GithubSearch 는 GitHub 저장소를 검색하고 결과를 웹뷰로 열어보는 iOS 앱이다.
사용자 여정은 **검색어 입력 → 결과 목록 → 항목 선택 시 웹뷰**로 이어지며, 검색 화면 상단에는
최근 검색어가 함께 노출된다(검색어가 비어 있을 때).

전체 구조는 한 개의 루트 `SearchFeature` 아래에 최근검색어/검색결과 자식 Feature 를 두고,
웹뷰는 루트의 destination 으로 띄우는 **단일 검색 흐름**으로 설계한다.

## 2. 화면 맵 (Screen map)

| # | 화면 | 역할 | Reducer |
|---|------|------|---------|
| S1 | 검색 화면 | navigation title + 검색 입력(search bar) 호스트. 검색어가 없으면 최근검색어, 검색이 확정되면 결과를 보여준다. | `SearchFeature` (+ 자식) |
| S2 | 검색 결과 | 검색어에 대한 저장소 결과 목록. 항목 선택 시 웹뷰로 이동 요청. | `SearchResultFeature` |
| S3 | 웹뷰 | 선택한 저장소를 `title`/`url` 로 표시. | `WebViewFeature` |

**공통 구조 (검색 화면 상단):**
- **navigation title** — 검색 화면의 큰 제목(참고 화면의 "Search").
- **search bar (검색 입력)** — `searchable` 로 제공되며 `SearchFeature.query` 에 바인딩된다.
  최근검색어 화면과 검색결과 화면이 **같은 search bar 하나를 공유**한다.

> 즉 S1 은 화면 컨테이너이고, 그 본문은 `query` 상태에 따라 최근검색어(`SearchRecentFeature`)와
> 검색결과(`SearchResultFeature`) 사이에서 전환된다. 전환의 **구체 조건**은 화면별 spec 소관.

**참고 화면(스크린샷):**
- 검색 입력/최근검색어 — [`../search_input_requirement.PNG`](../search_input_requirement.PNG), [`../search_input_improvement.PNG`](../search_input_improvement.PNG)
- 검색 결과 — [`../search_result_requirement.PNG`](../search_result_requirement.PNG), [`../search_result_improvement.PNG`](../search_result_improvement.PNG)

## 3. Feature Reducer 트리 (Composition)

```
SearchFeature                         ← root: navigation title, searchable query
├─ navigationTitle                    상태
├─ query (searchable, 바인딩)         상태 — 자식/검색을 구동하는 단일 소스
├─ Scope: SearchRecentFeature         자식 — 최근검색어
├─ Scope: SearchResultFeature         자식 — 검색결과
└─ destination: WebViewFeature        present — 웹뷰 (자식이 위임한 요청으로 띄움)
```

### 3.1 각 Feature 의 책임과 의존성

| Feature | 소유(책임) | 상위에 위임 | 주입 의존성 |
|---------|-----------|-------------|-------------|
| `SearchFeature` | navigation title, `query`(searchable), 자식 합성, 웹뷰 destination 제어 | — (루트) | — |
| `SearchRecentFeature` | 최근검색어의 저장/조회/삭제 등 **최근검색어 로직** | 검색어 선택 시 **검색 결과로의 전환**은 `SearchFeature` 에 위임 | **UserDefaultsClient** (최근검색어 영속화) |
| `SearchResultFeature` | 전달받은 검색어에 대한 **결과 로직**(호출/표시) | 항목 선택 시 **웹뷰 이동(destination)** 은 `SearchFeature` 에 위임 | **HTTPClient** (검색 API) |
| `WebViewFeature` | `title`, `url` 표시 | — | — |

### 3.2 위임/데이터 흐름 계약 (Delegation contract)

자식 → 부모 통신은 TCA `delegate` 액션 패턴을 따른다(자식은 의도를 알리고, **결정과 부수효과는
부모가 수행**). 이번 단계에서 고정하는 구조 계약은 다음과 같다.

- **검색어 하향 전달**: `query` 는 `SearchFeature` 가 단일 소스로 소유하고 `SearchResultFeature` 로
  **하향 전달**된다. 결과 Feature 는 검색어를 직접 입력받지 않는다.
- **최근검색어 → 검색 전환(상향 위임)**: `SearchRecentFeature` 가 최근검색어 선택을 delegate 로 알리면,
  `SearchFeature` 가 `query` 를 갱신해 검색결과 흐름을 구동한다.
- **검색결과 → 웹뷰(상향 위임)**: `SearchResultFeature` 가 항목 선택을 delegate(예: 선택한 저장소의
  `title`/`url`)로 알리면, `SearchFeature` 가 `WebViewFeature` 를 destination 으로 present 한다.

> 위 계약의 **구체 트리거/조건/데이터 형태**(예: 어떤 액션명, 어느 시점, 어떤 필드)는 화면별 spec 의
> State/Action/Policy 에서 확정한다. 여기서는 "누가 소유하고 누구에게 위임하는가"만 고정한다.

## 4. Core 모듈 (범용 Client)

화면에 종속되지 않는 **범용 재사용 Client** 는 Core 에 둔다. 두 Client 모두 CLAUDE.md 의 Client 규약
(`@DependencyClient`, `liveValue`/`testValue`/`previewValue`, `@Dependency` 주입, `Sendable`)을 따른다.

| Client | 책임 | 비고 |
|--------|------|------|
| `UserDefaultsClient` | `set` / `get` method 제공 (키-값 영속화) | `SearchRecentFeature` 의 최근검색어 저장에 사용. **테스트 코드 함께 구축.** |
| `HTTPClient` | concurrency(`async`/`await`) 기반 API 호출, **Decodable 기반 응답 파싱** | `SearchResultFeature` 의 검색 API 에 사용. 범용 HTTP 추상화. |

> Client 의 **세부 시그니처/엔드포인트/에러 매핑**은 이를 사용하는 화면별 spec 의 "API 명세"와
> 함께 확정한다. Core 자체는 화면 정책을 모른다(범용).

## 5. 모듈/패키지 레이아웃 (목표 구조)

모든 실제 코드는 `GithubSearchPackage` (로컬 SPM) 안에 둔다. 현재는 `AppFeature` 만 존재하며,
아래는 이번 구조에 맞춰 **추가해 갈 목표 레이아웃**이다(모듈 추가 = `Package.swift` 편집, `.xcodeproj` 미수정).

```
GithubSearchPackage/Sources/
  AppFeature/          (기존) 앱 합성 루트 / 진입점
  SearchFeature/       SearchFeature · SearchRecentFeature · SearchResultFeature · WebViewFeature
  Core/                UserDefaultsClient · HTTPClient  (범용 Client)
GithubSearchPackage/Tests/
  SearchFeatureTests/  TestStore 기반 리듀서 테스트
  CoreTests/           UserDefaultsClient/HTTPClient 테스트
```

> 모듈 분리 granularity(예: feature 별 모듈 추가 분할 여부)는 구현 단계의 결정 사항이다.
> 원칙: feature 리듀서들은 응집된 feature 모듈에, 범용 Client 는 `Core` 에 둔다.

## 6. 검증/하네스 연계

- 화면 = SwiftUI `View` + TCA `@Reducer`, 의존성 = `Client`(3-value) — CLAUDE.md 규약 그대로.
- 각 화면별 spec 의 "수용 기준"은 `TestStore` 시나리오로, Core Client 는 단위 테스트로 검증한다.
- 빌드/테스트 게이트(`swift test`, `xcodebuild build/test`)는 **코드가 생기는 다음 스텝부터** 적용한다.

## 7. 다음 스텝 — Task 분해

이 overview 를 기준으로 화면별 상세 spec 과 Core 구현을 아래 단위로 분해한다. 각 항목은 별도 이슈/PR 로
진행하며, **동작 정의 항목은 `spec.md` 작성이 코드보다 앞선다**(spec-first).

| # | Task | 산출물 | 의존 |
|---|------|--------|------|
| T1 | 검색 화면 spec | `docs/specs/search/spec.md` (SearchFeature: title·searchable·자식 합성·webview destination) | overview |
| T2 | 최근검색어 spec | `docs/specs/search-recent/spec.md` (SearchRecentFeature + UserDefaultsClient 사용 정책) | T1 |
| T3 | 검색결과 spec | `docs/specs/search-result/spec.md` (SearchResultFeature + 검색 API 명세) | T1 |
| T4 | 웹뷰 spec | `docs/specs/webview/spec.md` (WebViewFeature: title·url) | T1 |
| T5 | Core: UserDefaultsClient | 구현 + 테스트 | T2 |
| T6 | Core: HTTPClient | 구현 + 테스트 (concurrency·Decodable) | T3 |
| T7 | Feature 구현 | 각 spec 의 수용 기준을 TestStore 로 충족 | T1–T6 |

> 각 화면별 spec 디렉터리는 본 단계에서 **골격만 스캐폴딩**(섹션1 식별/Overview 만 채우고 나머지 `TBD`)했다.
> 상세 정책은 위 Task 에서 `_template/spec.md` 의 모든 섹션을 채워 완성한다.

## 8. 변경 이력 (Changelog)

| 날짜 | 이슈/PR | 변경 내용 |
|------|---------|-----------|
| 2026-05-31 | #5 | 최초 작성 — 전체 구조 overview + 화면별 spec 골격 분해 |

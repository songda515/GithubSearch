# GithubSearch

GitHub 저장소를 검색하고 결과를 웹뷰로 열어보는 iOS 앱.
**SwiftUI + The Composable Architecture (TCA)** 로 작성되었으며, 모든 실제 코드는
로컬 SPM 패키지(`GithubSearchPackage`)에 모듈로 분리되어 있다.

| | |
|---|---|
| Platform | iOS 17.0+ |
| Language | Swift 6 (strict concurrency, `swiftLanguageModes: [.v6]`) |
| Architecture | The Composable Architecture (TCA) `1.25.5` |
| UI | SwiftUI |
| Image cache | Kingfisher `8.9.0` |
| Tests | Swift Testing (`@Test` / `#expect`) + TCA `TestStore` |

---

## 개요

사용자 여정은 **검색어 입력 → 결과 목록 → 항목 선택 시 웹뷰**로 이어진다.
검색 입력창은 하나(`searchable`)이며, 입력 상태에 따라 본문이 전환된다.

- 검색어가 비어 있으면 → **최근 검색어**
- 입력 중이면 → **자동완성**(최근 검색어 대소문자 무시 contains 매칭)
- 검색이 확정되면(엔터/선택) → **검색 결과 목록**

## 주요 기능

- **GitHub 저장소 검색** — `GET /search/repositories` (인증 없이 호출, per-page 30).
- **검색 결과 목록** — 저장소 총개수 헤더, 빈/에러 상태 처리, 아바타 이미지 캐싱(Kingfisher).
- **페이지네이션** — 마지막 행 도달 시 다음 페이지 load-more, 목록 70% 지점에서 다음 페이지
  **prefetch**, 다음 페이지 로딩 인디케이터. GitHub 검색 상한(1000건)까지.
- **최근 검색어** — UserDefaults 영속화, 날짜 내림차순, 대소문자 무시 dedup, 최대 10개,
  개별/전체 삭제(전체 삭제는 확인 Alert).
- **자동완성** — 입력 중 최근 검색어에서 후보 노출.
- **웹뷰** — 선택한 저장소를 `title`/`url` 로 표시.

---

## 아키텍처

화면 = SwiftUI `View` + TCA `@Reducer`. 사이드 이펙트(네트워크·저장)는 모두 `@Dependency` 로
주입되는 **Client** 뒤로 격리한다(리듀서는 URLSession/UserDefaults 를 직접 호출하지 않는다).

### Feature 트리

```
AppFeature                            ← 앱 합성 루트 (Scope 로 화면 호스팅)
└─ SearchFeature                      ← 검색 화면 셸: searchable query(단일 소스) 소유
   ├─ Scope: SearchRecentFeature      자식 — 최근 검색어 / 자동완성  (← UserDefaultsClient)
   ├─ Scope: SearchResultFeature      자식 — 검색 결과 / 페이지네이션 (← HTTPClient)
   └─ destination: WebViewFeature     present — 웹뷰
```

자식 → 부모 통신은 TCA `delegate` 액션 패턴을 따른다(자식은 의도를 알리고, 결정·부수효과는 부모가 수행).

- **검색어 하향 전달**: `query` 는 `SearchFeature` 가 단일 소스로 소유하고 자식으로 내려준다.
- **최근 검색어 → 검색 전환**: `SearchRecentFeature` 가 선택을 delegate 로 알리면 부모가 `query` 갱신.
- **검색 결과 → 웹뷰**: `SearchResultFeature` 가 항목 선택을 delegate 로 알리면 부모가 웹뷰를 present.

### Core 모듈 (범용 Client)

화면에 종속되지 않는 재사용 Client. 각 Client 는 `@DependencyClient` 로 정의되고
`liveValue` / `testValue`(unimplemented) / `previewValue` 세 값을 제공한다.

| Client | 책임 |
|--------|------|
| `HTTPClient` | `async`/`await` 기반 HTTP 호출 + `Decodable` 파싱. 화면 비종속(엔드포인트·DTO 는 feature 소유) |
| `UserDefaultsClient` | 키-값(`Data`) 영속화. 최근 검색어 저장에 사용 |

> GitHub API 의 엔드포인트·DTO·도메인 매핑은 `SearchFeature` 내부(`GitHubSearchAPI.swift`)에 있고,
> `HTTPClient`(Core)는 API 명세를 모른다.

---

## 프로젝트 구조

```
GithubSearch/                  ← 얇은 앱 셸(.xcodeproj 타깃). 비즈니스 로직 없음
GithubSearchPackage/           ← 모든 실제 코드(로컬 SPM 패키지)
  Package.swift                ← 모듈 + 의존성의 단일 진실 공급원
  Sources/
    AppFeature/                앱 합성 루트 / 진입점
    SearchFeature/             SearchFeature · SearchRecent · SearchResult · WebView
    Core/                      HTTPClient · UserDefaultsClient (범용 Client)
  Tests/
    AppFeatureTests/  SearchFeatureTests/  CoreTests/   (Swift Testing + TestStore)
GithubSearchTests/             앱 셸 스모크 테스트
GithubSearchUITests/
docs/specs/                    SDD: 화면별 정책 SSoT(spec-first)
  _template/spec.md            새 스펙 시작용 템플릿
  overview.md                  앱 전체 구조 overview
  <feature>/spec.md            화면 하나의 정책 단일 진실 공급원
```

> **모듈 추가 = `GithubSearchPackage/Package.swift` 편집 + 파일 추가.** `.xcodeproj` 는 손대지 않는다.

---

## 시작하기

요구 사항: **Xcode 26+** (iOS 17 SDK, Swift 6 툴체인). 외부 API 키는 필요 없다.

```bash
git clone https://github.com/songda515/GithubSearch.git
cd GithubSearch
open GithubSearch.xcodeproj   # Xcode 에서 GithubSearch 스킴 실행 (⌘R)
```

TCA 는 매크로를 사용하므로, 최초 빌드 시 Xcode 가 매크로 신뢰 여부를 묻거나 CLI 에서는
`-skipMacroValidation` 가 필요할 수 있다(아래 검증 명령 참고).

---

## 빌드 & 테스트

> **코드 변경 후에는 빌드와 테스트가 모두 통과해야 완료로 본다.**

```bash
# 1) 빠른 리듀서/단위 테스트 (macOS 호스트, 시뮬레이터 불필요) — 1차 루프
swift test --package-path GithubSearchPackage

# 2) 사용 가능한 시뮬레이터 UDID 선택 (이름은 Xcode 버전마다 달라질 수 있어 UDID 권장)
SIM=$(xcrun simctl list devices available | grep -m1 -oE '[0-9A-F-]{36}')

# 3) iOS 빌드 검증 (TCA import/링크가 iOS 17 타깃에서 되는지 확인)
xcodebuild build -scheme GithubSearch -skipMacroValidation \
  -destination "platform=iOS Simulator,id=$SIM"

# 4) 앱 테스트 타깃 (Swift Testing). UI 테스트 제외해 빠르게:
xcodebuild test -scheme GithubSearch -skipMacroValidation \
  -destination "platform=iOS Simulator,id=$SIM" -only-testing:GithubSearchTests
```

`swift test` 로 도는 리듀서 테스트가 핵심 검증 자산이다 — 각 화면의 수용 기준이
`TestStore` 시나리오(검색/페이지네이션/prefetch/최근 검색어 저장·삭제/에러)로 매핑되어 있다.

---

## 개발 워크플로우

이 레포는 **Spec-Driven Development(SDD)** + **이슈 단위 워크플로우**를 따른다. 자세한 규칙은
루트 [`CLAUDE.md`](CLAUDE.md) 와 [`docs/specs/README.md`](docs/specs/README.md) 가 SSoT 다.

- **Spec-first** — 동작을 바꾸려면 `docs/specs/<feature>/spec.md` 를 코드보다 **먼저** 고친다.
  화면별 spec 이 그 화면 정책(요구사항·엣지케이스·API 명세·정책 + TCA 매핑·수용 기준)의 유일한 기준이다.
- **이슈 → 브랜치 → PR** — 작업 1단위 = 1이슈 = 1브랜치(`<issue#>-<slug>`) = 1PR. 체크리스트
  서브태스크마다 atomic 커밋. 빌드/테스트가 green 일 때만 PR 을 연다. 머지는 merge commit.
- **Claude Code 스킬** — `.claude/skills/` 에 `implement-spec`(구현), `review-spec`(독립 판정),
  `verify-screen`(시뮬레이터 화면 검증)이 있다.

---

## 라이선스

별도 명시 전까지 비공개 학습용 프로젝트.

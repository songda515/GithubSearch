# WebView Spec

> 이 화면 정책의 **SSoT** 다. 동작을 바꾸려면 코드보다 **이 문서를 먼저** 고친다.
> 전체 구조는 [`../overview.md`](../overview.md) 참고.

| 항목 | 값 |
|------|----|
| Feature | `webview` |
| 상태 | Approved (Task 6 필수 범위) |
| 관련 이슈/PR | #19 |
| 최종 수정 | 2026-06-01 |

> **이 spec 의 범위(Task 6 = 필수):** 선택한 저장소를 `title`/`url` 로 표시하는 웹뷰와 결과로의 복귀(back)까지.
> 로딩 인디케이터·에러 페이지·뒤로/앞으로 네비게이션 등 보강은 다음 스텝.

---

## 1. 개요 (Overview)
- **한 줄 설명**: 선택한 저장소를 `title`/`url` 로 표시하는 웹뷰.
- **진입 경로**: `SearchResultFeature` 가 위임한 선택을 받아 `SearchFeature` 가 destination 으로 **push**(NavigationStack).
- **TCA 모듈**: `View` = `WebView`, `Reducer` = `WebViewFeature`. 상태: `title`, `url`.

## 2. 화면별 요구사항 (Requirements)
- **R1.** 전달받은 `url` 의 웹 콘텐츠를 표시한다.
- **R2.** navigation title 로 전달받은 `title`(저장소 이름)을 표시한다.
- **R3.** back(상단 뒤로)으로 검색 결과 화면으로 복귀한다.

## 3. UI 상태 (UI States)

| 상태 | 조건 | 화면 표시 |
|------|------|-----------|
| Loaded | push 직후 | `url` 의 웹 콘텐츠, navigation title = `title` |

> 웹 콘텐츠 렌더링·push 표시는 **뷰 레이어**(WKWebView)이므로 화면 스크린샷으로 검증(spec §8).

## 4. 엣지 케이스 (Edge cases)

| # | 상황 | 기대 동작 |
|---|------|-----------|
| E1 | `url` 이 nil/무효한 항목 선택 | 상위가 destination 을 present 하지 않음(유효 url 만 push, P1) |

## 5. API 명세 (API spec)
- **외부 API 없음.** 웹 콘텐츠 로드(WKWebView)만 수행한다.

## 6. 정책 (Policy)
- **P1. (유효 url)** `landingUrl` 이 유효할 때만 웹뷰를 present 한다(무효 시 미present).
- **P2. (표시 한정)** 본 화면은 `title`/`url` 표시만 담당하며 별도 상태 전환/부수효과가 없다.

## 7. TCA 매핑 (State / Action / Client)
- **State**:
  - `title: String` — navigation title(저장소 이름).
  - `url: URL` — 표시할 웹 콘텐츠 주소.
- **Action**: 없음(표시 전용). 향후 보강 시 추가.
- **Client**: 없음.

## 8. 수용 기준 (Acceptance criteria)
- [ ] **R1/R2** `WebViewFeature.State(title:url:)` 가 전달값을 보유한다(상위 통합 테스트에서 present 시 값 일치).
- [ ] **R1/R2/R3 표시·push·복귀** → 화면 스크린샷(`/verify-screen`)으로 검증(뷰 레이어).

## 9. 변경 이력 (Changelog)
| 날짜 | 이슈/PR | 변경 내용 |
|------|---------|-----------|
| 2026-05-31 | #5 | 골격 스캐폴딩 (섹션1만 작성) |
| 2026-06-01 | #19 | Task 6 필수 범위 구체화(요구사항·UI·엣지·정책·TCA 매핑·수용 기준), push 표시 방식 확정 |

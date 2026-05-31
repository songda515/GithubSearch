# WebView Spec

> 이 화면 정책의 **SSoT** 다. 동작을 바꾸려면 코드보다 **이 문서를 먼저** 고친다.
> 전체 구조는 [`../overview.md`](../overview.md) 참고. 이 문서는 **골격(Draft)** 이며 상세 정책은 다음 스텝에서 채운다.

| 항목 | 값 |
|------|----|
| Feature | `webview` |
| 상태 | Draft |
| 관련 이슈/PR | #5 (스캐폴딩) |
| 최종 수정 | 2026-05-31 |

---

## 1. 개요 (Overview)
- **한 줄 설명**: 선택한 저장소를 `title`/`url` 로 표시하는 웹뷰.
- **진입 경로**: `SearchResultFeature` 가 위임한 선택을 받아 `SearchFeature` 가 destination 으로 present.
- **TCA 모듈**: `View` = `WebView`, `Reducer` = `WebViewFeature`. 상태: `title`, `url`.

## 2. 화면별 요구사항 (Requirements)
- TBD (다음 스텝)

## 3. UI 상태 (UI States)
- TBD (다음 스텝)

## 4. 엣지 케이스 (Edge cases)
- TBD (다음 스텝)

## 5. API 명세 (API spec)
- TBD — 외부 API 없음(웹 콘텐츠 로드). 로드 정책은 다음 스텝에서 확정.

## 6. 정책 (Policy)
- TBD (다음 스텝)

## 7. TCA 매핑 (State / Action / Client)
- TBD (다음 스텝)

## 8. 수용 기준 (Acceptance criteria)
- TBD (다음 스텝)

## 9. 변경 이력 (Changelog)
| 날짜 | 이슈/PR | 변경 내용 |
|------|---------|-----------|
| 2026-05-31 | #5 | 골격 스캐폴딩 (섹션1만 작성) |

# Search Spec

> 이 화면 정책의 **SSoT** 다. 동작을 바꾸려면 코드보다 **이 문서를 먼저** 고친다.
> 전체 구조는 [`../overview.md`](../overview.md) 참고. 이 문서는 **골격(Draft)** 이며 상세 정책은 다음 스텝에서 채운다.

| 항목 | 값 |
|------|----|
| Feature | `search` |
| 상태 | Draft |
| 관련 이슈/PR | #5 (스캐폴딩) |
| 최종 수정 | 2026-05-31 |

---

## 1. 개요 (Overview)
- **한 줄 설명**: 검색 화면. navigation title 과 검색 입력(search bar)을 호스트하고, 검색어 상태에 따라 최근검색어/검색결과 본문을 전환한다.
- **진입 경로**: 앱 진입점(루트 화면).
- **TCA 모듈**: `View` = `SearchView`, `Reducer` = `SearchFeature`.
- **합성**: 자식 `SearchRecentFeature` / `SearchResultFeature`, destination = `WebViewFeature`. `query` 를 단일 소스로 소유하고 결과 Feature 로 하향 전달, 자식의 전환/웹뷰 이동 위임을 처리. (구조 계약은 overview §3 참고)

## 2. 화면별 요구사항 (Requirements)
- TBD (다음 스텝)

## 3. UI 상태 (UI States)
- TBD (다음 스텝)

## 4. 엣지 케이스 (Edge cases)
- TBD (다음 스텝)

## 5. API 명세 (API spec)
- TBD — 이 화면 자체는 직접 API 를 호출하지 않음(검색 API 는 `search-result` 소관). 확정은 다음 스텝.

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

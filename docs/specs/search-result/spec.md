# Search Result Spec

> 이 화면 정책의 **SSoT** 다. 동작을 바꾸려면 코드보다 **이 문서를 먼저** 고친다.
> 전체 구조는 [`../overview.md`](../overview.md) 참고. 이 문서는 **골격(Draft)** 이며 상세 정책은 다음 스텝에서 채운다.

| 항목 | 값 |
|------|----|
| Feature | `search-result` |
| 상태 | Draft |
| 관련 이슈/PR | #5 (스캐폴딩) |
| 최종 수정 | 2026-05-31 |

---

## 1. 개요 (Overview)
- **한 줄 설명**: 전달받은 검색어에 대한 저장소 검색 결과 목록. 항목 선택 시 웹뷰 이동을 요청한다.
- **진입 경로**: `SearchFeature` 의 자식. 검색이 확정되면 검색 화면 본문으로 노출.
- **TCA 모듈**: `View` = `SearchResultView`, `Reducer` = `SearchResultFeature`.
- **위임/의존성**: 검색어는 **상위 `SearchFeature` 에서 하향 전달**받음. 항목 선택 시 **웹뷰 이동(destination)은 `SearchFeature` 에 위임**. 검색 API 호출은 **`HTTPClient`** 주입. (구조 계약은 overview §3 참고)

## 2. 화면별 요구사항 (Requirements)
- TBD (다음 스텝)

## 3. UI 상태 (UI States)
- TBD (다음 스텝)

## 4. 엣지 케이스 (Edge cases)
- TBD (다음 스텝)

## 5. API 명세 (API spec)
- TBD — GitHub 저장소 검색 API. `HTTPClient` closure 시그니처/엔드포인트/에러 매핑은 다음 스텝에서 확정.

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

현재 폴더에서 내가 보내는 프롬프트를 자동 기록하도록 hook 을 세팅해줘.

- docs/prompt.md 로 관리
- 별도 timestamp, stdout 출력은 필요 없고 내가 작성한 문장만 기록
- 최초 메세지는 hook 으로 저장되지 않으므로 최초 메세지로 문서에 작성
- 메세지 사이에는 구분선 추가해줘.

---

prompot hook test

---

SwiftUI + TCA 기반으로 iOS 앱을 개발하려고해. 아래 요구사항대로 앱을 개발하기 위한 claude code 기반 하네스 엔지니어링이 가능하게 구조를 만들어줘. 그리고 요구사항이 타당한지는 리서치를 통해 재차 검증해줘. 필요하다면 Ask user question

## 요구사항

- minimum iOS 17.0 설정 - 시장 점유율 1% 미만, SwiftUI 기능 버전 호환 위함
- Swift 6 설정 - 데이터 레이스 안정성 위함
- iOS 버전에 맞는 TCA 안정화 버전을 exact 로 SPM 설치
- 모든 화면은 SwiftUI View + TCA Reducer 조합으로 개발
- 네트워크, 내부저장소 등 의존성이 필요한 작업은 Client 로 분리
- Client 는 Dependency 로 주입하며 liveValue, testValue, previewValue 을 제공해서 테스트, 프리뷰 제공
- ios + xcode 환경에 맞게 gitignore 설정

## 규칙

- 코드 수정 후 빌드 및 테스트 진행 전에는 완료 보고 금지

## 결과 검증

- TCA import 해서 빌드 가능한지 확인
- CLAUDE.md 가 위 항목을 담았는지 검증 (rule, skill 은 아직 미설정)

---

github issue 로 현재 작업 내용을 생성해줘.

# Task 1. SwiftUI + TCA 앱 기반 구조를 만들고 검증 하네스 구축

요구사항과 검증 조건을 동일하게 작성해줘.
추가로 SwiftTesting 사용, 모듈화는 SwiftPackage 기반으로 작성 포함

---

Git PR work flow 에 대해서 CLAUDE.md 에 추가로 명시해줘.

- 모든 작업은 이슈 단위로 진행
- 이슈에는 요구사항, 규칙, 검증에 필요한 내용, 체크리스트가 포함
- 1 이슈당 1 브랜치를 사용해서 이슈마다 PR 을 생성
- 이슈에 작성된 sub task 단위로 commit 을 진행
- PR 을 생성하기 전에는 test, build 가 완료된 상태여야함. 실패 시 커밋 금지
- PR 본문에 Summary, 요구사항, 검증 결과, 결정 근거를 서술
- PR 을 머지할때에는 merge commit

---

task 워크플로우에 따라서 1번 이슈의 PR 을 생성해줘.

---

task 1 에서 prompt.md 와 hook 도 함께 추가해줘. 
현재 작성되어있는 md 파일에서 background 에서 입력된  <task-notification> , Continue: 등 프롬프트는 제외하도록 수정해줘.


---

PR 의 iOS 17 결정 근거에 대해 정정해줘.
- iOS 17 버전을 택한 이유는 TCA 버전이슈가 아님. TCA 버전은 iOS 17 에 호환되는 버전을 골랐을 뿐
- 내가 생각한 결정 근거 (최초 리서치 진행했던 결과)
1) 시장 점유율이 iOS 17 + 는 99% 이상, iOS 16 이하는 1%  미만
2) iOS17부터 Apple Observation 도입으로 TCA 에서도 WithPerceptionTracking 랩핑 불필요, 누락 버그 원천 제거 가능


---

Task 2 로 SDD (spec driven develop) 구조를 셋업하고 요구사항 기반의 스펙 문서를 만드려고해. 
요구사항에 해당하는 spec 의 docs 구조를 만들어주고, CLAUDE.md 에 명시해줘.

## 요구사항 
- 화면별 정책의 SSoT 는 docs/specs/<feature>/spec.md 로 정리
- 동작 변경시 코드부터 고치지 않고 spec 을 먼저 고친다. 
- spec 하위에 화면별 요구사항, 엣지케이스, API 명세, 정책을 기록한다.

## 결과 검증
- CLAUDE.md 수정에 반영 
- issue 생성 여부

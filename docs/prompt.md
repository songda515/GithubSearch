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


---

Task 3. 스펙 구성: 전체 구조 + 화면별 스펙 -> Task 분해

SDD 기반으로 개별 화면의 스펙을 정의하기 전에 전체 구조를 잡으려고 해. 스펙에 overview 로 정리해줘.
화면별 상세 정책은 다음 스텝으로 가져갈거기 때문에 해당 문서에 정리하지 말아줘.

## 구성할 화면
- 화면: 검색 화면, 검색 결과, 웹뷰
- 공통 구조: 검색 입력, 검색 결과 상단의 title, search bar 는 공통으로 사용
- 검색 결과 화면에서는 웹뷰를 열어야함

## Feature Reducer
- SearchFeature
  - navigation title
  - searchable query
  - child reducer:
    - SearchRecentFeature
    - SearchResultFeature
  - destination: webview

- SearchRecentFeature
  - 검색어 입력 후 검색 결과로의 전환은 SearchFeature 에 위임한다
  - 최근검색어 관련 로직은 해당 Feature 에서 관리한다
  - 최근검색어 관리가 필요하므로 Dependency 로 주입받는다.

- SearchResultFeature
  - 입력된 검색어는 상위 SearchFeature 에서 전달받는다.
  - 검색 결과에 대한 로직은 해당 Feature 에서 관리한다.
  - 검색 결과 화면에서 웹뷰 화면으로 이동하기 위한 destination 은 상위에 위임한다.
  - 검색 결과의 API 호출이 필요하므로 Dependency 로 주입받는다.
 - WebViewFeature
  - title, url


## Core 모듈
- Core 모듈은 범용적으로 사용할 수 있도록 구축
- UserDefaultsClient: set, get 에 대한 method 와 test 코드 함께 구축
- HTTPClient: concurrency 기반 API 호출, Decodable 기반 데이터 파싱 구축

## 참고 화면
docs/{}.PNG 이미지


---

Task 4: 검색 화면 구조 구현 진행해줘.
- spec 기반으로 개발이 진행될 수 있도록 implement-spec 스킬 생성
- 아래 스펙에 대해 구체적 문서 갱신

## 화면 요구사항
- title, searchbar, 하단 컨텐츠 영역(현재는 빈 영역)

## UI 상태
1. title
- 진입시: large title "Search"
- 서치바 입력 중: title collapse

2. 서치바
- 입력 전: placeholder "저장소 검색"
- 입력 중: query 업데이트, cancel 가능
- 입력 완료: 검색 확정, query 유지, cancel 가능

## 엣지케이스
- 검색어 trim 처리, trim 후 빈값인 경우 검색어 없는것과 동일하게 처리

## API
- 구조이기 때문에 API 명세 없음

## 검증
- 기존 test build 는 test store 기반으로 진행
- implement-spec 스킬이 동작되어서 구현되었는지 확인
- 최종 검증은 XcodeBuildMCP 을 도입해서 구현 화면 검증


---

이어서 진행해줘.


---

Continue Task 4: view the simulator screenshot, then open PR #7 and merge.


---

xcrun simctl로 화면을 검증한 결과와 동일하게
XcodeBuildMCP 검증 결과도 PR 에 댓글로 추가해줘.


---

https://github.com/songda515/GithubSearch/pull/8 의 후속 작업으로 수정을 진행해줘.


---

Task 5. 검색 입력 화면 구현 진행

## 선행 작업
specs/search-recent 하위에 search_result_{}.png 파일 이동
XcodeBuildMCP 시나리오 검증 플로우도 CLAUDE.md 에 추가
implement-spec 스킬 사용에 대해 CLAUDE.md 추가 

## 화면
1. 검색어 입력전
- 최근 검색어를 최대 10개까지 노출
- 최근 검색어가 없을 경우 empty view 제공
2. 검색어 입력중
- SearchFeature 의 query 활용
- 자동완성은  improvement 에서 진행
3. 검색어 입력완료, 최근 검색어 클릭
- 최근 검색어 저장, 검색 결과가 로드되기 전에 선행
- 검색결과 화면으로 이동, 다음 task 에서 진행
4. 전체 삭제 버튼 클릭시
- Alert 화면에서 전체 삭제 재확인

## UI
- seearch_result_requirement.PNG 참고
- 최근 검색 section title 
- 최근 검색어 목록 row: {검색어} {close button}
- 전체 삭제 button 제공
- 전체 삭제 alert 제공

## 데이터구조
1. SearchRecentItem
- String, Date 기준으로 struct 데이터모델 생성

## CoreModule
- UserDefaultsClient 를 생성해서 test code 별도 셋업

## 정책
1. 최근 검색어는 앱 재시작시 유지되어야함
2. 최근 검색어 저장 개수: max 10개
3. 최근 검색어 노출은 날짜 기준 내림차순 정렬
- 최근 검색어 추가시 맨 앞 삽입
- 중복 검색어 추가시 기존 제거 후 맨 앞 삽입
- 10개 초과시 가장 오래된 검색어 제거


---

Continue Task 5: read swift test result; if green commit code, then xcodebuild + XcodeBuildMCP scenario screenshots, PR, merge.


---

PR #8 에서 진행하지 못한 XcodeBuildMCP  tap UI-automation 활성화해주고, 재 검증해서 댓글에 추가해줘.


---

현재 남은 Task 구현과 별개로 하네스 개선하고 싶은게 있어. 
- review-spec 스킬 생성해서 스펙과 실제 구현 코드가 올바른지 검증. implement-spec 스킬과는 분리되어야함
- 실행 조건: implement-spec 이후 test 통과 단계
- 동작: 컨텍스트가 포함되지 않도록 서브에이전트 기반으로 동작
- 점검: 스펙의 요구사항, 테스트 기준 재 점검, UI 렌더링과 참고화면 일치
- CLAUDE.md 플로우에 test -> review-spec -> 판정 -> PR 명시


---

CLAUDE.md 에 중복 항목 개선해줘. 
1. skill - single source 원칙에서 정리가 필요
- implement-spec, review-spec 등 스킬에 대한 상세한 내용은 스킬에서 확인가능하므로 간단하게 요약
- 추후 두개의 문서가 달라질 수 있음을 사전에 방지 목적

2. xcode build mcp  
- 설정에 대한 SSoT 는 .mcp.json 을 가리키도록 개선,  npx 커맨드 등 제거
- 화면검증 절차는 skill create 해서 CLAUDE.md 에는 스킬을 명시
- 기존 스킬에서 사용하던 플로우에서 skill 참조하도록 수정

3. Tech stack, 프로젝트 구조, 코드 작성 규칙, 검증, Git 등 항목은 유지

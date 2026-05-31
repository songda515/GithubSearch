---
name: review-spec
description: Use after implement-spec when a feature's tests pass (swift test + xcodebuild green) and before opening a PR — to independently verify that the implementation matches docs/specs/<feature>/spec.md. Also when code and spec might have drifted and you need an arms-length judgment, not the author's. Keywords: spec compliance, acceptance criteria coverage, UI vs reference screenshot, 판정, verdict.
---

# review-spec

## Overview

구현이 spec 과 일치하는지 **독립적으로 판정**하는 검증 레인. `implement-spec` 가 **만든다면**,
review-spec 은 **심판한다** — 둘은 반드시 분리된다.

**핵심 원칙:** 코드를 작성한 컨텍스트가 자기 코드를 승인하면 안 된다(셀프 승인 금지). 그래서 review-spec 은
**새 서브에이전트**로 돌려, 검증 과정(파일 읽기·스크린샷)이 메인 컨텍스트를 오염시키지 않고 **판정만** 돌려받는다.

## When to Use

- `implement-spec` 구현이 끝나고 **테스트가 통과**한 직후, **PR 직전**. (test → review-spec → 판정 → PR)
- 코드와 spec 이 어긋나 보여 제3자 시각의 판정이 필요할 때.

NOT: spec 이 없는 변경, 단순 리팩터/포맷팅, 아직 테스트가 빨간 상태(먼저 GREEN 으로).

## How it runs (서브에이전트)

메인 에이전트는 **직접 점검하지 않는다.** 읽기 전용 리뷰어 서브에이전트를 띄우고 판정만 받는다:

```
Agent(subagent_type: "oh-my-claudecode:code-reviewer",   // 또는 "verifier" — 읽기 전용 레인
      description: "review-spec <feature>",
      prompt: <아래 점검 프롬프트>)
```

서브에이전트는 **코드를 수정하지 않는다**(구현 레인과 분리). spec 경로·변경 파일·시뮬레이터(scheme `GithubSearch`)를 프롬프트에 명시한다.

## 점검 항목 (서브에이전트가 수행)

1. **요구사항 재점검** — `docs/specs/<feature>/spec.md` §2 의 각 요구사항이 코드에 실제 구현됐는지 대조.
2. **테스트 기준 재점검** — §8 수용 기준 ↔ 테스트 1:1. 테스트가 존재·통과하고 **그 기준을 실제로 단언**하는지(공허한 통과 아님). `swift test` 재실행.
3. **UI 렌더링 일치** — XcodeBuildMCP 로 빌드·실행 후 spec 의 각 UI 상태/엣지케이스를 만들어 `screenshot`,
   **참고 화면(`docs/specs/<feature>/*.PNG`)** 및 spec 표시 규칙과 일치하는지 확인. (탭 필요 시 `tap`/`snapshot_ui`)

## 판정 (Verdict) — 반환 형식

```
판정: PASS | FAIL
- 요구사항: <충족/미충족 + 근거>
- 수용기준↔테스트: <충족/미충족 + 근거>
- UI 일치: <일치/불일치 + 근거(어느 상태)>
[FAIL 시] 불일치 목록: 파일/위치 + 무엇이 spec 과 어떻게 다른가
```

- **PASS** → PR 단계로 진행.
- **FAIL** → `implement-spec` 로 복귀해 **spec 또는 코드**를 고치고(불일치는 spec 위반), 게이트 GREEN 후 **다시 review-spec**.

## Common Mistakes / Red Flags — STOP

- 구현한 컨텍스트가 그대로 판정 → 셀프 승인. **새 서브에이전트로 돌려라.**
- UI 스크린샷 대조 생략하고 "코드상 맞으니 PASS" → §3 누락.
- 기준을 단언하지 않는 테스트(예: 액션만 보내고 상태/이펙트 미검증)를 통과로 인정.
- FAIL 인데 PR 로 진행 → 금지. 고치고 재검증.

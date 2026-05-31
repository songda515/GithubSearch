---
name: verify-screen
description: Use when a GithubSearch screen's view layer needs checking on a real simulator — title/placeholder/empty view/alert/navigation 등 화면 표시, 또는 spec 의 UI 상태·엣지케이스를 참고 화면(docs/specs/<feature>/*.PNG)과 대조할 때. implement-spec 의 검증 게이트나 review-spec 의 UI 점검에서 호출된다. Keywords: XcodeBuildMCP, simulator screenshot, snapshot_ui, build_run_sim, UI 시나리오.
---

# verify-screen

## Overview

Reducer 로직은 `TestStore` 로 검증하지만, **뷰 레이어(타이틀·플레이스홀더·empty view·alert·전환 등 화면 표시)는
실제 시뮬레이터 화면으로 확인**한다. 이 스킬이 그 절차의 SSoT 다.

**설정 SSoT 는 `.mcp.json`** (XcodeBuildMCP 등록). 실행 커맨드·env 는 거기서만 관리하고 여기/CLAUDE.md 에
재기재하지 않는다. MCP 서버가 연결되면 shell 보다 XcodeBuildMCP 도구를 우선 사용한다.

## When to Use

- spec 의 UI 상태/엣지케이스를 화면으로 확인해야 할 때(implement-spec 검증 게이트).
- review-spec §3 UI 렌더링↔참고 화면 대조.

NOT: 순수 reducer/로직(=`TestStore`), 빌드/링크만 보는 경우(=`swift test`/`xcodebuild`).

## 절차

1. **세션 디폴트 확인** — 첫 build/run 전 `session_show_defaults` 로 project/scheme/simulator 확인
   (없으면 `discover_projs` → `session_set_defaults`, scheme `GithubSearch`, iOS 17+ 시뮬레이터).
2. **빌드·실행** — `build_run_sim`.
3. **시나리오별 캡처** — 화면별 spec 의 UI 상태/엣지케이스마다 상태를 만들고 `screenshot`. 좌표·요소 확인은
   `snapshot_ui`, 상태 전환은 `tap`/`type_text`. 예) 검색 입력 화면: ① empty view ② 최근검색어 노출 ③ 전체삭제 alert.
4. **대조·기록** — 캡처가 spec 표시 규칙·참고 화면(`docs/specs/<feature>/*.PNG`)과 일치하는지 확인하고 PR 검증 결과(또는 코멘트)에 남긴다.

## Tips / Gotchas

- 시뮬레이터 키보드가 한글 IME 면 `type_text` 의 라틴 입력이 조합되어 깨진다 → **탭으로 상태를 만들거나**
  (예: 최근검색어 항목 탭으로 query 주입) UserDefaults 를 seed 한 뒤 relaunch.
- UI 자동화(tap/type/gesture)는 `.mcp.json` 의 `ui-automation` 워크플로우가 켜져 있어야 한다(설정 SSoT 참조).
- MCP 서버 미연결(세션 재시작 전) 시 동일 엔진 CLI 로 대체 가능(커맨드는 `.mcp.json`/툴 도움말 참조).

## Common Mistakes

- 뷰 레이어를 `TestStore` 로만 검증하고 화면 캡처 생략 → spec UI 상태 미확인.
- 참고 화면(`*.PNG`) 대조 없이 "떴으니 OK" → 표시 규칙 불일치 놓침.
- 실행 커맨드를 이 문서/CLAUDE.md 에 복붙 → 설정 중복. `.mcp.json` 이 SSoT.

# GithubSearch — Claude Code Harness

iOS app built with **SwiftUI + The Composable Architecture (TCA)**.
This file is the contract for how code is written and verified in this repo.

---

## Tech stack (non-negotiable)

| Item | Value | Why |
|------|-------|-----|
| Minimum iOS | **17.0** | <1% market below 17; unlocks Apple-native Observation so TCA needs no Perception backport |
| Swift language mode | **Swift 6** (`SWIFT_VERSION = 6.0`, `swiftLanguageModes: [.v6]`) | Compile-time data-race safety (strict concurrency) |
| Architecture lib | **TCA, pinned `exact: "1.25.5"`** via SPM | Latest stable matching this iOS/Swift toolchain; exact pin = reproducible builds |
| UI | SwiftUI only | — |
| Tests | **Swift Testing** (`@Test` / `#expect`) + TCA `TestStore` | Xcode 26 default; async-friendly |

> TCA's min platform is iOS 16, so an iOS 17 floor is safe and gives native `@ObservableState`.
> `import ComposableArchitecture` re-exports `Dependencies`, so **do not** add `swift-dependencies` separately.

---

## Project structure — thin app shell + local SPM package

```
GithubSearch/                  ← thin app shell (.xcodeproj target). No business logic.
GithubSearchPackage/           ← ALL real code lives here (local SPM package)
  Package.swift                ← single source of truth for modules + deps
  Sources/AppFeature/          ← feature module (View + Reducer)
  Tests/AppFeatureTests/       ← reducer tests (Swift Testing + TestStore)
GithubSearchTests/             ← app-shell smoke tests (Swift Testing)
GithubSearchUITests/
docs/specs/                    ← SDD: per-screen policy SSoT (spec-first). See "Spec-Driven Development"
  _template/spec.md            ← copy to start a new feature spec
  <feature>/spec.md            ← single source of truth for one screen's policy
```

**To add a feature/client module: edit `GithubSearchPackage/Package.swift` + add files. Never hand-edit `.xcodeproj`.**
The app target depends on the package's products; adding a target there requires no Xcode project surgery.

---

## Rules for writing code

1. **Every screen = SwiftUI `View` + TCA `@Reducer`.** State via `@ObservableState`. No view without a reducer.
2. **Side effects go through Clients.** Anything with a dependency — network, disk/storage, system services — is isolated behind a `Client` struct of closures. Reducers never call URLSession/FileManager directly.
3. **Clients are injected via `@Dependency`.** Each Client conforms to `DependencyKey` and **must provide all three**:
   - `liveValue` — real implementation (production)
   - `testValue` — for tests (unimplemented by default so unhandled calls fail loudly)
   - `previewValue` — deterministic stub for SwiftUI previews
   Access in a reducer with `@Dependency(\.someClient) var someClient`.
4. **Swift 6 concurrency:** keep types `Sendable`; UI/reducer test types are `@MainActor`. Fix data-race warnings, don't silence them.
5. **Module boundaries:** public API in package modules must be explicitly `public`.

### Client skeleton (copy this shape)

```swift
import ComposableArchitecture

@DependencyClient
struct SomeClient: Sendable {
    var fetch: @Sendable (_ query: String) async throws -> [Item]
}

extension SomeClient: DependencyKey {
    static let liveValue = SomeClient(fetch: { query in /* real call */ })
    static let previewValue = SomeClient(fetch: { _ in [.mock] })
    // testValue is auto-synthesized as "unimplemented" by @DependencyClient.
}

extension DependencyValues {
    var someClient: SomeClient {
        get { self[SomeClient.self] }
        set { self[SomeClient.self] = newValue }
    }
}
```

---

## Spec-Driven Development (SDD)

Per-screen behavior is defined by **specs, not code**. The spec is the contract; the code implements it.

1. **SSoT = `docs/specs/<feature>/spec.md`.** Each screen/feature gets one directory; its `spec.md` is the
   single source of truth for that screen's policy. One feature = one `docs/specs/<feature>/`.
2. **Spec-first — change the spec before the code.** To change behavior, the order is always
   `spec.md` → review → code/tests. Code must never lead the spec. If implementation and spec disagree,
   it's a **spec violation**: fix the spec or bring the code back in line — don't silently diverge.
3. **What a spec records** (template enforces the sections): per-screen **요구사항 (requirements) ·
   엣지케이스 (edge cases) · API 명세 (API spec) · 정책 (policy)**, plus a **TCA mapping**
   (State / Action / Client) and **acceptance criteria** that map to `TestStore` scenarios.
4. **Start from the template:** `cp docs/specs/_template/spec.md docs/specs/<feature>/spec.md`, then fill
   every section (no blanks — use `TBD`). See `docs/specs/README.md` for the full convention.
5. **Workflow tie-in:** spec changes follow the same issue→branch→PR flow below. A behavior-change issue's
   checklist **starts with "update `spec.md`"**, and in the PR the **spec commit precedes the code commit**.
6. **Use the `implement-spec` skill.** When implementing or changing any screen/feature/Client, drive the
   work with the project skill `.claude/skills/implement-spec` (invoke `/implement-spec`). It enforces this
   exact order: spec 구체화 → §7 TCA 매핑 → §8 수용 기준을 `TestStore` 로(TDD RED→GREEN) → 검증 게이트.
   "코드부터 짜고 spec 을 맞추는" 흐름은 금지.
7. **Use the `review-spec` skill to judge — separately from implementing.** 구현(`implement-spec`)과
   **분리된 독립 검증 레인**. 테스트가 GREEN 이 된 뒤 PR 직전에 `.claude/skills/review-spec` (invoke
   `/review-spec`) 으로 spec↔구현 일치를 판정한다. 셀프 승인 금지 — review-spec 은 **새 서브에이전트**에서
   돌아 검증 과정이 메인 컨텍스트를 오염시키지 않고 **판정만** 반환한다. 점검: ① 요구사항(§2) 구현 ②
   수용 기준(§8)↔테스트 ③ UI 렌더링↔참고 화면. **FAIL 이면 PR 금지** — 고치고 재검증.

---

## Verification gates — RUN BEFORE ANY COMPLETION REPORT

**Do not report a task complete before build AND tests pass after code changes.** No exceptions.

```bash
# Fast reducer/unit tests (macOS host, no simulator) — primary loop
swift test --package-path GithubSearchPackage

# Pick an available simulator UDID (names can be ineligible across Xcode versions):
SIM=$(xcrun simctl list devices available | grep -m1 -oE '[0-9A-F-]{36}')

# iOS build verification (proves TCA imports + links for the iOS 17 target).
# -skipMacroValidation bypasses the interactive macro-trust prompt (TCA uses macros).
xcodebuild build -scheme GithubSearch -skipMacroValidation \
  -destination "platform=iOS Simulator,id=$SIM"

# App test target on simulator (Swift Testing). Add -only-testing:GithubSearchTests
# to skip UI tests for a faster loop.
xcodebuild test -scheme GithubSearch -skipMacroValidation \
  -destination "platform=iOS Simulator,id=$SIM" -only-testing:GithubSearchTests
```

Targeting by UDID is more robust than by name: simulator *names* available to `xcodebuild`
can differ from `simctl` across Xcode versions. Any simulator on iOS ≥ 17.0 works.

### Screen verification — XcodeBuildMCP (UI 시나리오)

Reducer 단위는 `TestStore` 로 검증하지만, **뷰 레이어(타이틀/플레이스홀더/empty view/alert 등 화면 표시)는
실제 시뮬레이터 화면으로 확인**한다. 이를 위해 `XcodeBuildMCP` 를 도입했다(`.mcp.json`,
`npx -y xcodebuildmcp@latest mcp`). MCP 서버가 연결되면 shell 보다 XcodeBuildMCP 도구를 우선 사용한다.

표준 시나리오 검증 플로우:

1. **세션 디폴트 확인** — 첫 build/run 전 `session_show_defaults` 로 project/scheme/simulator 확인
   (없으면 `discover_projs` → `session_set_defaults`).
2. **빌드·실행** — `build_run_sim` (scheme `GithubSearch`, iOS 17+ 시뮬레이터).
3. **시나리오별 화면 캡처** — 화면별 spec 의 UI 상태/엣지케이스마다 상태를 만들고 `screenshot`
   (필요 시 `snapshot_ui` 로 좌표 기반 요소 확인, `tap`/`type_text` 로 상태 전환).
   예) 검색 입력 화면: ① empty view ② 최근검색어 노출 ③ 전체삭제 alert.
4. **결과 기록** — 캡처 결과가 spec·참고 화면과 일치하는지 확인하고 PR 검증 결과(또는 코멘트)에 남긴다.

> MCP 서버 미연결(세션 재시작 전) 시에는 동일 엔진인 **XcodeBuildMCP CLI**
> (`npx -y xcodebuildmcp@latest simulator build-and-run|screenshot ...`) 또는 `xcrun simctl` 로 대체한다.

---

## Git & PR workflow

All work is **issue-driven**. The flow is: open an issue → branch → commit per sub-task → PR → merge.

1. **One unit of work = one issue.** Never start coding without an issue. Each issue must contain:
   - **요구사항 (Requirements)** — what to build
   - **규칙 (Rules)** — constraints to follow
   - **검증 (Verification)** — what must be proven, and how
   - **체크리스트 (Checklist)** — `- [ ]` sub-tasks that map to commits and acceptance criteria
2. **One issue = one branch = one PR.** Branch off the default branch, named `<issue#>-<short-slug>` (e.g. `2-github-search-feature`). Every issue gets its own PR; never mix two issues in one branch/PR.
3. **Commit per sub-task.** Each checklist sub-task in the issue is its own commit. Keep commits atomic and scoped to one sub-task. Reference the issue in commit messages (e.g. `... (#2)`).
4. **Gate before a PR: `test → review-spec → 판정 → PR`.** First run the full [Verification gates](#verification-gates--run-before-any-completion-report) (`swift test` + `xcodebuild build` + `xcodebuild test`); **if build or tests fail, do NOT commit** — fix first. Then, for spec-backed work, run **`review-spec`** (독립 서브에이전트 판정; SDD §7) and act on the 판정: **PASS → open the PR; FAIL → 고치고 test 부터 다시.** A PR is only opened from a GREEN + PASS state.
5. **PR body must describe** (in this order):
   - **Summary** — what changed and why, at a glance
   - **요구사항 (Requirements)** — the issue's requirements this PR fulfills (link the issue: `Closes #<n>`)
   - **검증 결과 (Verification results)** — actual build/test evidence (commands run + pass/fail)
   - **결정 근거 (Rationale)** — key design/trade-off decisions and why
6. **Merge with a merge commit.** Use a merge commit (`gh pr merge --merge`), not squash or rebase, so issue/branch history is preserved.

```bash
# gh runs as songda515 in this repo (see Notes). Branch + PR + merge:
TOK=$(tr -d '\r\n' < .gh-token)

git switch -c 2-github-search-feature           # one branch per issue
# ... commit per sub-task: git commit -m "Add GitHubClient (#2)" ...
# ... only after Verification gates are GREEN ...

GH_TOKEN="$TOK" gh pr create --repo songda515/GithubSearch \
  --title "..." --body-file <pr-body.md>         # body: Summary / 요구사항 / 검증 결과 / 결정 근거
GH_TOKEN="$TOK" gh pr merge --merge              # merge commit, not squash/rebase
```

---

## Notes

- `.gitignore` is configured for Xcode + SwiftPM (`.build/`, `.swiftpm/`, `xcuserdata/`, `DerivedData/`). `Package.resolved` is committed for reproducible dependency resolution.
- Skills: `.claude/skills/implement-spec` (구현; SDD §6) and `.claude/skills/review-spec` (판정; SDD §7) are configured. `.claude/rules` is not yet configured.
- MCP: `.mcp.json` registers `XcodeBuildMCP` for UI/screen verification (see "Screen verification" above). 활성화는 Claude Code 재시작 시 반영.

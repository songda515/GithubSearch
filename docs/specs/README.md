# Specs — Spec-Driven Development (SDD)

이 디렉터리는 **화면별 정책의 단일 진실 공급원(SSoT, Single Source of Truth)** 이다.
화면이 "무엇을, 왜, 어떤 규칙으로" 동작하는지는 코드가 아니라 **여기 적힌 스펙이 정의**한다.

## 핵심 규칙

1. **SSoT = `docs/specs/<feature>/spec.md`**
   화면(feature) 하나당 디렉터리 하나. 그 안의 `spec.md` 가 해당 화면 정책의 유일한 기준이다.
2. **Spec-first — 코드보다 스펙을 먼저 고친다.**
   동작을 바꾸려면 순서는 항상 `spec.md` 수정 → 리뷰 → 코드/테스트. 코드가 스펙을 앞서면 안 된다.
   구현이 스펙과 어긋나면 **코드가 아니라 스펙 위반**으로 보고, 스펙을 고치거나 코드를 스펙에 맞춘다.
3. **스펙에 담는 것**: 화면별 **요구사항 · 엣지케이스 · API 명세 · 정책**. (`_template/spec.md` 섹션 구조 준수)
4. **하네스 연계**: 화면 = SwiftUI `View` + TCA `@Reducer`, 의존성 = `Client`.
   스펙의 상태/액션/정책은 `State` / `Action` / `Client` 로 매핑되어 구현·테스트의 근거가 된다.

## 디렉터리 구조

```
docs/specs/
  README.md            ← 이 문서 (SDD 규약)
  _template/
    spec.md            ← 새 화면 스펙 작성용 템플릿 (복사해서 시작)
  <feature>/
    spec.md            ← 화면별 정책 SSoT (예: github-search/spec.md)
```

- `<feature>` 는 화면/기능 단위의 kebab-case 슬러그 (예: `github-search`, `repo-detail`).
- 한 feature가 여러 화면으로 커지면 `spec.md` 안에서 화면별 섹션으로 나누거나
  `<feature>/<screen>.md` 로 분할하되, 최상위 `spec.md` 가 인덱스/정책 SSoT를 유지한다.

## 새 스펙 만드는 법

```bash
mkdir -p docs/specs/<feature>
cp docs/specs/_template/spec.md docs/specs/<feature>/spec.md
# 템플릿의 모든 섹션을 채운다. 미정 항목은 'TBD'로 명시(빈칸 금지).
```

## 워크플로우 연계 (이슈/PR)

스펙 변경도 일반 코드와 동일하게 **이슈 단위**로 진행한다 (자세한 규칙은 루트 `CLAUDE.md` 참고).

- 동작 변경 이슈는 **체크리스트 첫 항목이 "spec.md 갱신"** 이어야 한다.
- PR 은 보통 **스펙 변경 커밋이 구현 커밋보다 앞**선다 (spec → code).
- 머지는 merge commit 으로 이력을 보존한다.

> 스펙은 살아있는 문서다. 정책이 바뀌면 해당 `spec.md` 의 **변경 이력**에 기록하고,
> `spec.md` 와 구현이 항상 일치하도록 유지한다.

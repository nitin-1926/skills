# Productionize Dimensions

Per-dimension checklists for Phase 1 (investigate) and Phase 4 (fix). Each dimension lists how to investigate, what to flag, and which fixes are safe vs. needs-approval.

A **safe fix** is reversible, behavior-preserving, and local (e.g. removing a narration comment). A **needs-approval fix** changes behavior, deletes code, alters public surface, or has cross-cutting blast radius. When in doubt, treat it as needs-approval.

---

## 1. Code hygiene (deslop)

**Investigate**: diff against the base branch where possible; skim recently changed files for tone inconsistency.

**Flag**:

- Comments that narrate the code rather than explain intent/trade-offs
- Defensive `try/catch`, null guards, or fallbacks abnormal for the area or guarding trusted/validated inputs
- `any` casts or equivalent escape hatches used to silence the type checker
- Formatting/naming/style inconsistent with the surrounding file
- Commented-out code, debug logging, and leftover scaffolding

**Safe fix**: remove narration comments, dead debug logs, commented-out code; align formatting.
**Needs approval**: removing defensive checks (confirm the path is truly trusted); replacing `any` with real types that may surface new errors.

---

## 2. Architecture / tech debt (zero tech debt)

**Investigate**: identify mode flags, props, wrappers, route aliases, and fallbacks; search for their real callers. Map duplicated rules (flags, permissions, routing, URL state, command naming).

**Flag**:

- Modes/props/wrappers/routes/fallbacks with **no current caller**
- One component or flow split across mode flags instead of a clear boundary
- Shared rules duplicated across pages or hidden inside view components
- Abstractions or "frameworks" built for a single feature

**Safe fix**: none here are truly safe — architecture changes almost always need approval.
**Needs approval**: delete uncalled paths (state the no-caller evidence); collapse mode flags into one clear flow; hoist shared rules to one place; split a unit only when it creates an obvious boundary (state, layout, controls, domain commands).

---

## 3. Correctness / error handling

**Investigate**: trace primary flows and their edges (empty, large, concurrent, failure). Check how errors propagate and surface to the user.

**Flag**:

- Unhandled rejections/exceptions on real failure paths; swallowed errors
- Missing edge-case handling on inputs that can actually occur
- Inconsistent error surfacing (silent failures, generic messages)
- Race conditions and incorrect async/await usage

**Safe fix**: surfacing an already-caught-and-swallowed error.
**Needs approval**: adding error handling that changes control flow or user-facing behavior; reworking async sequencing.

---

## 4. Security / secrets

**Investigate**: search for hardcoded secrets, tokens, keys; review input handling, auth/permission checks, and any public surface.

**Flag**:

- Hardcoded credentials/keys/tokens in source or committed config
- Missing input validation on untrusted boundaries (injection, XSS, etc.)
- Missing or inconsistent authentication/authorization checks
- Secrets logged or exposed in responses

**Safe fix**: none — security changes need approval and care; never rotate or remove a secret without coordination.
**Needs approval**: move secrets to env/secret store; add validation/auth checks; flag exposure for the user to rotate.

---

## 5. Tests

**Investigate**: locate the test runner and existing coverage; identify which critical flows are untested vs. covered.

**Flag**:

- Critical/approved-end-state flows with no test coverage
- Weak assertions or tests coupled to implementation details
- Skipped, flaky, or always-passing tests

**Safe fix**: adding tests for existing behavior (does not change product code).
**Needs approval**: deleting or rewriting existing tests; changing product code to make it testable.

---

## 6. Config / environment

**Investigate**: inventory env vars, config files, defaults, and how the app behaves when config is missing.

**Flag**:

- Undocumented or implicit required env vars
- Environment-specific values hardcoded in source
- Unsafe defaults or missing-config behavior

**Safe fix**: documenting existing env vars (e.g. `.env.example`).
**Needs approval**: changing defaults; externalizing hardcoded config; altering startup/validation behavior.

---

## 7. Docs / CI

**Investigate**: check README accuracy, setup/run instructions, and whether CI exists and what it enforces.

**Flag**:

- README/setup instructions that are missing, stale, or wrong
- No CI, or CI that does not run build/test/lint
- Undocumented architecture decisions needed to operate the project

**Safe fix**: correcting docs to match reality; documenting setup/run steps.
**Needs approval**: adding or changing CI pipelines; introducing new tooling or workflows.

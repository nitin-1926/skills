# Productionize Plans

A plan is the product of the `audit`, `architecture`, and `plan` paths. It is a self-contained markdown file that a **cheaper, weaker executor** — a model that never saw the audit session — can run start to finish without judgement calls.

Plans go in `plans/`, one file per selected finding, named `NNN-short-slug.md` (e.g. `001-fix-n-plus-one.md`). Writing a plan never modifies source.

## Three properties that make a plan executable

1. **Self-contained.** All context is inlined — exact file paths, current-state code excerpts, the repo's conventions with a named exemplar file, and the verified commands from recon. No "as discussed above."
2. **Verification gates.** Every step ends with a command and its expected output. Done criteria are machine-checkable so the executor never has to judge whether it succeeded.
3. **Hard boundaries.** Explicit out-of-scope lists and **STOP conditions** ("if X, stop and report") instead of letting a weak model improvise when reality doesn't match the plan.

## Plan file template

```markdown
# NNN — <title>

- Written against commit: <git rev-parse HEAD at write time>
- Category: <correctness | security | perf | tests | debt | config | docs | arch>
- Effort: <S | M | L>   Confidence: <HIGH | MED | LOW>
- Depends on: <other plan numbers, or none>

## Drift check (run first)
`git rev-parse HEAD` — if it does not match the commit above, re-read the cited
files; if they have changed materially, STOP and report.

## Problem
<what's wrong, with file:line evidence and impact>

## Current state
<inlined excerpts of the exact code to change>

## Conventions
<the repo's relevant conventions + an exemplar file path to imitate>

## Steps
1. <change> → verify: `<command>` → expected: `<output / exit 0>`
2. <change> → verify: `<command>` → expected: `<output>`
   ...

## Done criteria
- `<build command>` passes
- `<test command>` passes
- `<lint/types command>` passes
- <flow-specific check>

## Out of scope
- <explicitly not part of this plan>

## STOP conditions
- If <files already changed / command missing / test framework absent>, STOP and report.
```

## The index

Maintain `plans/INDEX.md`:

- A table of all plans with status (`TODO` / `IN PROGRESS` / `DONE` / `BLOCKED`).
- The **recommended order** to execute them.
- A **dependency graph** (which plans must land before others).

Keep the rejection ledger ([audit.md](audit.md)) alongside it (e.g. `plans/REJECTED.md`) so repeat audits don't re-surface dismissed findings.

## After writing

Hand the plans back to the user. They can hand any plan to any agent ("implement plans/001-*.md"), or run it through the `execute` path ([execute.md](execute.md)). Merging is always the user's call.

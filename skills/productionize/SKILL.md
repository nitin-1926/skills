---
name: productionize
description: Understand any repo in any state, then carefully productionize it — remove AI slop, reshape toward the intended end state, and harden correctness, security, tests, config, and docs. Use when the user wants to make a project production-ready, clean up tech debt, remove slop, harden a prototype, or "productionize" a codebase.
metadata:
  author: nitin-1926
  version: "1.0.0"
---

# Productionize

## Purpose

Take a repo in any state — prototype, AI-generated draft, half-finished feature, or aging codebase — and carefully move it toward the code that _should_ exist, not the smallest diff from what exists now. Remove accidental complexity and slop, reshape toward the intended end state, and harden the dimensions that production demands.

## Core principle

Optimize for the intended end state, but **never act before understanding the repo and confirming intent**. Be conservative by default. You are not here to rewrite everything optimistically — you are here to make deliberate, justified changes the user has approved.

## When to use

- Making a prototype or AI-generated draft production-ready
- Cleaning up tech debt / removing slop before a release or handoff
- Hardening a project across correctness, security, tests, config, and docs

## When NOT to use

- A single, well-scoped bug fix or feature (just do the work directly)
- A repo the user wants left as an explicit throwaway prototype
- When the user has not given you permission to change anything yet — run the phases instead of editing

## Workflow (strict, phased — approval gates between phases)

Do not skip phases. Do not edit code before Phase 4. Do not start Phase 4 without explicit approval.

```
Productionize Progress:
- [ ] Phase 1: Investigate the repo → inline readiness report
- [ ] Phase 2: Interview the user on the intended end state
- [ ] Phase 3: Present a risk/impact-ranked plan and get approval
- [ ] Phase 4: Execute in small, verified batches
```

### Phase 1 — Investigate

Build an accurate mental model before forming any opinion. Map:

- Stack, package manager, entry points, and how the app is built/run/tested/deployed
- What actually works vs. what is scaffolding, dead, or unreachable
- Slop and accidental complexity (see `references/dimensions.md`)
- Risks across the seven dimensions

Produce an **inline production-readiness report**: current state per dimension, with concrete findings (file paths, line refs). Do not write a file unless the user asks. Do not propose fixes yet.

### Phase 2 — Interview

Ask only the end-state questions the investigation could not answer. Use `references/interview.md`. Ask a few at a time, provide a recommended default for each, and stop asking once you can describe the intended end state in one or two sentences. The user's intent overrides your assumptions about what "production" means.

### Phase 3 — Plan

Present a written plan, ranked by risk and impact, grouped by dimension. For each item: what changes, why, the blast radius, and whether it is a safe fix or a needs-approval change. **Require explicit approval before any edit.** If the user pushes back, revise the plan — do not start editing.

### Phase 4 — Execute

- Work in small, reviewable batches (one coherent change at a time).
- Verify after each batch: build, tests, lint, and the specific flow you touched.
- Delete only with an identified justification (no current caller / dead path) — never delete on suspicion.
- If a batch reveals something new, return to the plan and confirm before expanding scope.
- End with a summary of what changed and what remains.

## Rules (carefulness gates)

- Conservative by default. When unsure whether to change something, flag it and ask — do not change it.
- Optimize for the code that should exist, not the minimal diff from the old shape — but only within the approved scope.
- Delete dead compatibility paths instead of improving them; never preserve a mode/prop/wrapper/route/fallback that has no current caller, and never delete one without confirming it has none.
- Do not invent a generic framework or abstraction for a single feature.
- Preserve existing behavior unless the intended end state explicitly changes it.
- Move shared rules (flags, permissions, routing, config, naming) to one place instead of duplicating.
- Prefer names that describe product intent over implementation history.
- Keep each refactor scoped to what makes the final shape coherent.

## Anti-patterns to remove (slop)

- Comments that narrate what the code does ("// increment counter", "// import the module")
- Defensive `try/catch`, null checks, or fallbacks that are abnormal for that area or guard already-validated/trusted call paths
- `any` casts (or equivalent escape hatches) used to silence type errors
- Style inconsistent with the surrounding file or codebase
- Speculative configurability, options, or layers with no real consumer

## Verification (before claiming done)

- Build, test suite, and linter pass.
- Every deletion has a stated no-caller / dead-path justification.
- The touched flows (navigation, permissions, persisted state, etc.) were exercised.
- Changes stayed within the approved plan; new findings were re-confirmed, not silently expanded.

## Additional resources

- Per-dimension investigate + fix checklists: [references/dimensions.md](references/dimensions.md)
- End-state interview questions: [references/interview.md](references/interview.md)

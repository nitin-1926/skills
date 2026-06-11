---
name: productionize
description: Master skill to understand any repo in any state and carefully productionize it — route to the right path (audit, architecture-deepen, plan, execute, reconcile), grill the user one question at a time when intent is unclear, remove AI slop, reshape toward the intended end state, and harden correctness, security, tests, config, and docs. Use when the user wants to make a project production-ready, clean up tech debt, remove slop, audit a codebase, deepen its architecture, or "productionize" a repo.
metadata:
  author: nitin-1926
  version: "2.0.0"
---

# Productionize

## Purpose

Take a repo in any state — prototype, AI-generated draft, half-finished feature, or aging codebase — and carefully move it toward the code that _should_ exist, not the smallest diff from what exists now. This is the **master skill**: it picks the right path for the request, runs a vetted audit, deepens architecture where it pays off, writes self-contained plans cheaper executors can run, and closes the loop on what shipped.

## Core principle

Optimize for the intended end state, but **never act before understanding the repo and confirming intent**. Be conservative by default. The audit and planning paths never touch source code — they produce findings and plans. Source only changes under an explicit, approved path, in small verified batches, or inside a disposable worktree.

## Decide the path first

Before doing anything, determine which path the request wants. **If the path is unclear, do not guess — grill the user one question at a time** (the `grill-me` discipline): ask a single sharp question, give your recommended default, wait for the answer, then ask the next. Explore the repo to answer a question yourself before asking it. Stop asking the moment the path and scope are clear.

See [references/router.md](references/router.md) for the path catalog, trigger phrases, and the decision tree.

| Path                 | When                                                                                | Reference                                          |
| -------------------- | ----------------------------------------------------------------------------------- | -------------------------------------------------- |
| `audit` (default)    | "productionize", "clean up", "what's wrong with this repo", "make production-ready" | [references/audit.md](references/audit.md)         |
| `architecture`       | "deepen the architecture", "find refactors", "this is hard to test/navigate"        | [references/deepening.md](references/deepening.md) |
| `plan <description>` | a specific change is already chosen; skip the audit and spec it                     | [references/plans.md](references/plans.md)         |
| `execute <plan>`     | run an existing plan and review the result                                          | [references/execute.md](references/execute.md)     |
| `reconcile`          | refresh the backlog: verify done, unblock, retire stale                             | [references/execute.md](references/execute.md)     |

**Focus filters** narrow an `audit` (combine freely): `quick` (hotspots only), `deep` (every package, every category), `branch` (only what the current branch changes), `next` (feature/direction suggestions), or a single dimension — `security`, `perf`, `tests`, `bugs`, `debt`, `config`, `docs`, `arch`.

## Workflow by path

### audit (default, phased — approval gates between phases)

Do not edit source on this path. Do not start executing without an approved plan.

```
Audit Progress:
- [ ] Recon: map stack, conventions, and exact build/test/lint/deploy commands
- [ ] Interview: pin down the intended end state (only what recon couldn't answer)
- [ ] Audit: fan out across dimensions, gather file:line evidence
- [ ] Vet: re-read every cited location; drop false positives; record rejections
- [ ] Rank: leverage-ordered findings table; user picks what to plan
- [ ] Plan: write self-contained plans/ artifacts + index
```

- **Recon** — build an accurate mental model. See [references/recon.md](references/recon.md). The commands you capture here become the verification gates in every plan.
- **Interview** — ask only the end-state questions recon couldn't answer, one at a time with defaults. See [references/interview.md](references/interview.md).
- **Audit** — fan out parallel explore subagents across the dimensions ([references/dimensions.md](references/dimensions.md)), every finding carrying `file:line` evidence, impact, effort, and confidence. See [references/audit.md](references/audit.md).
- **Vet** — subagents over-report. Re-read every cited location yourself; drop false positives, correct attributions, record rejections so they don't return.
- **Rank** — present a leverage-ranked findings table (impact ÷ effort, weighted by confidence). The user picks what becomes plans.
- **Plan** — write one self-contained file per selected finding into `plans/`, plus an index. See [references/plans.md](references/plans.md).

### architecture (deepening lens)

Surface architectural friction and propose **deepening opportunities** — refactors that turn shallow modules into deep ones, for testability and AI-navigability. Present candidates, let the user pick, then grill the design. See [references/deepening.md](references/deepening.md). Selected candidates become plans via [references/plans.md](references/plans.md).

### plan <description>

Skip the audit; spec one already-decided change directly as a self-contained plan. See [references/plans.md](references/plans.md).

### execute <plan> / reconcile

Dispatch a cheaper executor subagent in an isolated git worktree, then review the result like a tech lead. `reconcile` refreshes the whole backlog. See [references/execute.md](references/execute.md). Merging always stays the user's call.

## Hard rules

- **Audit and plan paths never modify source.** The only writes are to `plans/` (and `CONTEXT.md` / ADRs during the deepening loop). Executors edit only inside disposable worktrees; merging is always the user's.
- **Conservative by default.** When unsure whether to change something, flag it and ask — do not change it.
- **Approval gates.** Require explicit approval before any source edit. If the user pushes back, revise the plan — do not start editing.
- **Optimize for the code that should exist**, not the minimal diff — but only within the approved scope.
- **Delete dead compatibility paths instead of improving them.** Never preserve a mode/prop/wrapper/route/fallback that has no current caller, and never delete one without confirming it has none.
- Do not invent a generic framework or abstraction for a single feature.
- Preserve existing behavior unless the intended end state explicitly changes it.
- Move shared rules (flags, permissions, routing, config, naming) to one place instead of duplicating.
- Prefer names that describe product intent over implementation history.
- **Never reproduce secret values.** Report locations and credential types only; recommend rotation.

## Anti-patterns to remove (slop)

- Comments that narrate what the code does ("// increment counter", "// import the module")
- Defensive `try/catch`, null checks, or fallbacks that are abnormal for that area or guard already-validated/trusted call paths
- `any` casts (or equivalent escape hatches) used to silence type errors
- Style inconsistent with the surrounding file or codebase
- Speculative configurability, options, or layers with no real consumer

## Verification (before claiming done)

- Build, test suite, and linter pass (using the commands captured in recon).
- Every deletion has a stated no-caller / dead-path justification.
- The touched flows (navigation, permissions, persisted state, etc.) were exercised.
- Changes stayed within the approved plan; new findings were re-confirmed, not silently expanded.

## Additional resources

- Path catalog + grilling decision tree: [references/router.md](references/router.md)
- Repo recon → verification gates: [references/recon.md](references/recon.md)
- Parallel audit, vetting, leverage ranking: [references/audit.md](references/audit.md)
- Per-dimension investigate + fix checklists: [references/dimensions.md](references/dimensions.md)
- Architecture-deepening lens: [references/deepening.md](references/deepening.md)
- Self-contained plan artifacts: [references/plans.md](references/plans.md)
- Execute + reconcile loops: [references/execute.md](references/execute.md)
- End-state interview questions: [references/interview.md](references/interview.md)

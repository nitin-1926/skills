---
name: god-review
description: GOD-tier code review of the current branch's diff. Dispatches parallel reviewer personas (correctness, security, performance, architecture-depth, maintainability, tests, API contracts, migrations, reliability, concurrency, observability, i18n, accessibility, git-history, code-comments, and more), gates findings on anchored 0–100 confidence, promotes cross-reviewer agreement, validates each survivor with an independent pass, then emits a severity-ranked report with a provable coverage ledger and a merge verdict. Use when the user wants a deep, exhaustive, GOD-tier, thermo-nuclear, or "miss nothing" code review; a strict maintainability + security + architecture audit of a diff; or to review the current branch/PR before merge. Triggers on "god-review", "GOD review", "review everything", "deep/strict/thorough review", "thermo-nuclear review".
metadata:
  author: nitin-1926
  version: "1.0.0"
---

# God Review

## Purpose

The most thorough code review a single command can run. Review the **current branch's diff** the way a paranoid staff engineer would: fan out one specialist reviewer per dimension, hunt for the one bug or exploit each is built to find, then survive only what an independent validator can re-confirm. Output is a ranked report that **proves what it checked** — not a wall of nitpicks.

It fuses four lenses into one engine: structured persona fan-out (`/code-review`, `ce-code-review`), attacker-mindset security (`ce-security-reviewer`, `/security-review`), architecture-depth (`improve-codebase-architecture`), and ambitious maintainability "code judo" (thermo-nuclear).

## Core principles

- **Read-only by default.** Reviewers never mutate the tree. Fixes are opt-in and never auto-committed. See [Modes](#modes).
- **Miss nothing = provable coverage.** Every dimension is either evaluated or explicitly marked skipped-with-reason in the Coverage Ledger. Silent omission is the failure mode this skill exists to kill.
- **Evidence or it didn't happen.** Every finding cites `file:line` and a concrete failure scenario (inputs/state → wrong output/crash). No vibes.
- **Precision over volume.** A late confidence gate plus an independent validator pass kill false positives. Prefer a handful of high-conviction findings over a long list of cosmetic notes.
- **Be ambitious about structure.** Don't stop at "could be cleaner." Hunt for the code-judo move that deletes whole branches/layers. See [references/architecture-lens.md](references/architecture-lens.md).

## Modes

Parse arguments for an optional mode; default is `report`.

| Mode | Trigger | Behavior |
| --- | --- | --- |
| `report` (default) | bare invocation | Read-only. Review, print the ranked report + Coverage Ledger + Verdict. No edits. |
| `--comment` | `--comment` / "post on the PR" | Read-only on code. Post findings as PR comments via `gh` (full-SHA permalinks). |
| `--fix` | `--fix` / "and fix them" | After the report, apply only `safe_auto` findings, re-review them, then **stop and ask** before anything riskier. Never commits or pushes. |

A review target after stripping the mode token (`PR #`, URL, branch) overrides the diff base; otherwise review the current branch against its merge-base.

## Pipeline

```
God Review Progress:
- [ ] Scope:    resolve merge-base; collect diff; tier primary / secondary / pre-existing
- [ ] Dispatch: select personas (always-on + warranted conditionals + gap dims); fan out in parallel
- [ ] Collect:  each reviewer returns structured findings with file:line, anchor, severity
- [ ] Merge:    fingerprint + dedup; promote cross-reviewer agreement; gate confidence LATE
- [ ] Validate: one independent validator subagent per survivor; drop what it can't re-confirm
- [ ] Report:   ranked P0–P3 tables + Coverage Ledger + Verdict (then --comment / --fix if asked)
```

1. **Scope** — resolve the diff base by merge-base (never `git diff HEAD` fallback). Exclude generated/lockfiles/vendored. Tier every hunk. See [references/diff-scope.md](references/diff-scope.md).
2. **Dispatch** — pick the persona roster: always-on for everything, conditionals only when the diff warrants, gap dimensions when their surface is touched. Fan out read-only subagents in parallel, model-tiered by stakes. See [references/personas.md](references/personas.md).
3. **Collect** — each reviewer returns compact structured findings (`file:line`, anchor, severity, failure scenario, route). Security uses [references/security-lens.md](references/security-lens.md); architecture/maintainability use [references/architecture-lens.md](references/architecture-lens.md).
4. **Merge → 5. Validate** — fingerprint, dedup, promote agreement, gate `<75` (keep `P0@50+`), then validate each survivor independently. See [references/confidence.md](references/confidence.md).
6. **Report** — emit the ranked tables, Coverage Ledger, and Verdict. See [references/output.md](references/output.md).

## Hard rules

- **Never mutate source in `report`/`--comment` mode.** `--fix` applies only `safe_auto` findings, never commits, and stops before risky changes.
- **Never reproduce secret values.** Report location + credential type only; recommend rotation.
- **Don't flag what a linter/typechecker/CI catches** (formatting, imports, type errors). Assume CI runs separately.
- **Don't flag pre-existing issues on unmodified lines** — surface them in a separate, clearly-labeled section.
- **Every persona carries a "what NOT to flag" catalog.** No defense-in-depth on already-guarded code, no "consider adding X" without a named failure mode, no intentional/lint-disabled code. See [references/personas.md](references/personas.md).
- **Confidence gate runs late** — after cross-reviewer promotion — so corroborated mid-confidence findings get their chance.

## Additional resources

- Diff scoping + base resolution + tiers: [references/diff-scope.md](references/diff-scope.md)
- Persona roster + per-dimension hunt-lists + "what NOT to flag": [references/personas.md](references/personas.md)
- Anchored confidence, merge/dedup, promotion, validator pass: [references/confidence.md](references/confidence.md)
- Attacker-mindset security lens: [references/security-lens.md](references/security-lens.md)
- Architecture-depth + thermo-nuclear maintainability lens: [references/architecture-lens.md](references/architecture-lens.md)
- Output format: ranked tables + Coverage Ledger + Verdict: [references/output.md](references/output.md)

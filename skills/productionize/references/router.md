# Productionize Router

How to pick the path before doing any work, and how to grill the user when the path is unclear.

## Path catalog

| Path | Intent | What it produces |
| --- | --- | --- |
| `audit` (default) | Understand the repo and surface everything worth fixing | A vetted, leverage-ranked findings table → selected `plans/` |
| `architecture` | Find deepening opportunities (shallow → deep modules) | Candidate list → grilled design → selected `plans/` |
| `plan <description>` | A change is already decided; skip the audit | One self-contained plan file |
| `execute <plan>` | Run an existing plan and review the result | A reviewed diff in a worktree + a verdict |
| `reconcile` | Refresh the backlog after work landed | Updated `plans/` index (verified / unblocked / retired) |

### Focus filters (narrow an `audit`)

Combine freely with `audit`:

- `quick` — cheap pass: hotspots and the top findings only; skip exhaustive coverage.
- `deep` — exhaustive: every package, every dimension.
- `branch` — audit only what the current branch changes (diff against the base branch).
- `next` — feature / direction suggestions; every one must cite repo evidence, no generic idea-slop.
- A single dimension — `security`, `perf`, `tests`, `bugs`, `debt`, `config`, `docs`, `arch`.

## Trigger-phrase mapping

- "productionize this", "make it production-ready", "clean up this repo", "remove the slop", "harden this" → `audit`
- "what's wrong with this", "audit this", "what should I fix" → `audit`
- "audit only my branch", "review what I changed" → `audit branch`
- "what should I build next", "where should this go" → `audit next`
- "this is hard to test", "deepen the architecture", "find refactors", "too many tiny files to understand X" → `architecture`
- "write a plan for X", "spec out X" (X already chosen) → `plan <description>`
- "run plan 003", "implement plans/003-*.md" → `execute <plan>`
- "refresh the backlog", "what's still open", "did that land" → `reconcile`

## Decision tree (grill one question at a time)

Follow the `grill-me` discipline: **ask a single sharp question, give your recommended default, wait, then ask the next.** Explore the repo to answer a question yourself before asking it. Stop the moment path + scope are clear.

```
1. Is a specific change already chosen?
   - Yes → plan <description>
   - No  → continue
2. Does the request name an existing plan or the backlog?
   - "run/implement plan N"      → execute <plan>
   - "refresh / what's open"     → reconcile
   - No                          → continue
3. Is the request about testability / navigability / "shallow modules" / refactoring?
   - Yes → architecture
   - No  → audit (apply any focus filters the request implies)
```

If, after exploring, the request is still ambiguous between two paths, ask **one** disambiguating question with a recommended default — for example:

> "Do you want a full audit of the whole repo, or just the changes on your current branch? (default: full audit)"

Do not ask a second question until the first is answered. Never batch the whole decision tree into one message.

## Explore-before-ask

A question is only worth asking the user if exploring the repo cannot answer it. Resolve these yourself, do not ask:

- Stack, package manager, build/test/lint commands → read config files (see [recon.md](recon.md)).
- Whether a path has callers → search the codebase.
- Whether tests exist → locate the test runner.

Reserve questions for genuine intent: the end state, risk tolerance, must-keep paths, external consumers, and which path to take. The end-state questions live in [interview.md](interview.md).

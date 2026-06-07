# Productionize Audit

The audit turns recon into a vetted, leverage-ranked list of findings the user can choose from. It runs after [recon.md](recon.md) and the [interview.md](interview.md), and produces nothing but findings — **it never modifies source.**

## 1. Fan out

Dispatch parallel explore subagents, one per dimension (see [dimensions.md](dimensions.md)):

1. Code hygiene (slop) · 2. Architecture / tech debt · 3. Correctness / error handling · 4. Security / secrets · 5. Tests · 6. Config / environment · 7. Docs / CI · 8. Architecture depth (the deepening lens — see [deepening.md](deepening.md))

Plus, when the focus filter asks for it: **direction** (`next`) — feature and "where to take this" suggestions, where _every_ suggestion must cite evidence from the repo itself. No generic idea-slop.

Apply focus filters to the fan-out:

- `quick` — only the highest-signal dimensions (correctness, security) over the hotspots.
- `deep` — every dimension over every package.
- `branch` — every dimension, but scoped to the diff against the base branch.
- single-dimension filters (`security`, `perf`, …) — run only that subagent.

## 2. Evidence contract

Every finding a subagent reports must carry:

| Field | Meaning |
| --- | --- |
| `file:line` | Exact location(s) — the evidence |
| Impact | What goes wrong, and to whom (user, maintainer, security) |
| Effort | S / M / L — rough size of the fix |
| Confidence | HIGH / MED / LOW — how sure the finding is real |

A finding without a `file:line` and an impact is not a finding. Drop it.

## 3. Vet (re-read before showing anything)

Subagents over-report. Before presenting a single finding, **re-read every cited location yourself**:

- **False positive** → drop it (the code is fine, or the concern doesn't apply here).
- **Wrong attribution** → correct the `file:line` or restate the actual problem.
- **Rejected with a reason** → record it in the rejection ledger so it doesn't come back next run.

### Rejection ledger

Keep a short, durable list of dismissed findings with the reason — so a future audit doesn't re-surface them. Format:

```
- [SEC-01] https_proxy env var "SSRF": by-design — standard proxy convention, every CLI honors it. Not a finding.
- [DEBT-04] duplicated constant in a.ts/b.ts: intentional — different domains, coincidental value. Not a finding.
```

Persist the ledger where the project keeps its plans (e.g. `plans/REJECTED.md`) when the user wants audits to be repeatable; otherwise present it inline.

## 4. Rank by leverage

Order findings by **leverage = impact ÷ effort, weighted by confidence.** High-impact, low-effort, high-confidence findings rise to the top. Present as a table:

```
| # | Finding                                          | Category  | Effort | Confidence |
|---|--------------------------------------------------|-----------|--------|------------|
| 1 | shadow-config duplicated in search.ts/view.ts,   | tech-debt | M      | HIGH       |
|   | copies already drifted (TODO at search.ts:31)    |           |        |            |
| 2 | O(n^2) icon migration (migrate-icons.ts:168)     | perf      | S      | HIGH       |
| 3 | no test coverage on the auth refresh path        | tests     | M      | MED        |
```

## 5. Hand off

Ask the user which findings to turn into plans ("plan 1, 3 and 5"). Selected findings become self-contained plan files — see [plans.md](plans.md). Do not start editing source; the audit's product is the findings table and the plans, not a diff.

# Output

The report has three parts, always in this order: **ranked findings**, **Coverage Ledger**, **Verdict**. The ledger is what makes "miss nothing" provable — it shows what was checked, not just what was found.

## 1. Ranked findings

Group by severity, highest first. Use the stable `#` assigned to the validated survivors at the end of the [merge + validation pipeline](confidence.md) — never renumber.

```markdown
### P0 — must fix before merge
| # | File:line | Issue | Reviewer(s) | Conf | Route |
|---|-----------|-------|-------------|------|-------|
| 1 | api/auth.ts:42 | Ownership check missing — user A can read user B's order | security, adversarial | 100 | gated_auto |

### P1 — should fix
| # | File:line | Issue | Reviewer(s) | Conf | Route |
|---|-----------|-------|-------------|------|-------|
| 2 | sync.ts:88 | Two independent writes can leave state half-applied on error | correctness, reliability | 75 | manual |

### P2 / P3 …
```

Under each table, for any finding that needs more than a row, add a short block: the **failure scenario** (concrete inputs/state → wrong output) and a **suggested fix** grounded in an existing convention in the repo (grep for the canonical pattern before proposing one). No suggested fix without a named failure mode.

Then, if present:

- **Requirements completeness** (only when the `requirements` persona fired) — a short checklist of each discovered acceptance criterion marked `met` / `not addressed` / `partially addressed`, so "does the diff do what it set out to" is on record alongside "is the diff correct".
- **Pre-existing (not blocking)** — a separate labeled section for problems on lines this diff didn't touch.
- **Applied fixes** (only in `--fix` mode) — what `safe_auto` findings were applied, and what was left for approval.

## 2. Coverage Ledger

Proof of work. List every dimension and its disposition:

```markdown
### Coverage Ledger
| Dimension | Status | Notes |
|-----------|--------|-------|
| correctness | ✅ reviewed | 3 findings, 1 surfaced |
| security | ✅ reviewed | diff touched auth/ |
| performance | ⏭️ skipped | no DB/loop/hot-path changes |
| history (blame) | ✅ reviewed | diff modifies existing lines |
| i18n | ⏭️ skipped | no user-facing strings |
| accessibility | ✅ reviewed | JSX changed |
| requirements | ⏭️ skipped | no plan/issue/acceptance criteria found |
| … | | |

Suppressed: 4 findings below anchor 75 · 2 validated out · 1 pre-existing (separate section).
```

Every persona from [personas.md](personas.md) appears exactly once — either `reviewed` or `skipped` with the reason it didn't fire. A skipped dimension with no reason is a bug in the review, not a clean result.

## 3. Verdict

A blockquote with the call and the reasoning:

```markdown
> **Verdict: changes requested.** 1 P0 (auth bypass) blocks merge.
> **Fix order:** #1 (auth) → #2 (atomicity) → P2s at author's discretion.
> **Reasoning:** behavior is otherwise correct; the architecture-depth pass found no structural regression. The P0 is a real ownership-check gap with a constructible exploit.
```

The bar for an **approve** verdict (mirrors the thermo-nuclear bar): no structural regression, no unjustified file-size explosion, no spaghetti-growth from special-case branching, no hacky/magical abstraction, no unnecessary wrapper/cast churn, no architecture-boundary leak or canonical-helper duplication, and no surviving P0/P1. Don't approve merely because behavior seems correct.

## `--comment` mode (PR posting)

When asked to post on the PR, use `gh` (not web fetch). Keep it brief, no emojis. Cite each finding with a **full-SHA permalink** so GitHub renders it:

```
https://github.com/<owner>/<repo>/blob/<full-sha>/path/to/file.ts#L40-L45
```

Provide ≥1 line of context before and after the cited line. Post the ranked findings and the Verdict; the full Coverage Ledger can stay in the local report. If no findings survive, post a one-line "No issues found — checked: <dimensions>." so the coverage is still on record.

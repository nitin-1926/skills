# Confidence, Merge & Validation

The quality engine. Reviewers over-report; this pipeline is what turns raw findings into a short, high-conviction report. Unfiltered LLM review runs >95% false positives — these stages are not optional.

## Finding schema

Each reviewer returns a list of findings, each:

```json
{
  "file": "path/relative/to/repo",
  "line": 142,
  "tier": "primary | secondary | pre_existing",
  "title": "one-sentence statement of the defect",
  "failure_scenario": "concrete inputs/state → wrong output/crash",
  "severity": "P0 | P1 | P2 | P3",
  "anchor": 0,
  "autofix_class": "safe_auto | gated_auto | manual | advisory",
  "reviewer": "correctness"
}
```

## Anchored confidence (copy this rubric verbatim into every reviewer)

Score each finding on the discrete scale — never a float (the model can't calibrate finer, and discrete anchors prevent false precision):

- **0** — Not confident. False positive under light scrutiny, or pre-existing.
- **25** — Somewhat confident. Might be real, couldn't verify. Suppress.
- **50** — Moderately confident. Verified real, but may be a nitpick or rare in practice.
- **75** — Highly confident. Double-checked; names a concrete observable consequence (wrong result / unhandled path / contract mismatch / security exposure) that will be hit in practice.
- **100** — Certain. Verifiable from the code alone — literal injection, definitive logic bug, type/compile contradiction, a quotable standards violation.

**Anchor and severity are independent axes.** Anchor gates *whether a finding surfaces*; severity *orders* what surfaced. A typo can be anchor-100/P3; a subtle auth bypass can be anchor-50/P0.

## Severity scale

| Level | Meaning | Action |
| --- | --- | --- |
| **P0** | Critical breakage, exploitable vuln, data loss/corruption | Must fix before merge |
| **P1** | High-impact defect hit in normal usage, broken contract | Should fix |
| **P2** | Moderate issue with real downside (edge case, perf regression, maintainability trap) | Fix if straightforward |
| **P3** | Low-impact, narrow, minor improvement | Author's discretion |

## Action routing (who acts next)

| `autofix_class` | Meaning |
| --- | --- |
| `safe_auto` | Local deterministic fix; safe for `--fix` mode to apply |
| `gated_auto` | A concrete fix exists but it changes behavior/contract/permissions — needs approval |
| `manual` | A design decision; hand off, don't auto-apply |
| `advisory` | Report-only (residual risk, rollout note, learning) |

## Merge pipeline (run in this order)

1. **Validate returns** against the schema; drop malformed findings.
2. **Fingerprint & dedup** — fingerprint = `normalize(file) + line_bucket(line ±3) + normalize(title)`. On collision, merge into one: keep the **highest severity** and **highest anchor**, and record every reviewer that flagged it.
3. **Cross-reviewer promotion** — if 2+ independent reviewers flagged the same fingerprint, promote one anchor step (50→75→100). Independent agreement is stronger signal than any single reviewer.
4. **Partition `pre_existing`** into its own bucket — never gate the PR on it.
5. **Gate confidence LATE** — only now suppress everything `< 75`. **Exception:** keep any `P0` at anchor `50+` (critical-but-uncertain must never be silently dropped). Record suppressed counts by anchor for the [Coverage Ledger](output.md).
6. **Normalize routing** to the most conservative `autofix_class` among merged duplicates.
7. **Defer numbering until after validation.** Do not assign report numbers yet — the validator pass below still drops findings, and gapped IDs (`#2, #5, …`) confuse downstream readers. Numbering happens once, over the validated survivors (see below).

## Validator second pass

For **each** finding that survives the gate, spawn one independent **validator subagent** with fresh context and no stake in the original:

- Give it only the finding (file, line, title, failure scenario) and the diff scope — not the reviewer's reasoning.
- It re-derives from the code whether the failure scenario actually holds.
- **Conservative bias:** if it cannot reproduce/re-confirm the finding, drop the finding. A validator failure is a drop, not a keep.
- Per-finding (not batched) so each judgment stays independent.

Findings that survive validation are the report. Everything dropped here is tallied in the Coverage Ledger as "validated out", so the count is visible rather than hidden.

**Now number them.** Across all surviving findings, assign `#1, #2, …` in severity order (P0 first), then **never renumber** — downstream comments and tickets reference these stable IDs. Because numbering is the last step, the sequence is contiguous with no gaps from dropped findings.

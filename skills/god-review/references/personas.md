# Persona Roster

One specialist reviewer per concern beats one monolith — a narrow prompt finds the bug a broad scan walks past. Dispatch each as a **read-only** subagent (Read/Grep/Glob/Bash for non-mutating `git`/`gh` only), in parallel, model-tiered by stakes.

## Selection: three layers

1. **Always-on** — run on every non-trivial diff.
2. **Conditional** — run only when the diff touches the persona's surface. Decide by judgment, not keyword match: a refactor that moves an auth check still warrants security.
3. **Gap dimensions** — the concerns almost no tool covers. Run when their surface is touched. This is the "miss nothing" edge.

Record which layer fired which persona — the [Coverage Ledger](output.md) reports it.

| Layer | Persona | Fires when |
| --- | --- | --- |
| always-on | correctness | always |
| always-on | maintainability (thermo-nuclear) | always — see [architecture-lens.md](architecture-lens.md) |
| always-on | architecture-depth | always — see [architecture-lens.md](architecture-lens.md) |
| always-on | tests | always |
| always-on | project-standards | a `CLAUDE.md`/`AGENTS.md` exists in repo root or a touched dir |
| conditional | security | auth, input handling, public endpoints, crypto, secrets, deserialization — see [security-lens.md](security-lens.md) |
| conditional | performance | DB queries, loops over data, caching, hot paths, I/O |
| conditional | api-contract | exported types, request/response shapes, public signatures, versioning |
| conditional | data-migrations | migration files, schema changes, backfills |
| conditional | reliability | retries, timeouts, circuit breakers, background jobs, error handling |
| conditional | adversarial | diff ≥ 50 changed lines, or touches auth/payments/data mutation/external APIs |
| conditional | history (git blame) | the diff modifies existing lines — read blame/recent history to catch bugs the historical context reveals |
| conditional | code-comments | modified files carry comments/docstrings near the change whose guidance the diff may now violate |
| conditional | previous-comments | reviewing a PR/branch that already has review comments — re-check whether prior feedback was addressed |
| conditional | requirements | a plan, linked issue, or PR body with acceptance criteria is discoverable — verify the diff actually meets them |
| gap | concurrency / races | shared mutable state, async UI, transactions, multi-step workflows |
| gap | observability | new failure paths, logging, metrics, trace context — *and PII/secrets in logs* |
| gap | i18n / l10n | user-facing strings, dates, currency, Unicode/RTL handling |
| gap | accessibility | HTML/JSX/components — keyboard nav, ARIA, contrast, screen-reader |

## Per-persona hunt-list

Each reviewer gets its hunt-list, the [diff scope](diff-scope.md), the [confidence rubric](confidence.md), the PR/intent summary, and the **universal "what NOT to flag"** below.

- **correctness** — requirements vs implementation, off-by-one, null deref, incomplete state machines, time/zone/overflow edges, surfaced implicit assumptions.
- **maintainability** — see [architecture-lens.md](architecture-lens.md): code-judo moves, spaghetti growth, 1k-line file explosions, thin wrappers, magic, copy-paste vs extracted helper.
- **architecture-depth** — see [architecture-lens.md](architecture-lens.md): shallow modules, leaky seams, logic in the wrong layer, lost locality, bespoke helpers duplicating a canonical one.
- **tests** — tests submitted with code, test *validity* (does it fail when the code breaks?), edge coverage, assertion specificity, brittle implementation-coupling.
- **project-standards** — audit against the repo's own `CLAUDE.md`/`AGENTS.md`. Cite the exact rule. Standards are guidance for writing code — not every rule applies at review time.
- **security** — [security-lens.md](security-lens.md).
- **performance** — N+1 queries, unbounded in-memory growth, missing bulk/JOIN, algorithmic complexity vs data volume, cacheable repeats, blocking calls that should be async.
- **api-contract** — additive vs breaking change, deprecated-field handling, downstream consumer impact, undocumented contract drift.
- **data-migrations** — rollback path, atomicity, index/lock implications, truncation risk, backfill correctness against real data shapes.
- **reliability** — silent catch/`pass`, graceful partial failure, resource cleanup on every path, idempotency, retry storms.
- **adversarial** — don't check patterns; *construct the failure*. "Given these inputs/this state, here is the exact sequence that breaks it." See [confidence.md](confidence.md) anchor 75+.
- **history** — `git blame`/`git log -p` the modified lines. Does the change reintroduce a bug a past commit fixed, or contradict the reason a line was last touched? Read prior PRs that changed these files for warnings that still apply.
- **code-comments** — read comments and docstrings adjacent to the change. Does the diff break an invariant a comment promises, or leave a comment now lying about the code? (Comment-rot is a real finding; comment style is not.)
- **previous-comments** — when prior review threads exist, check each against the current diff: addressed, ignored, or newly re-broken. Re-emit unresolved feedback instead of burying it under a fresh round.
- **requirements** — discover acceptance criteria (the `plan:` arg, a linked issue, the PR body). For each, mark met / not addressed / partially addressed against the diff. Don't invent requirements that aren't stated.
- **concurrency** — shared-resource sync, interleaving, transaction atomicity/rollback, async UI lifecycle races, DOM-timing.
- **observability** — can prod be debugged from the logs/metrics this adds? Any PII/secrets/tokens written to logs or error messages?
- **i18n** — hardcoded locale strings, unabstracted date/currency, Unicode/RTL breakage.
- **accessibility** — keyboard operability, ARIA correctness, contrast, focus management, screen-reader semantics.

## Universal "what NOT to flag"

Carry this in every persona prompt — this is where signal-to-noise is won:

- Anything a linter/typechecker/compiler/formatter catches (style, imports, type errors, newlines). Assume CI runs them.
- Pre-existing issues on lines this diff didn't modify.
- Pedantic nitpicks a senior engineer wouldn't raise.
- Defense-in-depth on already-guarded code ("add a second escape just in case").
- Generic advice with no named failure mode ("consider rate limiting", "consider a CSP header").
- Intentional changes, or issues explicitly silenced by a lint-disable comment.
- Test-coverage or doc complaints unless the project standards demand them.

## Dispatch mechanics

- **Model-tier:** correctness, security, adversarial inherit the session/frontier model; the rest run a mid-tier model to cut cost.
- **Bounded parallelism:** respect the harness active-subagent cap; treat a capacity error as backpressure (requeue), not a reviewer failure.
- Each subagent writes its full reasoning to a run artifact and returns only the compact findings the merge stage needs ([output schema](confidence.md)).

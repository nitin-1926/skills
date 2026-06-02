# DEVLOG — {{PROJECT_NAME}}

> A running, append-only log of every substantive bug fix, feature, refactor, build/CI change, and decision that shapes this project. Written _during_ the session that made the change so that future blog posts, LLM-mistake pattern analysis, or context-restoration reads can reconstruct the journey without spelunking through git history.

This file may be **local-only and gitignored** (maintainer journal) or **committed** (team-visible decision log) — check `.gitignore` to see which mode this project uses.

---

## Problem statement

{{PROJECT_PURPOSE}}

---

## Baseline (state before this log begins)

{{BASELINE}}

---

## Entry template

Every new entry follows this skeleton. Keep it compact — the goal is fast scan, not novel-length prose. Link out instead of restating.

```markdown
### YYYY-MM-DD — <one-line title naming the artifact + change>

- Type: bug | feature | refactor | build | docs | chore
- Scope: <files / packages / commands affected>

Reasoning / RCA / research:
<1-6 bullets. For bugs: what broke, root cause, why the obvious fix
was wrong. For features: why it matters, what alternatives were
considered and rejected. For refactors: what changed in shape
without changing behavior, and what motivated the reshape.>

Implementation summary:
<1-6 bullets. What code moved, what files were added/deleted, what
tests landed, what verification ran.>

Follow-ups deferred:
<Optional. Known unfinished work — anything you intentionally
decided NOT to do in this change, with the reason.>
```

### Style rules

- **Capture _why_, not _what_.** The diff already shows what. The journal earns its keep by recording decisions.
- **Name files affected** so a future grep finds the entry from a path.
- **State tradeoffs explicitly:** "considered X but Y because Z." A rejected option is more valuable than the chosen one when read six months later.
- **Note failed approaches.** If you tried fix A and it didn't work before fix B did, both belong — the dead-end teaches.
- **Each bullet ≤2 sentences.** If you need more, link to a longer doc and summarize.
- **Don't paraphrase the diff.** "Renamed `foo` to `bar`" is useless; "renamed `foo` to `bar` because `foo` collided with the new public API for the upgrade path" is the entry.

### Anti-patterns

- **Don't batch unrelated changes** into one entry. One logical change per entry.
- **Don't write entries days later.** Context decays in hours. The skill exists because the LLM forgets — write while it remembers.
- **Don't edit past entries.** Correct factual errors with a _new_ entry that references the old one. The chronology is the point.
- **Don't omit the boring-looking changes.** Build/CI/docs changes shape the project's behavior over time and surface in pattern analysis.

New entries go at the **top** of the Log section (reverse chronological).

---

## Log

### YYYY-MM-DD — Devlog initialized via `/setup-devlog`

- Type: chore
- Scope: `DEVLOG.md`, `CLAUDE.md` (or `AGENTS.md`), `.gitignore`

Reasoning / RCA / research: - Project lacked a structured journal of decisions, tradeoffs, and
bug fixes. Future blog posts, LLM-mistake pattern reads, and
context-restoration sessions need a single source they can scan. - Chose append-only flat markdown over a tool (Notion, Linear)
because the file lives next to the code, follows the repo, and
survives tool churn.

Implementation summary: - Created DEVLOG.md from the setup-devlog skill template - Added discipline section to CLAUDE.md so every Claude Code session
reads the rule and appends entries during the same session as a
substantive change - {{GITIGNORE_DECISION}}

Follow-ups deferred: - First few entries set the tone. If they drift toward "what
changed" instead of "why we chose this," recalibrate by reading
back the Style rules above.

---

<!-- end of template — sample entries follow that show the shape -->
<!-- Replace these with your own; keep them only as scaffolding while writing the first 2-3 real entries -->

### 2026-01-15 — Replaced bespoke retry loop in `client/http.go` with `cenkalti/backoff` after the third spurious 5xx storm

- Type: refactor
- Scope: `client/http.go`, `client/http_test.go`, `go.mod`

Reasoning / RCA / research: - The bespoke linear retry shipped with no jitter; under load it
dogpiled the upstream service every 30s and amplified the 5xx
window we were trying to absorb. - Considered fixing in-place (add jitter, exponential backoff) but
the existing code had no tests and the math was inline-trivial
to get wrong. `cenkalti/backoff` is well-trodden, has a clean
`RetryNotify` API, and adds 0 transitive deps for our usage. - Rejected: implementing our own jittered exponential — would have
required a test matrix we were going to copy from the library
anyway.

Implementation summary: - Replaced 40 lines of manual retry with `backoff.RetryNotify`
using `NewExponentialBackOff` defaults plus a 30s `MaxElapsedTime` - Added `TestHTTPClient_RetriesAreJittered` that asserts no two
retry intervals are identical across 100 attempts - Net diff: -42 +18 lines including tests

Follow-ups deferred: - Per-endpoint MaxElapsedTime override — current single value is
fine for now but auth endpoints want a tighter ceiling

### 2026-01-22 — Caching `getUserPreferences` shaved p50 from 180ms to 22ms but broke logout invalidation

- Type: bug
- Scope: `services/preferences.ts`, `auth/logout.ts`, `services/preferences.test.ts`

Reasoning / RCA / research: - Earlier change cached `getUserPreferences` per-request, then
lifted to per-session for the latency win. Per-session was
correct except logout — old cache survived in Redis and the next
login as the same user re-read stale prefs. - Wrong fix attempt: invalidate on logout endpoint. Found this
missed flows that logout via session expiry (no endpoint hit).
Right fix: hook the cache key to `sessionId` (not `userId`) so
a new session gets a fresh cache regardless of how the prior
one ended.

Implementation summary: - Cache key changed from `prefs:{userId}` to `prefs:{sessionId}` - Removed the logout-endpoint invalidation (now redundant) - Added test that exercises session-expiry path

Follow-ups deferred: - Cache stampede protection (singleflight) — harmless under
current traffic but worth adding before we scale beyond 5x

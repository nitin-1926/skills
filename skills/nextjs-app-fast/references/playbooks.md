# Playbooks

Operational fixes for each class from the skill workflow. Measured case study: [field-record.md](field-record.md).

Do one playbook at a time. Measure before and after in the same environment. After every change, name the new silent-failure mode and what catches it (see [Silent failures](#silent-failures)).

---

## Instrument

Use when latency numbers cannot be attributed to a route or query.

**Request-path log** — put the path immediately before the host's duration REPORT in the same log stream:

```ts
// middleware.ts (or proxy.ts on hosts that renamed it)
console.log(`[req] ${request.method} ${pathname}`);
```

**Prisma slow-query tripwire** — log duration + SQL only. Never params (PII lands in CloudWatch forever):

```ts
prisma.$on("query", (e) => {
  if (e.duration < SLOW_QUERY_MS) return; // default 300
  console.warn(`[slow-query] ${e.duration}ms ${e.query}`);
  // NEVER e.params
});
```

Leave a test that the tripwire fires *and* leaks no params.

Before proposing any optimisation: if the answer to "what produced this number?" is inference, stop here.

---

## Bounded fan-out

Use when `await` sits inside a loop over DB or HTTP across a network boundary. Invisible on localhost (~1ms/row); fatal against a remote pool (~hundreds of ms of waiting per row).

**Wrong tools:**

| Attempt | Why it fails |
| --- | --- |
| `prisma.$transaction([...])` | Atomic, not concurrent. Round trips stay serial; default tx timeout then kills long batches. |
| Unbounded `Promise.all` | Exhausts the pool → `Can't reach database server`. |
| Guessed higher limit (25→50) | Hangs past what the pool serves. Measure the limit. |

**Shape that works** — bounded concurrency; count rejections, do not throw the whole batch (a row can vanish between read and write):

```ts
export async function runConcurrent<T>(
  tasks: (() => Promise<T>)[],
  limit = 10,
): Promise<{ ok: T[]; failed: number }> {
  const ok: T[] = [];
  let failed = 0;
  let i = 0;

  async function worker() {
    while (i < tasks.length) {
      const idx = i++;
      try {
        ok.push(await tasks[idx]());
      } catch {
        failed++;
      }
    }
  }

  await Promise.all(
    Array.from({ length: Math.min(limit, tasks.length) }, () => worker()),
  );
  return { ok, failed };
}
```

Start from a conservative measured limit (field record used 25 for DB upserts, 8 for Slack). Raise only with before/after numbers under load.

---

## Diff-before-write

Use when a job re-upserts an entire derived set to change a small delta.

1. Read current rows once.
2. Diff against the newly derived values.
3. Write only the delta.
4. **Verify the comparison returns true for unchanged rows** before shipping — a dead diff is slower than no diff (extra read + full write).

**Canonical compare for `jsonb`** — Postgres does not preserve object key order; arrays keep order:

```ts
const canonical = (v: unknown) =>
  JSON.stringify(v, (_, x) =>
    x && typeof x === "object" && !Array.isArray(x)
      ? Object.fromEntries(
          Object.entries(x).sort(([a], [b]) => a.localeCompare(b)),
        )
      : x,
  );
```

Also watch `Map`, `Set`, and `Date` precision. Deduplicate identical queries on one request path (two callers each loading the same full set buys nothing).

---

## Paginated tables

Use when a directory/table is "slow" but already pages on the server.

1. **Profile the counts before the rows.** A `count` with an unindexable predicate often dominates `findMany`.
2. **Leading-wildcard `LIKE` / `contains`** (`email LIKE '%@x.com'`) never uses a btree. Indexing alone will not fix it.
3. **Cache filter-independent counts** behind a tag the sync invalidates (e.g. `TAGS.contacts`). Do not recompute constants on every keystroke.
4. **Reuse** when the page's own `where` is identical to a "grand total" filter — do not run the same 135k-row scan twice.
5. **NULL in partition predicates** — `NULL LIKE …` is `NULL`; `NOT NULL` is `NULL`. Rows fall out of both sides. Prefer null-safe predicates; correctness often appears while speeding up.
6. **Reject denormalised flags** (`isInternal`) until cache misses demand them — migration + backfill + sync forever. Next step if needed: `pg_trgm` GIN (helps search too), not an application-owned column.

---

## Payload

Use when first paint waits on full-table reads or the RSC payload ships the whole dataset for client filtering.

1. **Static shell that awaits nothing** — heading/chrome on the first frame; data behind `loading.tsx` / Suspense or a client fetch to a page API.
2. **Filter, sort, count, and page on the server** — first payload is one page, not the full set.
3. **Move search server-side when the client no longer has the full set.** Local search over one page of N silently lies. Debounce (~250ms) is fine; a wrong answer is worse than a slower one.
4. **Header counts from server `total`**, not `slice.length` — board columns and "+N more" must be honest about the whole column.

Audit every client-side search / count / sort that assumed the full set after you paginate.

---

## Jobs / platform

Use when cron/sync routes timeout, stall as "running", or budgets never fire.

1. **Observe the host kill**, do not trust `export const maxDuration = 60`. Amplify Hosting cuts SSR at 30s and freezes the Lambda mid-handler — `finishedAt` never writes.
2. **One constant** — `PLATFORM_BUDGET_MS` derived from the observed wall. A check script asserts no job budget exceeds it (non-vacuous: restoring an old oversize value must fail assertions).
3. **Reserve for the step about to start** — before work: `elapsed + SLOWEST_UNIT < WALL`. Checking only `elapsed < BUDGET` starts a 15s call with 5s left and overruns.
4. **Oversized work returns `partial`**, not failure — watermark + later tick. First-class UI state (amber, not red).
5. **`resultOk()` walks the payload** — handler did not throw ≠ success. Distinguish ok / skipped / failed / stalled / partial.

---

## Geography

Use when warm TTFB is high for users far from the app region, or someone proposes moving the database to fix page latency.

1. **Two legs:** user→app and app→DB. Moving the DB closer to the app can punish every user SSR navigation.
2. **Prefer moving the stateless app** when users and DB already share a region — reversible (new app, same repo, env, CNAME flip).
3. **Do not attach sync-loop RTT** (~400ms per serial query) to page p50. Different workloads, one number.
4. **Region moves do not fix pool/statement timeouts** caused by sync saturation.
5. **Re-read infrastructure after anything else touches it:**
   - Env allow-list scripts: copy 17→17; do not "fix" missing keys mid-migration.
   - Prisma CLI reads `.env`, not `.env.local` — `migrate` can silently skip while `generate` succeeds.
   - Console connect can mint new logging roles / wrong-region ARNs; policy fix may need redeploy for STS.

---

## Perceived + mobile web

Use when server duration is fine but the UI feels slow — especially on phones.

**Felt latency (App Router)**

- `loading.tsx` on every route that awaits.
- Static shell for chrome that does not depend on data — finer Suspense so headings do not flash to skeleton.
- Do not re-skeleton filter-independent KPIs when only the list changes.
- Silent refetch after inline edit (no skeleton); filter changes may skeleton.
- Filter state in `useState`, seeded from the URL; mirror with `history.replaceState` so each click is not a Next navigation:

```ts
window.history.replaceState(window.history.state, "", url);
```

- Stale-while-refetch: keep previous results visible and dimmed (`aria-busy` + opacity). Skeleton is for first load only.

**Mobile web / CWV (starting guardrails, not universal pass/fail)**

| Guardrail | Starting target |
| --- | --- |
| Field LCP / INP / CLS | Prefer mobile p75; LCP ≤ 2.5s, INP ≤ 200ms, CLS ≤ 0.1 |
| TTFB | < 800ms |
| JS (compressed) | < 300 KB |
| Total page weight | < 1.5 MB |

- LCP: `next/image` with `priority` / `fetchPriority` on the hero; `next/font`; avoid late-discovered LCP resources.
- INP: avoid a router navigation per filter click; break long tasks; defer third-party (facades).
- CLS: width/height or `aspect-ratio` on images; reserve space for dynamic chrome.
- Long lists: `content-visibility: auto` where appropriate.

If Chrome DevTools MCP is available, prefer a performance trace over vibes; skip recommendations with 0ms estimated impact. For Lighthouse-only deep audits, hand off to sister skills.

---

## React / Next best-of

Use after Phase 0 shows the problem is in the React/Next request path (not jobs/platform). Prefer this short list; for the full rule tree install `vercel-react-best-practices`.

**Waterfalls (critical)**

- Defer `await` into branches where the result is used.
- Parallelize independent work — but when hitting a connection pool, use **bounded** concurrency (Houston override of unbounded `Promise.all`).
- Start promises early in route handlers; await late.
- Suspense / `loading.tsx` to stream slow islands.

**Bundle (critical)**

- No barrel imports for icon/utils mega-packages — import the leaf module.
- `next/dynamic` for heavy client-only UI (editors, charts, PDF).
- Defer analytics / third-party after hydration or behind interaction.

**Server**

- `React.cache()` for per-request dedupe.
- Minimize data passed to client components (serialize less).
- `after()` for non-blocking post-response work when the host supports it.
- Cache with a natural invalidation point (`cacheTag` / app-level tags the sync clears). Do not assume Vercel `maxDuration` / Cache Components behave the same on Amplify or other hosts — verify.

**Images / fonts**

- `next/image` over raw `<img>`; `next/font` over external stylesheet font loads.

Point at `vercel-labs/agent-skills@vercel-react-best-practices` and `vercel-labs/next-skills` for the rest. Do not start here if Phase 0 says the tail is sync jobs.

---

## Silent failures

Highest-value rule: every budget, cap, batch, skip, or cache invents a way to do less work than intended while looking fine.

| Looks fine | Actually |
| --- | --- |
| `withCron` / handler did not throw → `ok: true` | Nested `airtable: { ok: false }` still green |
| Lambda killed mid-run | No `finishedAt` → "running" forever |
| LLM `status === 200` + empty `items` | Truncated tool JSON (`max_tokens`) ≠ quiet week — read `stop_reason` |
| pg_cron `succeeded` | Command was the inspection SQL; no HTTP ever fired |

**Design out successful-looking no-ops:**

- Success = downstream observed the effect (rows written, HTTP called, watermark advanced).
- `resultOk()` walks nested payloads; job states include stalled / partial.
- Assert budgets and concurrency limits with non-vacuous checks.
- After each optimisation, write down the silent-failure mode and the check that fails when it returns.

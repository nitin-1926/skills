# Making a Next.js app fast when the slowness isn't in the code

A field record from Houston — a Next.js 15 App Router CRM on AWS Amplify, Prisma, Supabase
Postgres, ~135k contacts, ~2,900 deals, an LLM extraction pipeline and a nightly sync chain.

Every number here was measured against production. Wrong turns are kept in, because most of what
this taught was learned by being wrong first and the corrections are the useful part.

---

## 0. The shape of the problem

The app was "slow". It was not slow in the way anyone assumed.

Production, `n=1654` requests over 3 days (CloudWatch, Amplify SSR Lambda):

```
Duration    p50 = 38ms    p75 = 256ms    p90 = 2872ms    p95 = 5883ms    p99 = 28003ms
Cold start  6.8% of requests, init p50 1625ms
Errors      2287 statement timeouts (57014) · 807 pool timeouts · 36 lambda timeouts
```

A **p50 of 38 milliseconds**. The median request was already fast, and had been all along. The
entire problem lived in the tail — and the tail was not user page loads at all. It was the sync
jobs saturating the database, in bursts: 1,143 errors in one hour, 1,144 in another, 803 pool
timeouts in a third, and clean quiet hours between them.

**Lesson zero: get the distribution before you optimise anything.** A p50 tells you the app is
fine. A p99 that is 700× the p50 tells you there are two workloads sharing one runtime, and only
one of them is broken. Optimising the median here would have been months of work for nothing.

---

## 1. You cannot fix what you cannot attribute

Amplify's SSR logs carry **no route information**. A `REPORT` line gives duration and memory and
nothing about which page produced it. So every latency claim for weeks was inference.

Two pieces of instrumentation ended that, and both are small:

**A one-line request log in middleware.**

```ts
// middleware.ts — puts the path immediately before the Lambda REPORT line
// in the same log stream, which is the only thing that makes duration attributable.
console.log(`[req] ${request.method} ${pathname}`);
```

**A Prisma slow-query tripwire.**

```ts
prisma.$on("query", (e) => {
  if (e.duration < SLOW_QUERY_MS) return;           // default 300
  console.warn(`[slow-query] ${e.duration}ms ${e.query}`);
  // NEVER e.params — they carry customer emails and land in CloudWatch forever.
});
```

That second comment is not a style note. Query params in this app contain personal data; logging
them to solve a performance problem would have created a compliance problem. There is a test
asserting the tripwire fires *and* leaks no params.

> **For an agent:** before proposing a single optimisation, ask what produced the number. If the
> answer is "inference", the first change is instrumentation, not code.

---

## 2. The big one: serial `await` across a network boundary

This is the single largest category, it appeared five separate times, and it is invisible locally.

The pattern:

```ts
for (const row of rows) {
  await prisma.account.upsert({ ... });   // fine on localhost, fatal across a region
}
```

On a local Postgres that's ~1ms a row. Against a pooled database in another region it is ~400ms
of pure waiting per row, and none of it is CPU. What it produces is not an error — it is a job
that quietly never finishes.

| Where | Before | After |
|---|---|---|
| `normalizeHubspot` — one `await` per record | ~20 deals/run against 978 staged (49 runs to drain) | chunks of 25 in flight |
| `deltaSweep` staging | 500 sequential upserts ≈ 200s of waiting | same chunking |
| `/api/cron/backfill` | **>400s, timing out** | **30–77s** |
| Avoma thread enrichment | 40 serial Slack round trips, route hung past **400s** | 8 in flight, **19s** |
| Account health writes | 90 serial `prisma.account.update` = **25.0s** | bounded concurrency |

### What did NOT work, and why

**`prisma.$transaction([...])` — the first attempt at the health writes.** A batch transaction
makes writes *atomic*. It does not make them *concurrent*. The round trips stayed serial, and the
5-second default transaction timeout then killed long batches outright — strictly worse.

**Unbounded `Promise.all` — the second attempt.** It exhausts the pooled connection and the
database starts returning `Can't reach database server`. Concurrency without a bound is just a
different failure.

**Raising the chunk size by guessing.** Moving from 25→50 in flight and the budget 25s→40s made
the route *hang outright* — past what the connection pool serves. 25 stands because it was
measured, not because it looked reasonable.

The shape that worked:

```ts
// Bounded fan-out. Rejections are counted, not thrown — a row can legitimately
// vanish between the read and the write, and one missing row must not fail the batch.
export async function runConcurrent<T>(tasks: (() => Promise<T>)[], limit = 10) { ... }
```

> **For an agent:** `await` inside a loop over a network resource is a design error, not a style
> preference. Fix it with *bounded* concurrency. Never with a transaction (wrong tool), never with
> unbounded `Promise.all` (moves the failure), never with a guessed limit (measure it).

---

## 3. Do not write what has not changed

`deriveObservations` re-upserted all **2,872** observation rows on every run in order to change the
~45 the latest scan had added. An Observation is a pure function of its ContextFact, and facts are
append-only — so almost every write was rewriting a row to its current value.

Read the current rows once, diff, write the delta: **86.8s → 4.4s**.

### The failed first cut, which is the interesting part

The diff was written with `JSON.stringify(a) === JSON.stringify(b)` and **matched nothing** — it
still wrote all 2,872 rows, and the run got *slower* because it now did a read as well.

Cause: **Postgres `jsonb` does not preserve object key insertion order.** The value round-trips
through the database with its keys reordered, so two semantically identical objects stringify
differently, forever.

```ts
// jsonb DOES preserve array order (the sentiment trend is chronological, and must stay so).
// jsonb does NOT preserve object key order. Compare objects through a key-sorting canonical form.
const canonical = (v: unknown) => JSON.stringify(v, (_, x) =>
  x && typeof x === "object" && !Array.isArray(x)
    ? Object.fromEntries(Object.entries(x).sort(([a], [b]) => a.localeCompare(b)))
    : x);
```

The same pass also found the same 2,872-row query being issued **twice** — `deriveObservations` and
`recomputeBrandIntel` each ran it independently, and the second bought nothing.

> **For an agent:** before adding a diff-before-write, verify the comparison actually returns true
> for unchanged rows. A diff that never matches is strictly worse than no diff. Watch for
> serialisation round-trips that are not order-stable: `jsonb`, `Map`, `Set`, `Date` precision.

---

## 4. Counting is the expensive part of a paginated table

The 134,978-row contact directory was reported as slow. It was **not** over-fetching — it already
paged on the server with filters in SQL and 50–200 rows on the wire. The cost was five parallel
queries, one of which dominated:

```
169ms  count({})                  filtered total
530ms  count({ NOT: INTERNAL })   grand total   <-- unindexable scan of 134,978 rows
164ms  count(INTERNAL)            internal count
219ms  findMany page 0 take 50
172ms  groupBy lifecycleStage
```

Three problems at once:

1. **An unanchored `LIKE` can never use a btree index.** `email LIKE '%@rocketium.com'` seq-scans,
   always. No amount of indexing fixes a leading wildcard.
2. **It ran twice on the landing view** — when internal contacts are hidden, the page's own `where`
   *is* the grand-total filter, so the identical 135k-row scan executed twice for one number.
3. **Two of the three counts are constants.** They do not depend on the search box, the lifecycle
   filter, or the page — yet they were recomputed on every keystroke.

Fix: cache the constants behind a `TAGS.contacts` invalidated by the contacts sync, and reuse the
cached grand total instead of re-running the identical filter. **~900ms → 510ms**, and structurally
three 135k-row scans leave the request path entirely.

### The bug the optimisation uncovered

Checking a shortcut (`grandTotal = all − internal`) surfaced a real correctness bug:

```
all = 134978,  NOT internal = 130095,  internal = 1808,  sum = 131903
```

**3,075 rows were in neither count.** Every contact with a null email. `NULL LIKE '%@x.com'` is
`NULL`, so the OR-group evaluated to `NULL`, and `NOT NULL` is also `NULL` — matching neither side.
Those contacts were absent from the default directory *and* uncounted in "internal hidden". The
null-safe predicate returns **133,170** and costs 14ms more.

Correctness was free, and it was only found because someone tried to make it faster.

**Rejected: a denormalised `isInternal` column.** Same result, but it adds a migration, a 135k-row
backfill, and a field the sync must never forget to set — permanent upkeep for something a cache
with a natural invalidation point already solves. If cache misses later prove costly, a `pg_trgm`
GIN index is the better next step: one migration, no application upkeep, and it also speeds the
search box, which hits the same unindexable `contains`.

> **For an agent:** on a slow paginated table, profile the *counts* before the rows. Ask which
> counts are filter-independent (cache those), whether any predicate has a leading wildcard
> (unindexable), and whether three-valued logic is silently dropping NULL rows from both sides of a
> partition.

---

## 5. Stop shipping the whole dataset to the browser

`/actions` was `force-dynamic`, blocked first paint on two full-table reads, then serialised
**every** merged item into the RSC payload — ~1,300 items, **~1.2 MB** — purely so the browser
could filter them. Rendering had been capped earlier; the payload never had been.

The fix has three parts and the third is the one people skip:

1. **A static shell that awaits nothing.** Heading and chrome paint on the first frame; the queue
   arrives from `GET /api/actions` behind a skeleton. Warm TTFB **617ms → ~20ms**.
2. **Filtering, sorting, counting and paging move server-side.** First payload is one page of 100
   instead of all 1,300.
3. **Search had to move server-side too.** It was local specifically so keystrokes would not
   round-trip. But with only one page in the browser, local search would have silently searched 100
   of 1,300 items. **A wrong answer is worse than a slower one** — it moved to the server with a
   250ms debounce.

That third point generalises: *partial data plus client-side logic equals a confidently wrong
answer.* When you paginate, audit every client-side operation that assumed the full set.

Same lesson elsewhere: board view issues four requests against the *same* endpoint rather than a
bespoke `columns` response, so each column's header count is the server's `total` rather than the
length of a client-side slice — "+N more" is honest about the whole column.

---

## 6. The platform wall you are not told about

Every cron route declared:

```ts
export const maxDuration = 60;   // a Vercel/Next.js knob. Amplify does not honour it.
```

**Amplify Hosting cuts the SSR response at 30 seconds.** Worse than a truncated response: the
Lambda is frozen mid-handler, so the job's `finishedAt` write never lands and the run reads
"running" forever.

The budgets written against the imaginary 60s wall could therefore never fire:

```
Jobs finishing under ~17s:  0 stalls in 124 runs
`daily` (routinely >30s):   29 of its first 30 runs never wrote finishedAt
```

Three rules came out of it:

1. **Every budget derives from one constant** (`PLATFORM_BUDGET_MS`), and a check script asserts
   none exceeds it. Verified non-vacuous: restoring the old 40s value fails two assertions.
2. **Reserve for the step you are about to start.** The check runs *before* the work, so
   `elapsed < BUDGET` is wrong — it must be `elapsed + SLOWEST_UNIT < WALL`. A 40s budget produced
   a 52.5s request precisely because it tested the clock before a ~15s call without reserving.
3. **A job too big for one window returns `partial`, not failure.** Work happened, more remains, a
   later tick resumes from a watermark. `partial` is a first-class state in the UI (amber, not
   red), because a red tick that cries wolf gets ignored.

> **For an agent:** find the *platform's* real limit before tuning timeouts. Framework config
> (`maxDuration`) is a request to the host, not a guarantee. Verify against observed behaviour.

---

## 7. Geography, and why we moved the app rather than the database

Amplify ran in `eu-west-1`. Supabase has always been `ap-south-1`. 99% of users are in India.

There are **two** latency legs: user→app, and app→DB. Moving the database to Ireland fixes leg 2
and leaves every Indian user crossing a continent on every SSR navigation — optimising for the
machines and against the humans. Moving the app fixes both.

The cost asymmetry pointed the same way: an Amplify app is stateless (new app, same repo, re-add
env, flip a CNAME, rollback = flip it back). Relocating Supabase is a data migration with new
connection strings, re-issued keys and real downtime — to buy the worse outcome.

**Result:** `/login` warm TTFB 383–503ms → **151ms**. A/B against the old app on identical code and
database: 263ms → **144ms** median. TLS handshake 78–190ms → **41ms**. Cold start (~2.8–3.1s)
**unchanged**, because that is Lambda init, not geography.

### The claim I had to retract

I justified the move partly with "~400ms per awaited query". That number is real — but it comes
from the *sync loops*, which issue thousands of serial queries. It does not describe page renders,
whose N+1s had already been removed. Production p50 was **38ms** of server compute; the move buys
~120ms on the network leg, and that is close to the whole prize for normal browsing.

Two different workloads, one number, and I attached it to the wrong one.

**The region move also fixed none of the errors.** Same Postgres, same `statement_timeout`, same
pooler — the 2,287 statement timeouts were sync jobs saturating the database and moving compute
does not touch them.

### Three infrastructure traps, in the order they bit

1. **The env allow-list.** A script materialises `.env.production` from an explicit array; the app
   carried 17 vars while the array listed ~30. Copying 17→17 preserves behaviour exactly — the
   temptation to "fix" that during a migration is how you cause an unrelated outage.
2. **The Prisma CLI reads `.env`, not `.env.local`.** `prisma generate` needs no env and succeeded;
   `prisma migrate` needs `DIRECT_URL` and silently failed. The client learned about a column the
   database never got, and every query on that model blew up.
3. **A console click is a write.** Connecting the repo through the console minted a *new* SSR
   logging role and swapped it in — cloning Ireland's hardcoded `eu-west-1` resource ARNs into a
   brand-new `ap-south-1` app. Mumbai wrote no logs at all, silently. Fixing the policy was not
   enough either: Amplify holds STS credentials assumed under the old policy, so it took a redeploy
   to take effect.

> **Lesson:** re-read infrastructure state after anything else touches it.

---

## 8. Perceived performance is a separate discipline

Measured latency and felt latency are different problems, and the second one is often cheaper.

**Route-level boundaries.** Next's `loading.tsx` is the route-level Suspense boundary. Three pages
lacked one and were the actual gap.

**A static shell beats a fast page.** `/today` already had `loading.tsx`; splitting it into a static
shell plus two Suspense boundaries is a *finer* boundary, not an unblocking — the heading stops
flashing to skeleton. Same total time, better experience.

**Do not skeleton what did not change.** When a filter changes, the list skeletons but the KPI tiles
hold their numbers — those counts are filter-independent by design, so re-skeletoning them would be
a lie about what changed.

**Do not blank what the user just edited.** A successful inline edit triggers a *silent* refetch —
no skeleton. Blanking the queue someone just edited is a worse tell than half a second of stale
text. Filter changes do skeleton; edits do not.

**The last mile: stop paying for a navigation per click.** Every filter dropdown routed its value
through `router.replace`, so the select's own displayed choice waited on a Next.js navigation
round-trip. Filter state moved into `useState`, seeded once from the URL so deep links still land
filtered, with the URL kept as a *mirror* written via native `history.replaceState`:

```ts
// Next syncs useSearchParams over a native replaceState, so the address bar stays
// shareable with zero navigations per click.
window.history.replaceState(window.history.state, "", url);
```

While a refetch is in flight the previous results stay visible and dimmed (`aria-busy` + opacity)
rather than flashing to skeleton. The skeleton is for first load only.

> **For an agent:** separate "make it fast" from "make it feel fast". Check `loading.tsx` coverage,
> whether filter state round-trips through the router, whether stale-but-correct data can stay on
> screen during a refetch, and whether anything re-skeletons that did not actually change.

---

## 9. The failure mode that performance work creates

Making things faster made them fail *silently*, twice. This is the part most performance write-ups
omit and it cost more than any of the wins.

**A cron that reported success while doing nothing.** `withCron` stamped `ok = true` whenever the
handler did not throw. A `sync` whose own payload said `airtable: {ok:false}` displayed green. A
Lambda killed mid-run never writes `finishedAt`, so it read "running" forever. Fix: `resultOk()`
walks the payload, and `jobState()` distinguishes ok / skipped / failed / stalled / partial.

**An LLM call that returned success with no data.** All four extraction scanners shared:

```ts
if (r.status !== 200) return [];
return toolInputFrom(r.json, "log_x")?.items ?? [];
```

which reports "found nothing" for *every* failure. The dangerous one answers **HTTP 200**: when the
model hits `max_tokens` mid-tool-call the JSON is cut, the parse yields nothing, and a truncated
run is indistinguishable from a quiet week. The call-corpus scan sat like that — **~57s of model
time per chunk, zero commitments written, logged as ok** — until `stop_reason` was actually read.

**A scheduler whose command was the wrong SQL.** The nightly drain job showed `active=true`, the
right cadence, and an unbroken run of `succeeded` rows. Its command was:

```sql
select command from cron.job where jobname = 'houston-daily-drain'
```

— the *inspection query*, pasted in as the command. It ran every five minutes, returned one row, and
pg_cron recorded `succeeded`, because from pg_cron's side nothing had failed. **No HTTP request was
ever made.** Seven of nine sync steps did not run for six days while the admin page showed green.

> **For an agent, and this is the highest-value rule in this document:** every performance change
> that adds a budget, a cap, a batch, a skip or a cache creates a new way to do less work than
> intended. Ask what a *successful-looking* failure would look like, and make it impossible to
> report success while producing nothing. `status === 200` is not success. `no exception` is not
> success. `succeeded` is not success. Only "the thing downstream observed the effect" is success.

---

## 10. Distilled rules

Ordered by how much they paid.

1. **Measure the distribution, not the average.** p50/p90/p99. A 38ms median with a 28s p99 is two
   workloads, not one slow app.
2. **Make latency attributable before optimising.** Request-path logging plus a slow-query
   tripwire. Never log query params.
3. **Never `await` in a loop over a network resource.** Bounded concurrency. Not a transaction, not
   unbounded `Promise.all`, not a guessed limit.
4. **Diff before write — then verify the diff matches.** Serialisation round-trips are not
   order-stable (`jsonb` reorders object keys).
5. **Profile counts before rows on paginated tables.** Cache filter-independent counts. Leading
   wildcards are unindexable. Watch NULL falling out of both sides of a partition.
6. **Paginate the payload, and audit every client-side operation that assumed the full set.**
   Partial data plus client logic equals a confident wrong answer.
7. **Find the platform's real limit.** Framework config is a request, not a guarantee. Derive every
   budget from one constant and assert it. Reserve for the step you are about to start.
8. **Long work returns `partial` and resumes from a watermark.** Give it a first-class UI state.
9. **Move compute to the data, or the data to the users — count both latency legs** and prefer the
   reversible change.
10. **Perceived performance is separate work.** Route boundaries, static shells, stale-while-
    refetching, and never re-skeleton what did not change.
11. **Every optimisation invents a new silent failure.** Design the "it did nothing but looks fine"
    case out, and leave a check behind that fails when it returns.

---

## 11. Checklist

**Before**
- [ ] p50/p90/p99, and how many requests
- [ ] Can a slow request be attributed to a route? If not, instrument first
- [ ] Is the tail user traffic, or background jobs sharing the runtime?
- [ ] What is the platform's real response/execution limit — observed, not documented?

**Server**
- [ ] No `await` inside a loop over DB/HTTP; bounded concurrency with a measured limit
- [ ] No repeated identical query within one request path
- [ ] Writes diffed against current state, and the diff verified to match on unchanged rows
- [ ] Counts on paginated tables: which are filter-independent? cache those
- [ ] Any leading-wildcard `LIKE`? It will never use a btree
- [ ] Nullable columns in a partition predicate — does NULL fall out of both sides?

**Payload**
- [ ] Is the whole dataset being serialised so the client can filter it?
- [ ] After paginating, does any client-side search/count/sort still assume the full set?

**Background work**
- [ ] Every budget derived from one constant, asserted by a check
- [ ] Budget reserves for the step about to start, not just for elapsed time
- [ ] Oversized work returns `partial` + watermark, and the UI has a state for it
- [ ] Does a no-op run look different from a successful one?

**Perceived**
- [ ] `loading.tsx` on every route that awaits
- [ ] Static shell for pages whose chrome does not depend on data
- [ ] Filter state avoids a router navigation per click
- [ ] Stale data stays visible while refetching; nothing re-skeletons that did not change

**After**
- [ ] Numbers before and after, from the same environment
- [ ] A check that fails if the regression returns
- [ ] What new silent-failure mode did this create, and what catches it?

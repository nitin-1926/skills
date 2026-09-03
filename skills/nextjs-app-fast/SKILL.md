---
name: nextjs-app-fast
description: Diagnoses and fixes Next.js App Router performance when the slowness is or isn't in the React — distribution-first measurement, latency attribution, bounded concurrency, payload pagination, platform walls, geography, perceived performance, and silent-failure design. Use when the app is slow, p99/timeouts spike, cron/sync jobs hang, a directory or table feels slow, TTFB is high, Core Web Vitals or Lighthouse fail, or the stack is Amplify/Vercel/serverless with Prisma/Postgres.
metadata:
  author: nitin-1926
  version: "1.0.0"
---

# Next.js App-Fast

## Purpose

Make a Next.js App Router app fast. Assume the slowness may not live in the component tree: it is often a fat tail of background jobs, an unattributable host log, a serial `await` across a region, a full-table count, a megabyte RSC payload, a platform kill the framework config lied about, or a silent "green but did nothing" after an earlier speedup.

The measured field record behind these rules is in [references/field-record.md](references/field-record.md). How to execute each class of fix is in [references/playbooks.md](references/playbooks.md).

## When to use

- "The app is slow" / "pages feel laggy" / high TTFB
- p90/p99 dwarfs p50; Lambda/SSR timeouts; pool or statement timeouts
- Cron, sync, or LLM pipeline routes hang or stall as "running"
- Paginated directory/table is slow despite small page sizes
- Core Web Vitals / Lighthouse / "feels slow on mobile"
- Amplify, Vercel, or other serverless + Prisma / Postgres

**Out of scope:** React Native / Expo — hand off to `callstackincubator/agent-skills@react-native-best-practices`. "Mobile" here means Next.js on phones (mobile CWV, INP, mid-tier CPU).

## Hard rules

1. **Measure the distribution, not the average.** p50/p90/p99 and n. A 38ms median with a 28s p99 is two workloads, not one slow app.
2. **Make latency attributable before optimising.** If the answer to "what produced this number?" is inference, instrument first: request-path logging plus a slow-query tripwire. Never log query params.
3. **Never `await` in a loop over a network resource.** Bounded concurrency. Not a transaction (wrong tool), not unbounded `Promise.all` (moves the failure), not a guessed limit (measure it).
4. **Diff before write — then verify the diff matches.** Serialisation round-trips are not order-stable (`jsonb` reorders object keys). A diff that never matches is strictly worse than no diff.
5. **Profile counts before rows on paginated tables.** Cache filter-independent counts. Leading-wildcard `LIKE` is unindexable. Watch NULL falling out of both sides of a partition.
6. **Paginate the payload, and audit every client-side operation that assumed the full set.** Partial data plus client logic equals a confidently wrong answer. A wrong answer is worse than a slower one.
7. **Find the platform's real limit.** Framework config (`maxDuration`) is a request to the host, not a guarantee. Verify against observed behaviour. Derive every budget from one constant and assert it. Reserve for the step you are about to start.
8. **Long work returns `partial` and resumes from a watermark.** Give it a first-class UI state (amber, not red).
9. **Move compute to the data, or the data to the users — count both latency legs** (user→app and app→DB) and prefer the reversible change.
10. **Perceived performance is separate work.** Route boundaries, static shells, stale-while-refetching, and never re-skeleton what did not change.
11. **Every optimisation invents a new silent failure.** Design the "it did nothing but looks fine" case out. `status === 200` is not success. `no exception` is not success. `succeeded` is not success. Only "the thing downstream observed the effect" is success.

## Workflow

Do not propose a code optimisation until Phase 0 has numbers. One playbook at a time, highest leverage first. Do not start with `memo` / `useMemo` or a denormalised column.

```
App-Fast Progress:
- [ ] Phase 0: Diagnose (distribution, attribution, tail owner, platform wall, geography)
- [ ] Phase 1: Classify (user vs jobs vs perceived; pick one playbook)
- [ ] Phase 2: Playbook (see references/playbooks.md)
- [ ] Phase 3: Verify (same-env before/after, regression check, silent-failure design)
```

### Phase 0 — Diagnose

1. p50 / p90 / p99, and how many requests (same environment you will compare against).
2. Can a slow request be attributed to a route? If not → Instrument playbook first.
3. Is the tail user traffic, or background jobs sharing the runtime?
4. What is the platform's real response/execution limit — observed, not documented?
5. Both geography legs: user→app and app→DB.
6. If the complaint is "feels slow", gather mobile CWV / INP as well as server duration. Measure before recommending; skip 0ms "issues"; quantify.

### Phase 1 — Classify

| Signal | Likely class | Playbook |
| --- | --- | --- |
| Fast p50, huge p99; errors in bursts | Background jobs saturating DB/runtime | Bounded fan-out, Jobs/platform |
| Slow request, no route in logs | Unattributable latency | Instrument |
| Serial `await` over DB/HTTP in a loop | Network-bound fan-out | Bounded fan-out |
| Paginated table slow; small `take` | Counts / predicates | Paginated tables |
| Large RSC payload; client filters full set | Over-serialisation | Payload |
| Cron past host kill; `finishedAt` missing | Platform wall | Jobs/platform |
| Warm TTFB high; users far from app region | Geography | Geography |
| Server fast; UI flashes / waits on router | Perceived / mobile web | Perceived + mobile web |
| Waterfalls, fat bundles, heavy client | React/Next code | React/Next best-of |

### Phase 2 — Playbook

Follow the matching section in [references/playbooks.md](references/playbooks.md). Prefer the reversible, measured fix. Reject unbounded concurrency and guessed limits.

### Phase 3 — After

1. Numbers before and after, from the same environment.
2. A check that fails if the regression returns.
3. What new silent-failure mode did this create, and what catches it?

## Checklist

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

## Distilled rules (leverage order)

1. Measure the distribution, not the average.
2. Make latency attributable before optimising.
3. Never `await` in a loop over a network resource — bounded concurrency.
4. Diff before write — then verify the diff matches.
5. Profile counts before rows on paginated tables.
6. Paginate the payload; audit client ops that assumed the full set.
7. Find the platform's real limit; one budget constant; reserve for the next step.
8. Long work returns `partial` + watermark with a UI state.
9. Count both latency legs; prefer the reversible move.
10. Perceived performance is separate work.
11. Every optimisation invents a silent failure — design it out.

## Sister skills

Install these when the complaint is narrower; do not duplicate their trees here.

| Skill | Use when | Install |
| --- | --- | --- |
| `vercel-react-best-practices` | Waterfalls, bundles, re-renders, RSC serialization detail | `npx skills add vercel-labs/agent-skills@vercel-react-best-practices` |
| `next-best-practices` | App Router conventions, Suspense, image/font, data patterns | `npx skills add vercel-labs/next-skills` |
| `core-web-vitals` / `performance` (Addy Osmani) | Lighthouse / field LCP·INP·CLS only | `npx skills add addyosmani/web-quality-skills` |
| `web-perf` | Chrome DevTools MCP trace workflow | (local / agent-skills install of web-perf) |
| `react-native-best-practices` | Native mobile, not Next.js on phones | `npx skills add callstackincubator/agent-skills@react-native-best-practices` |

## Additional resources

- Field record (measured case study): [references/field-record.md](references/field-record.md)
- Playbooks (how to fix each class): [references/playbooks.md](references/playbooks.md)

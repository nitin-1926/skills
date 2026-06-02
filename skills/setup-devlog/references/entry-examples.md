# Entry examples

Four sample entries showing the _why_-not-_what_ style. Use these as calibration when writing real entries — read them, then write yours, then re-read these to check if yours captures decision and tradeoff or just diff narration.

---

## Example 1 — Bug fix

### 2026-02-03 — Auth middleware was rejecting valid JWTs after server restart

- Type: bug
- Scope: `middleware/auth.go`, `middleware/auth_test.go`

Reasoning / RCA / research: - First-pass diagnosis blamed clock skew (auth times-out look like
skew). Disproved by replicating with system clock pinned via
`faketime` — still failed. - Real cause: middleware lazy-loaded the JWT signing key on first
request and cached it forever. After a key rotation, the middleware
kept the old key in memory across the restart of _clients_, but
had stale cache only for the duration of the _server process_ —
diagnosed by realizing the bug only happened when N>1 clients hit
the server within a 10-min window after rotation. - Considered: invalidate cache on every Nth request. Rejected — same
class of bug, just rarer. Right fix: tie cache lifetime to the
key's `kid` claim and refetch on `kid` mismatch.

Implementation summary: - Cache keyed by `kid` instead of singleton; refetch on mismatch - Added test that simulates rotation mid-flight (two valid keys
visible from JWKS endpoint, request signed by the newer one) - Removed the old fixed 1-hour TTL — `kid`-driven invalidation
replaces the time-based fallback

Follow-ups deferred: - JWKS endpoint failure handling — current code falls back to cached
keys silently. Acceptable now; revisit when we add more issuers.

---

## Example 2 — Feature with rejected alternatives

### 2026-02-08 — Switched ingest pipeline from BullMQ to Temporal

- Type: feature
- Scope: `ingest/`, `worker/`, `package.json`, ops runbook

Reasoning / RCA / research: - BullMQ served us until cron-style schedules and retry-with-state
both became first-class needs. Hacking each into BullMQ was
possible (Bull-Board, manual retry maps) but every workaround
built more glue. - Evaluated: Inngest, AWS Step Functions, Temporal. Inngest was
lighter but locks us to their cloud — not acceptable for ingest
data. Step Functions priced poorly for our 50M/day step volume.
Temporal won on (a) self-hostable, (b) state-machine model maps
directly to our retry logic, (c) the Go SDK matched the rest of
the worker stack. - Tradeoff accepted: Temporal's operational footprint (Cassandra
or RDS, plus cluster) is heavier than BullMQ's Redis. We hold
this cost in exchange for not writing two more years of
"BullMQ + bespoke state" patches.

Implementation summary: - Single ingest workflow + 4 activities replaced 12 BullMQ queues - `worker/temporal.go` is the only new entry point; old BullMQ
worker boots are gone - Migrated 4 cron jobs to Temporal scheduled workflows - Net: -2,800 lines including tests; +900 lines workflow code

Follow-ups deferred: - Temporal Cloud vs self-host — running self-hosted on staging for
8 weeks before deciding - Old BullMQ Redis cluster: drained, kept for 30 days before
decommission in case we need to replay

---

## Example 3 — Refactor with shape change

### 2026-02-14 — Extracted `Reservation` from `Booking` after `Booking` started leaking into 6 unrelated services

- Type: refactor
- Scope: `domain/booking/`, `domain/reservation/`, services touching either

Reasoning / RCA / research: - `Booking` had grown into a god-object: payment status, guest
info, room assignment, cleaning schedule, and reservation state
all on the same struct. Six services touched it; each used 10-20%
of the fields. Adding any field cascaded through every service. - Trigger: a 4-line PR adding a `cleaning_window` field broke 3
services' tests because they validated `Booking` as a whole. - Considered: just add JSON tags to mark optional fields. Rejected —
treats the symptom. The aggregate boundary was wrong; a Reservation
(room slot + dates) is independent of a Booking (commercial
transaction wrapping zero or more reservations). - Decision: split. Booking now references Reservation by ID. Most
services drop their Booking dependency entirely.

Implementation summary: - New `domain/reservation/` with `Reservation` aggregate and its
own repository - Booking holds `ReservationIDs []ReservationID`; old fields
removed - 4 of 6 dependent services now import `domain/reservation` only - Migration: 12-line SQL to backfill the join table from existing
Booking rows. Ran in <1s on prod.

Follow-ups deferred: - Cleaning service still uses Booking — its scheduling rules are
genuinely commercial-transaction-aware. Leave alone for now.

---

## Example 4 — Failed approach worth recording

### 2026-02-21 — Tried React Server Actions for the upload flow; reverted

- Type: feature
- Scope: `app/upload/`, `app/upload/upload-button.tsx`, infra notes

Reasoning / RCA / research: - Started swapping the upload flow to Server Actions to drop the
`/api/upload` route. Worked locally. Failed on Vercel preview
because Server Actions don't stream multipart bodies — they
expect `FormData` resolved in memory. - Our uploads are 50MB-2GB video. Buffering in memory crashed the
function (1GB limit on the Pro plan). Streaming via the old
route handler with `request.body` worked fine. - Considered: chunked client-side upload then server-action
assembly. Rejected — adds two round-trips and we'd need to
handle resume anyway. - Rolled back. Kept the existing `/api/upload` route. Recorded the
tradeoff so the next person doesn't repeat the experiment.

Implementation summary: - Reverted commits 4f3a..7b2c - Added a comment in `app/upload/upload-button.tsx` pointing here - No code change beyond the revert

Follow-ups deferred: - When Vercel adds streaming Server Actions (announced for 2026
H2), revisit this entry and re-evaluate

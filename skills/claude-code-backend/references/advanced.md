# Advanced Layers (opt-in)

The core spine (invariants 1–8) runs a single agent on demand and lands validated state. These layers turn it into the full gold standard. **Add them only when the use case demands** — each is real complexity. Pick à la carte.

## Scheduling (cron)

Run agents on a cadence without a person clicking a button.

- A **table-driven scheduler**, not hardcoded crontab: a `cron_jobs` table (`cron_expr`, `timezone`, `enabled`, `last_fired_at`, `target`). One daemon polls it.
- **Poll, don't trust timers.** Nexus uses a 60 s poll loop computing "is the most recent scheduled occurrence newer than `last_fired_at`?" rather than node-cron, whose timer drift silently skipped executions. A `LOOKBACK_MS` bounds catch-up after an outage.
- **Jitter + overlap guard:** add ±N s jitter so co-scheduled jobs don't thunder; keep a per-job in-flight set so a slow run doesn't double-fire.
- **One dispatcher for cron and manual.** The "Run now" button and the daemon call the *same* dispatch function → identical runs. This is the single most important scheduling invariant.

## Workflow DAG handoff

Chain agents into a pipeline (strategist → writer → reviewer).

- A `workflows` table holds the DAG as JSON: `nodes` with `id`, `agent`, `depends_on`. Runtime state in `workflow_runs` + `workflow_step_runs`.
- When a step completes, the engine queues nodes whose `depends_on` are all done; **predecessor outputs are concatenated into the next agent's task** (use the *typed rows*, not chat text — see [state-and-output.md](state-and-output.md)).
- Node types beyond `agent`: `approval` (parks for a human), `channel` (Slack/email send), `connector`/`mcp` (attach-only — modify an adjacent agent's capabilities), `input` (trigger-time form fields surfaced to downstream agents).
- **An agent is a 1-node workflow** — model standalone runs and pipelines uniformly so there's one execution path.
- Retry lives here (invariant 7): `retryAgentStep` re-dispatches with the prior error appended, capped at `retry_max`, skipping permanent failures.

## Review / approval gate (invariant 9)

Keep a human between generation and anything irreversible.

- Outputs are **drafts with a status** (`draft → review → approved/rejected/revision_needed`). Nothing an agent writes is "live".
- A **reviewer agent** (nexus's Brand Guardian) checks every draft first, writing a review record and flipping status; *then* a human approves in the UI.
- Rejected drafts can route to an **auto-fix** flow (`fix.sh` → `status=fixing` → back through review).
- **No agent ever publishes/sends/spends.** The final irreversible step is a human action. This is a hard rule, not a preference.

## Learning loop (compounding)

Make the system get better from human feedback.

- **Capture** every human judgment (approve/reject/edit/comment) as append-only `learning_events` (DB triggers + an events endpoint).
- **Distill:** a Distiller agent turns recurring patterns into `learned_rules` (behavioral corrections) and skill candidates.
- **Inject:** the harness pulls active rules into every agent's prompt (the "learned rules" layer in [agent-contract.md](agent-contract.md)) so corrections auto-apply. Keep a per-rule kill switch and make rules visible.
- Skill proposals stay **human-gated** (applied only after approval) — the loop suggests, a person commits.

## Multi-tenant workspaces

Serve several teams/functions from one runtime.

- A `workspaces` table is the tenant boundary; every operational row carries `workspace_id`; every query filters on it (an unfiltered query is a tenant-isolation bug).
- Per-tenant data dir (`$DATA_ROOT/<slug>/`), per-tenant prompt layer, per-tenant connectors.
- Resolve the tenant once (env `WORKSPACE_SLUG`/`_ID`) and thread it through spawn → harness → persist (where it's auto-stamped).

## Dashboard

A UI to trigger, observe, and approve.

- Reads run state from the run-tracking rows; triggers via the same authenticated dispatcher; tails logs (SSE/log-tail endpoints on the runner).
- Hosts the approval queue, the workflow graph view, and the learning-rules kill switches.
- Keep it a *client* of the runner + datastore — it never spawns the CLI itself (except a dedicated edit/chat surface that streams `--output-format stream-json`).

## Chat / streaming surface

When you need interactive, streamed responses (not batch):

- Spawn `claude -p --output-format stream-json --verbose --include-partial-messages`, parse the event lines (`content_block_delta`/`tool_use`/`tool_result`/`result.is_error`), re-emit as SSE.
- Hardcode this surface's tool + model allowlists (don't take them from the request) to block arg injection.

---

**Sequencing advice:** ship the core spine first and run *one* agent end-to-end. Then add the review gate (cheap, high value), then scheduling, then the DAG, then the learning loop and dashboard. Don't build the DAG engine before you have two agents that actually hand off.

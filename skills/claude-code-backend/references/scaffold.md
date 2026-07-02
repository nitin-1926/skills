# Scaffold Procedure

How the router's `scaffold` path turns the invariants into files in the target project. Detect → map → generate (in dependency order) → verify. **No source is written before the user approves the plan.**

## 1. Detect the stack

Read the repo before proposing anything. Establish:

| Question | Why it matters |
|----------|----------------|
| Language / runtime? | The runner + harness are written in it (TS/Node, Python, Go, bash…). |
| Web framework? | The trigger endpoint slots into the existing app (Express/Next route/FastAPI/…) — don't add a second server if one exists. |
| Datastore? | Where run rows + business state + the registry live (Postgres, SQLite, Mongo, even files for a prototype). |
| Host / deploy? | Where the CLI is installed and credentials persist (container, VM, serverless — note: serverless cold-spawn + timeouts fight this pattern). |
| Existing auth/secrets? | Reuse the secret store; pick the trigger-auth mechanism. |
| Scheduler present? | If they already have one, drive it; else the poll-daemon pattern. |
| Is `claude` installed + authed here? | Blocks everything — smoke-test first (below). |

Confirm the use case actually fits the pattern (see SKILL.md "When this pattern fits"). If it doesn't, say so instead of scaffolding.

## 2. Map invariants → concrete files

Produce a table the user approves. Example shape (adapt names to the stack):

| Invariant | Concrete artifact in this project |
|-----------|-----------------------------------|
| 1 CLI-as-backend | `lib/agents/invoke.ts` — `spawn("claude", ["-p", …])`, prompt on stdin |
| 2 Dumb spawner | `POST /api/agents/:slug/trigger` route + `attachWatchdog` |
| 3 Layered prompt | `lib/agents/harness.ts::assemblePrompt()` |
| 4 Capabilities | `lib/agents/capabilities.ts` + `agent_grants` rows |
| 5 Proposes/disposes | `lib/agents/persist.ts` + `schema/*.json`; agents write `pending/<run>.json` |
| 6 Run rows | `agent_runs` table + open/patch helpers |
| 7 Retry/dispatch | `lib/agents/dispatch.ts` (shared by manual + scheduled) |
| 8 Auth | env: `ANTHROPIC_API_KEY` *or* persisted `~/.claude`; `HOME` forced in spawn |
| Agent #1 | `agents/<slug>/SKILL.md` + a registry row |

Then list the **advanced layers** chosen (default: none beyond the review gate) per [advanced.md](advanced.md).

## 3. Generate in dependency order

Build bottom-up so each step is testable before the next:

```
Scaffold order:
- [ ] 0. Smoke test: `echo "Reply: ok" | claude -p --allowedTools ""` succeeds in this env
- [ ] 1. Auth + env: credentials reachable by a spawned process (HOME, secret store)
- [ ] 2. Invoke wrapper: one function that spawns claude -p with prompt on stdin + watchdog
- [ ] 3. Run rows + persist path: open/patch run; validated, id-stamping single write path
- [ ] 4. Harness: layered prompt assembly + the 12-step ceremony
- [ ] 5. Capabilities resolver: per-agent allowlist → tools/MCP/skills
- [ ] 6. Trigger endpoint: secret-authed, spawns via the harness, returns the run id
- [ ] 7. First agent: a real <slug>/SKILL.md + registry row that produces one output
- [ ] 8. (chosen advanced layers, in the order advanced.md recommends)
```

Match the **existing project's** conventions (style, dir layout, config) — this is surgical addition, not a parallel framework. Reuse their datastore client, their config loader, their server.

## 4. Verify (don't declare done without this)

- **Smoke test passed** (step 0) — the CLI actually runs and authenticates here.
- **One real end-to-end run:** trigger the first agent; confirm a run row opens `running` and patches `completed`, and that **real validated state landed** through the persist path (not just stdout).
- **Failure path:** force an error (bad task / revoked tool) and confirm the run patches `failed` with an error message — not a silent hang.
- **Watchdog:** confirm a deliberately-stuck run is killed at the timeout.
- **Auth boundary:** the trigger endpoint rejects a missing/wrong secret.

## Anti-patterns (call these out if you see them)

- **Calling the Anthropic SDK on the worker path** — that's not this pattern; either commit to the CLI or use the API directly, not a confused hybrid.
- **Letting the model write the datastore** — re-route through the persist path.
- **Fire-and-forget with no run row** — failures vanish.
- **No watchdog** — one hung call wedges the worker.
- **Unauthenticated trigger endpoint** — remote code execution by proxy.
- **`--dangerously-skip-permissions` on a server** without written justification.
- **Building the DAG/learning/dashboard before one agent runs end-to-end** — sequence it (advanced.md).
- **Serverless with hard short timeouts** for minutes-long agent runs — flag the mismatch; suggest a queue/worker host.

## Output of the scaffold path

A working core spine + one agent that runs, the mapping table (so the user knows what was added and where), and a short README section documenting: how to add an agent, the env vars, and how to trigger a run.

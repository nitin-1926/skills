# The Portable Invariants

What makes the rocketium-nexus architecture a gold standard, stated so it survives a change of language, datastore, framework, or host. Each invariant is *why it matters* + *the nexus reference* + *how to adapt it*. The concrete how-to for each lives in the linked reference file.

## 1. CLI-as-backend, not SDK

**Why:** spawning `claude -p` (headless/print) gives you the full agent — tool use (Read/Write/Bash/WebSearch/Glob/Grep), MCP servers, Skills, and multi-step reasoning — with no agent loop to build or maintain. Your code shrinks to a deterministic shell around the process. The nexus rule: *no Anthropic API SDK is ever called on the worker path.*

**Nexus:** the prompt is piped to `claude -p --model … --allowedTools …` via **stdin**; output is `tee`'d to a log. See [cli-invocation.md](cli-invocation.md).

**Adapt:** any language can spawn a subprocess and write its stdin. Keep the invocation in one place.

## 2. The server is a dumb spawner

**Why:** keeping intelligence out of the HTTP layer makes the runtime trivially portable and restart-safe. The server authenticates, spawns, and returns; it does not reason. A **watchdog** guarantees a hung model can't wedge the box.

**Nexus:** `deploy/server.js` (prod) and `runner/local-runner.mjs` (dev) are deliberate functional mirrors (same trigger contract; they differ only where they must — module system, and `detached`/kill strategy for the macOS Keychain) — a secret-authed `POST /trigger/:agent` spawns `bash run.sh` and returns 200; a watchdog SIGTERM/SIGKILLs the process *group* after a timeout. See [runner.md](runner.md).

**Adapt:** prod and local should be the *same* server shape so there's no scheduler/trigger skew between environments.

## 3. One layered system prompt, assembled deterministically

**Why:** an agent's behavior is the sum of universal rules + tenant rules + live config + learned corrections + its own role. Assembling these in a fixed order, in one harness, means every agent is consistent and changes propagate everywhere at once.

**Nexus:** `_nexus_load_prompts` concatenates, in order: universal `SHARED_PROMPT.md` → `workspaces/<slug>/PROMPT.md` → live DB config block → injected learned rules → the agent's frontmatter digest → the agent's body, then appends the task and pipes to stdin. See [agent-contract.md](agent-contract.md).

**Adapt:** the layers are the point, not the filenames. Drop layers you don't need (most apps start with universal + agent + task).

## 4. Deny-by-default capabilities, resolved per run

**Why:** a server-side agent with unrestricted tools is a liability. Grant the minimum tool set, MCP servers, and skills *per agent, per run*, from explicit records — never a blanket allow.

**Nexus:** `resolve_capabilities.py` reads enabled tool grants / MCP assignments / skill assignments from the DB and emits `--allowedTools`, an `--mcp-config` file, and mounted skill dirs. Anything ungranted is simply absent from the CLI flags. See [capabilities.md](capabilities.md).

**Adapt:** the registry can be a DB table, a config file, or per-agent metadata — the invariant is *explicit allowlist, resolved at spawn time*.

## 5. Model proposes, deterministic code disposes

**Why:** this is the highest-leverage invariant. The model **cannot be trusted to write your source of truth** — it can hallucinate success. So it never touches the datastore. It writes a structured file; a deterministic step validates that file against a schema, stamps the tenant/run ids the model can't forge, writes through the single persist path, and reports exactly what landed. A fabricated "I saved it" is structurally impossible — only physically-written rows count.

**Nexus:** the model writes a JSON file; `persist.py` validates against `persist_schema.json`, auto-stamps `workspace_id` + `workflow_run_id`, writes via PostgREST, and prints `{inserted, deduped, failed}`. Unparseable final line → hard failure, not a silent skip. See [state-and-output.md](state-and-output.md).

**Adapt:** keep one write path. The model's output is a *proposal artifact*, never a direct mutation.

## 6. Every run is a tracked row

**Why:** observability, idempotency, and a place to hang status/logs/errors. Without it, fire-and-forget spawns silently fail and you can't tell a finished run from a lost one.

**Nexus:** the harness inserts an `agent_runs` row at `status=running` (capturing the id), then patches it to `completed`/`failed` with `completed_at` + `error_message`. Empty id → loud warning (the run would be invisible). See [state-and-output.md](state-and-output.md).

**Adapt:** any store works; the lifecycle (open running → patch terminal) is the invariant.

## 7. Retry and locking live above the worker

**Why:** a worker that retries itself can retry-storm a failing dependency. Lift retry/backoff/overlap-control into the orchestrator, which has the context to tell a transient failure from a permanent one and to append the prior error so the agent self-corrects.

**Nexus:** retry moved out of the shell into the workflow engine (`retryAgentStep`, up to `retry_max`, error text appended to the next task); permanent failures (auth/schema) escalate immediately. The only shell-level retry is `finish.sh` posting step-completion (5 attempts) so a lost callback can't orphan a step. See [runner.md](runner.md).

**Adapt:** even without a DAG engine, put retry in the dispatcher, not the agent. Never retry on auth/permission/schema errors.

## 8. Auth is the CLI's own login

**Why:** the `claude` CLI authenticates itself — it does not need your code to hold a key. A persisted login (a Claude subscription via OAuth) or an env token is all the subprocess needs, as long as it can find the credentials.

**Nexus:** uses a **persisted OAuth login**, not an API key — `~/.claude` + `~/.claude.json` are symlinked onto a Fly volume in the Dockerfile and `HOME=/root` is forced into every spawn so the subprocess finds them. (Portable alternatives: `ANTHROPIC_API_KEY` or `CLAUDE_CODE_OAUTH_TOKEN` as env.) See [cli-invocation.md](cli-invocation.md).

**Adapt:** pick one auth source, persist it across deploys, and ensure the spawned process's `HOME`/env can reach it.

## 9. A human gate before anything irreversible

**Why:** autonomous agents should generate, not act irreversibly. A review/approval step between generation and any publish/send/spend keeps a human in the loop and a bad run recoverable.

**Nexus:** every draft is reviewed by a Brand-Guardian agent, then a human approves in the dashboard; **no agent ever publishes** — a human runs the final step. See [advanced.md](advanced.md).

**Adapt:** at minimum, outputs are drafts with a status; promotion to "live" is a distinct, gated action.

---

**Core vs advanced.** Invariants 1–8 are the mandatory spine every implementation needs. Invariant 9 and the scheduling / DAG-handoff / learning-loop / multi-tenant / dashboard layers are opt-in — start minimal, add them when the use case demands. See [advanced.md](advanced.md).

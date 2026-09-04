---
name: claude-code-backend
description: "Wire Claude Code (the `claude` CLI) into an app as an agentic backend — spawn `claude -p` as a headless worker per task instead of calling an LLM API directly. Routes explain → plan → scaffold: distills the portable gold-standard invariants from the rocketium-nexus architecture (a dumb HTTP spawner + watchdog, a deterministically layered system prompt, deny-by-default tools/MCP/skills, a model-proposes/code-disposes write path, run-tracking rows, retry-above-the-worker, and CLI-login auth), detects the target project's stack, then scaffolds a minimal core spine with opt-in advanced layers (cron scheduling, workflow DAG handoff, review/approval gate, a learning loop, and a dashboard). Use when the user wants Claude Code as a backend, an agent runtime, to run the claude CLI server-side per request, to build an autonomous agent/ops platform, or to add claude-code-as-a-backend to an app instead of normal API configuration."
metadata:
  author: nitin-1926
  version: "1.0.0"
  reference_architecture: rocketium-nexus
---

# Claude Code as a Backend

## Purpose

Stand up an architecture where the **`claude` CLI is your backend worker** — spawned headless (`claude -p`) once per task — instead of calling an LLM API with a hand-built prompt+tools loop. You get tools (Read/Write/Bash/WebSearch/MCP/Skills), multi-step agentic behavior, and permission scoping for free; your code becomes a thin, deterministic shell around it.

The gold standard is **rocketium-nexus**: a pool of bash-shelled Claude agents on cron, each producing work products routed through a review gate before human approval. This skill distills that into **portable invariants** and maps them onto whatever stack the target project already uses.

## When this pattern fits (and when it doesn't)

**Fits:** multi-step work that benefits from tools and filesystem/shell/MCP access; back-office/ops automation on a cadence; tasks where "an agent that can read, search, run, and write" beats a single prompt; you want one runtime for many specialized agents.

**Doesn't:** a low-latency synchronous request path (CLI spawn is hundreds of ms+ and runs seconds–minutes); a pure single-shot completion with no tools (use the API directly); anything needing tight token-level streaming control where the API SDK is simpler. Say so plainly if the user's case is one of these.

## The portable invariants (the spine)

These hold regardless of language, datastore, or host. Full detail in [references/invariants.md](references/invariants.md).

| # | Invariant | Reference |
|---|-----------|-----------|
| 1 | **CLI-as-backend, not SDK** — spawn `claude -p`, pipe the prompt via stdin | [cli-invocation.md](references/cli-invocation.md) |
| 2 | **The server is a dumb spawner** — thin secret-authed trigger, spawn + return, watchdog kills runaways | [runner.md](references/runner.md) |
| 3 | **One layered system prompt, assembled deterministically** — universal → tenant → config → learned rules → agent → task | [agent-contract.md](references/agent-contract.md) |
| 4 | **Deny-by-default capabilities, resolved per run** — `--allowedTools`, `--mcp-config`, skills mounted on demand | [capabilities.md](references/capabilities.md) |
| 5 | **Model proposes, deterministic code disposes** — the model writes a file; a validating, tenant-stamping step is the only write path | [state-and-output.md](references/state-and-output.md) |
| 6 | **Every run is a tracked row** — open `running` at start, patch `completed`/`failed` at end | [state-and-output.md](references/state-and-output.md) |
| 7 | **Retry/locking live above the worker** — re-dispatch transient failures with the error appended; escalate permanent ones | [runner.md](references/runner.md) |
| 8 | **Auth is the CLI's own login** — persisted OAuth session or `ANTHROPIC_API_KEY`/`CLAUDE_CODE_OAUTH_TOKEN`; force `HOME` | [cli-invocation.md](references/cli-invocation.md) |

Invariants 1–8 are the **mandatory core**. The review/approval gate (**invariant 9** — a human gate before anything irreversible), scheduling, workflow DAGs, the learning loop, multi-tenant workspaces, and a dashboard are **opt-in advanced layers** — see [references/advanced.md](references/advanced.md). (Invariant 9 is conditional: its reviewer machinery is opt-in, but *if* an agent performs an irreversible action it becomes mandatory — see Hard rules.)

## Workflow: explain → plan → scaffold

Do not generate code before understanding the target project and confirming intent. **If the path or fit is unclear, grill the user one question at a time** (the `grill-me` discipline): one sharp question, your recommended default, wait, then the next.

```
Backend Progress:
- [ ] Explain: confirm the pattern fits this project; name what it replaces
- [ ] Detect:  map the target stack (language, web framework, datastore, host, auth, scheduler)
- [ ] Plan:    map each core invariant onto the stack; pick which advanced layers (if any)
- [ ] Approve: present the plan + file list; get explicit go-ahead before writing
- [ ] Scaffold: generate the core spine in dependency order; then chosen advanced layers
- [ ] Verify:  prove a real claude -p run completes end-to-end through the new spine
```

- **Explain** — confirm the use case fits (see above). State what this replaces (a bespoke API+tools loop) and why the CLI buys it.
- **Detect** — read the repo: language, web framework, datastore, host/deploy, existing auth, any scheduler. The scaffold adapts to these — see [references/scaffold.md](references/scaffold.md).
- **Plan** — produce a mapping table (invariant → concrete file/component in this stack) + the advanced layers chosen. Nothing speculative.
- **Approve** — present the plan and the exact file list. **No source is written before approval.**
- **Scaffold** — generate in dependency order (auth/CLI smoke test → runner → agent contract → state/persist → capabilities → advanced). See [references/scaffold.md](references/scaffold.md).
- **Verify** — actually trigger one agent and confirm a tracked run completes and lands real state. A scaffold that never ran proves nothing.

## Hard rules

- **Never call the Anthropic API SDK on the worker path** — that defeats the pattern. The worker is `claude -p`.
- **The model never writes to the datastore directly.** It emits a structured file; deterministic code validates, stamps tenant/run ids, and writes. This makes fabricated "I saved it" impossible (invariant 5).
- **Deny-by-default tools.** Grant the minimum; never wire `--dangerously-skip-permissions` on a server path without an explicit, justified reason.
- **Every spawned worker has a watchdog.** A hung `claude` must be killed by timeout (group kill), or one stuck API call wedges the queue.
- **Authenticate the trigger endpoint.** A shared secret (constant-time compare) at minimum; never expose an unauthenticated spawn endpoint.
- **Never commit credentials.** Persist the CLI login out-of-band (a volume/secret store); document env, don't hardcode keys.
- **If an agent performs any irreversible action (publish, send, spend), a human gate is mandatory** (invariant 9). Generation produces drafts; promotion to "live" is a separate, approved step. The reviewer-agent machinery itself is opt-in ([references/advanced.md](references/advanced.md)) — the gate is not.

## Additional resources

- The portable invariants, in depth: [references/invariants.md](references/invariants.md)
- Invoking `claude -p` as a backend (flags, stdin, auth, model, timeout): [references/cli-invocation.md](references/cli-invocation.md)
- The dumb-spawner trigger server + watchdog + retry: [references/runner.md](references/runner.md)
- Agent contract + layered prompt assembly + run tracking: [references/agent-contract.md](references/agent-contract.md)
- Model-proposes / code-disposes write path + run state: [references/state-and-output.md](references/state-and-output.md)
- Deny-by-default tools / MCP / skills + secrets: [references/capabilities.md](references/capabilities.md)
- Opt-in advanced layers (cron, DAG, approval, learning, dashboard): [references/advanced.md](references/advanced.md)
- Stack detection + the scaffold procedure + verification: [references/scaffold.md](references/scaffold.md)

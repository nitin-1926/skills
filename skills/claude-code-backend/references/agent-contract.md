# The Agent Contract

What an "agent" is in this architecture, and how the harness turns one into a `claude -p` run. The shape below is the nexus gold standard; the **entry/harness can be bash OR your project's language** — keep the contract, swap the implementation.

## An agent is a directory + a registry row

```
agents/<slug>/
├── SKILL.md   # the prompt: YAML frontmatter + a structured body (role, rules, phases, output spec)
├── run.sh     # thin entry: source the harness, init, run, finalize  (≈ 12–80 lines)
└── fix.sh     # (optional) auto-fix entry for a rejected output
```

Plus a registry row (a DB table or config entry) holding `slug`, `system_prompt`/prompt-source, `model`, `schedule`, and capability grants. Nexus resolves **DB-first** (the `agents` table is source of truth), falling back to the filesystem `SKILL.md` when a row is missing — so prompts can be edited live without a deploy.

## The harness owns the ceremony

The per-agent entry is a **thin wrapper**; one shared harness does the 12-step ceremony so every agent is identical:

1. Resolve agent dir + repo root.
2. Load env (tenant slug/id, data dirs, run/step ids, trigger source).
3. Gate checks (schedule enabled? quiet-hours/"zen" window?).
4. Resolve the tenant data dir.
5. **Assemble the layered prompt** (below).
6. **Open the run row** (`status=running`) — capture the id.
7. Resolve capabilities (tools/MCP/skills — [capabilities.md](capabilities.md)).
8. **Invoke `claude -p`** with the prompt on stdin ([cli-invocation.md](cli-invocation.md)); capture exit code.
9. On failure: alert + mark the run `failed`.
10. **Persist** the model's output file through the single write path ([state-and-output.md](state-and-output.md)).
11. Post-run hooks (versioning, learning candidate, custom alerts).
12. Finalize: patch the run terminal, advance any workflow step.

A per-agent `run.sh` therefore reduces to: `source harness` → `init <slug>` → build `TASK` → `run "$TASK"` → optional post-hooks → `finalize`. Nexus's are 12–80 lines.

## Layered prompt assembly (invariant 3)

The harness concatenates layers in a **fixed order**, then appends the task and pipes the whole thing to stdin:

```
[ universal system prompt ]        ← rules every agent obeys (product, terminology, hard limits)
[ tenant/workspace context ]       ← per-tenant rules, vocabulary, schemas   (omit if single-tenant)
[ live configuration ]             ← values pulled from the DB at run time    (optional)
[ learned rules ]                  ← corrections distilled from human feedback (optional — advanced.md)
[ agent frontmatter digest ]       ← one-line role/IO summary
[ agent body ]                     ← this agent's role, phases, output spec
---
## Your task
<task text, with any upstream outputs / inputs concatenated in>
```

- **Keep assembly in one place.** A single `load_prompts` function means a change to the universal layer reaches every agent at once.
- **Start minimal.** A single-tenant app with no learning loop is just *universal + agent body + task*. Add layers when you need them.
- **The task carries context.** Upstream outputs, form inputs, and (on retry) the prior error are appended to the task block so the agent has everything in one shot.

## Writing the agent prompt (SKILL.md body)

Nexus agents follow a 7-section body — a reasonable default skeleton:

1. **Methodology / role** — what this agent is and how it thinks.
2. **Core philosophy** — the few principles it must not violate.
3. **Routing logic** — what input it consumes, when it should no-op.
4. **Knowledge base** — domain facts, links to context files it may read.
5. **Core rules** — hard constraints (what it must never do — e.g. never fabricate, never publish).
6. **Phases** — the step-by-step procedure for a run.
7. **Output standards** — the **exact** shape of the file it must write (this is the contract the persist step validates against).

Section 7 is load-bearing: the agent's only real output is the structured file, and [state-and-output.md](state-and-output.md) validates it. Be precise about the schema.

## Run tracking (invariant 6)

The harness — not the server — owns the run row. Open `running` with `{agent, status, log_file, triggered_by, tenant, …}` at step 6, capture the id into the env, and patch it to `completed`/`failed` (+ `completed_at`, `error_message`) at finalize. An empty id is a loud warning: the run would be invisible.

## Adapting to a non-bash stack

The contract is *thin entry + shared harness + structured prompt file + registry row*. In a TS/Node project: the "harness" is a module, `run.sh` becomes an exported `runAgent(slug, task)`, and you still `spawn("claude", ["-p", …])`. Keep the 12 steps and the layered prompt; the language is incidental.

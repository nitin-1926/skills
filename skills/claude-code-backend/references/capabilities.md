# Capabilities: Tools, MCP, Skills, Secrets

A server-side agent is only as safe as what you let it touch. Resolve capabilities **deny-by-default, per agent, per run** (invariant 4).

## Resolve at spawn time, from an explicit registry

Before invoking `claude -p`, a resolver reads what *this* agent is granted and emits exactly three things: the allowed tools, an MCP config (if any), and the skill dirs to mount. Anything ungranted is simply absent — there is no implicit allow.

**Nexus:** `resolve_capabilities.py` queries enabled grants and prints:

```
TOOLS=Read,Write,Bash,WebSearch
MCP_CONFIG=/tmp/nexus_mcp_<step>.json
SKILL_DIRS=/path/to/skillA:/path/to/skillB
```

The harness feeds `TOOLS` to `--allowedTools`, `MCP_CONFIG` to `--mcp-config`, and symlinks the skill dirs into the CLI's config dir.

## Tools (`--allowedTools`)

- Grant the **minimum**. A writer agent needs `Read,Write,Bash`; a research agent needs `WebSearch,WebFetch,Read`; a reviewer might need only `Read,Grep,Glob`.
- Empty/unknown grant → a **minimal safe fallback** (e.g. `Read`), never a blanket allow.
- **Never** wire `--dangerously-skip-permissions` into a server path without an explicit, written justification. On a backend there's no human to approve a permission prompt, so the *allowlist* is your entire safety boundary — make it tight.
- The tool list flows into argv. Build it from your registry, never from unvalidated caller input.

## MCP servers (`--mcp-config`)

Attach external capabilities (databases, SaaS APIs, browsers) as MCP servers per run:

- The resolver writes `{ "mcpServers": { "<name>": { command, args, env } } }` to a temp file and passes `--mcp-config <file>`.
- Inject each server's secrets through its `env` block in that JSON — not into the global environment.
- Grant MCP servers per agent, same deny-by-default discipline as tools.

## Skills

Mount Claude Skills the agent may use by symlinking their dirs into the CLI config dir (`${CLAUDE_CONFIG_DIR:-$HOME/.claude}/skills`) and adding the `Skill` tool to the allowlist when any are mounted. This lets agents share reusable procedures without baking them into every prompt.

## Per-run overrides

Allow a single run to layer on top of the agent's standing grants — `{add_tools, remove_tools, add_mcps, remove_mcps, add_skills, remove_skills}` passed via env (nexus: `NEXUS_OVERRIDES` JSON). Useful for a one-off workflow node that needs one extra tool without changing the agent's defaults.

## Secrets & env into the spawned process

- The worker inherits the runner's env, so downstream tools/MCP find their keys — **be deliberate about what's in the parent env**. Don't leak more than the agent needs.
- Force `HOME` (and `CLAUDE_CONFIG_DIR` if relocated) so the CLI finds its login ([cli-invocation.md](cli-invocation.md)).
- Keep provider secrets in a secret store / volume, injected at spawn — never committed, never in the prompt.
- **Guard against arg injection:** any caller-influenced value that reaches argv (model, tool names) must be validated against an allowlist. Nexus hardcodes the chat surface's tool list and model allowlist precisely to block shell-arg injection through the request body.

## Checklist

- [ ] Tools are an explicit allowlist per agent; default is minimal, not open.
- [ ] No `--dangerously-skip-permissions` on a server path without justification.
- [ ] MCP secrets ride in the per-server `env`, not the global env.
- [ ] Caller-supplied model/tool values are allowlist-validated before hitting argv.
- [ ] The parent env exposes only what agents need.

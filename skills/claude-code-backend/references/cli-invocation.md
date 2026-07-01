# Invoking `claude -p` as a Backend

The heart of the pattern. This is how a request becomes an LLM-driven worker — no API SDK, just a subprocess.

## The core invocation

Pipe the fully-assembled prompt to the CLI's **stdin** and read its stdout. Minimal flags:

```bash
printf '%s\n\n## Your task\n%s' "$COMBINED_PROMPT" "$TASK" \
  | claude -p \
      --model "$MODEL" \
      --allowedTools "$ALLOWED_TOOLS" \
      ${MCP_ARGS[@]+"${MCP_ARGS[@]}"} \
  2>&1 | tee -a "$LOG_FILE"
EXIT_CODE=${PIPESTATUS[0]}   # the CLI's exit code, not tee's
```

- `-p` / `--print` — headless: run once, print the result, exit. This is what makes it a backend worker rather than an interactive session.
- `--model` — pin the model per agent (resolve from a registry; validate against an allowlist so a caller can't inject an arbitrary string).
- `--allowedTools "Read,Write,Bash,WebSearch,…"` — comma list; **deny-by-default** (see [capabilities.md](capabilities.md)).
- `--mcp-config <path>` — optional; a JSON file of MCP servers to attach for this run.
- The **system prompt is the stdin body** — nexus does not use `--system-prompt` on the agent path; the whole layered prompt is piped in, with the task appended under a `## Your task` heading.
- Capture `PIPESTATUS[0]` (bash) / the process exit code (other languages) — a non-zero means the run failed; branch on it.

**Why stdin, not a positional arg:** prompts are large and contain arbitrary text; stdin avoids arg-length limits and shell-quoting hazards. (A short, fixed system prompt *may* use `--system-prompt` with the user text as a positional arg — nexus's document-edit path does exactly that: `claude -p --system-prompt "$SYS" --no-session-persistence --tools "" --output-format text "$USER"`.)

## Output formats

- **Default (text):** stdout is the model's final text. Treat it as a *log artifact*, not a data source — structured results flow through the file→persist path ([state-and-output.md](state-and-output.md)).
- **`--output-format stream-json --verbose`:** newline-delimited events (`content_block_delta`, `tool_use`, `tool_result`, `result.is_error`). Parse these when you need live streaming — e.g. nexus's chat surface spawns `claude -p --output-format stream-json --verbose --include-partial-messages …` and re-emits the deltas as SSE frames.
- **`--output-format text`** (explicit) for single-shot edits where you only want the final string.

## Model selection

Resolve the model per agent from your registry; **validate against an allowlist** before passing it to `--model` (a model string flows into a shell/argv — never pass an unvalidated caller-supplied value). Nexus validates against a small allowlist of current model IDs (Opus / Sonnet / Haiku tiers) and defaults to a Sonnet tier — look up the current model IDs rather than copying version strings, which age. Pick the cheapest tier that does the job; reserve Opus for the hardest agents.

## Auth (no API key required)

The `claude` CLI authenticates *itself* from on-disk credentials or an env token. Three options:

| Source | How | When |
|--------|-----|------|
| **Persisted OAuth login** (subscription) | `claude login` once → `~/.claude` + `~/.claude.json`; persist these on a volume/secret store; symlink into the runtime `HOME` | nexus's choice — flat-rate subscription, no per-token billing |
| **`CLAUDE_CODE_OAUTH_TOKEN`** | export the token in the spawn env | headless/CI where you can't run an interactive login |
| **`ANTHROPIC_API_KEY`** | export in the spawn env | metered API billing; simplest in cloud secret managers |

**Critical for servers:** force `HOME` (and `CLAUDE_CONFIG_DIR` if you relocate the config) in the spawn environment so the subprocess finds the credentials. Nexus sets `HOME=/root` in every spawn and symlinks `/data/.claude → /root/.claude` in the Dockerfile so the login survives redeploys.

**macOS gotcha:** the CLI reads credentials via the Keychain, which **breaks for detached/orphaned child processes**. Spawn **non-detached** locally on macOS (nexus's local runner does `detached:false` for exactly this reason); detached is fine on Linux where creds are file-based.

## Timeout / watchdog (non-negotiable)

A hung API call must not wedge the worker. Wrap every spawn in a watchdog:

- Start a timer (`CLAUDE_TIMEOUT_MS`, e.g. 30 min) on spawn.
- On timeout: SIGTERM the process **group**, then SIGKILL after a grace period (`CLAUDE_KILL_GRACE_MS`, e.g. 10 s).
- Group kill matters because `claude` spawns child tools — kill `-pid` (detached) or `pkill -P` (non-detached) so nothing is orphaned.

See [runner.md](runner.md) for where the watchdog lives in the server.

## Smoke test before building anything

The very first scaffold step: prove the CLI runs in the target environment.

```bash
echo "Reply with exactly: ok" | claude -p --allowedTools ""
```

(Let the CLI pick its default model for the smoke test — don't pin a version string here.) If that doesn't print `ok`, fix auth/`HOME`/install before writing a single line of runner code.

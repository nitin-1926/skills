# The Runner: a Dumb Spawner

The HTTP layer. Its whole job is: authenticate the caller, spawn the worker, guard it, return. No reasoning lives here — that keeps it portable and restart-safe.

## Responsibilities (and non-responsibilities)

**Does:** auth the request · resolve agent → entry script/command · spawn the worker with the right env · attach a watchdog · stream stdout to a log · return immediately (202/200).

**Does NOT:** assemble prompts · call the model · write business state · decide retries. Those live in the harness ([agent-contract.md](agent-contract.md)), the persist path ([state-and-output.md](state-and-output.md)), and the orchestrator (below).

## The trigger endpoint

```
POST /trigger/<agent>     header: x-runner-secret: <shared secret>
  → 400 if required context (e.g. run/step ids) is missing
  → spawn worker, return 200/202 with the run id
```

- **Authenticate** with a shared secret compared in **constant time** (hash-compare, not `==`, to avoid timing leaks). Refuse to boot if the secret env var is unset. Never expose an unauthenticated spawn endpoint — it's remote code execution by proxy.
- **Resolve the agent** from an in-memory map rebuilt periodically from your registry (nexus rebuilds the `agents` map at boot and every 60 s, with a hardcoded fallback list).
- **Resolve the entry**: a per-agent script if it exists, else a shared generic entry with the slug as an argument (nexus: `agents/<slug>/run.sh` else `agents/_shared/generic_run.sh <slug>`).

## Spawning

```js
const child = spawn("bash", [entryScript, task], {
  env: { ...process.env, HOME: "/root", AGENT_SLUG, RUN_ID, TRIGGERED_BY, /* tenant + context */ },
  detached: true,          // Linux; use false on macOS (Keychain — see cli-invocation.md)
  stdio: ["ignore", logFd, logFd],
});
attachWatchdog(child, CLAUDE_TIMEOUT_MS, CLAUDE_KILL_GRACE_MS);
```

- **Inject the full context as env**: agent slug, run id, trigger source (`schedule`/`manual`/`workflow`/`chat`), tenant id, any workflow/step ids, data dirs, dashboard URL. The worker reads these; it does not re-derive them.
- **Inherit the process env** so downstream tools/MCP get their secrets — but be deliberate about what's in the parent env.
- **Return immediately.** The run is tracked by its row ([state-and-output.md](state-and-output.md)); the caller polls or subscribes for completion. Do not block the HTTP response on the model.
- **Beware fire-and-forget lying.** If the spawn itself fails, surface it — don't let the caller believe a run started. (Nexus flags this as an open bug: a fire-and-forget trigger can show "approved" while the spawn silently failed.)

## The watchdog

```js
function attachWatchdog(child, timeoutMs, graceMs) {
  const t = setTimeout(() => {
    try { process.kill(-child.pid, "SIGTERM"); } catch {}   // group kill (detached)
    setTimeout(() => { try { process.kill(-child.pid, "SIGKILL"); } catch {} }, graceMs);
  }, timeoutMs);
  child.on("close", () => clearTimeout(t));
}
```

Non-detached (macOS/local): kill the tree with `pkill -P <pid>` instead of the negative-pid group kill. Either way, **a runaway `claude` is always killable.**

## Prod == local

Run the **same server shape** in production and locally so there is no behavioral skew. Nexus's `deploy/server.js` and `runner/local-runner.mjs` are deliberate mirrors; the only differences are `detached` (macOS) and the kill mechanism. Boot prod + local from the same code path where you can.

## Retry and overlap control (above the worker)

Put these in the **dispatcher/orchestrator**, never inside the agent (invariant 7):

- **Retry:** on a *transient* failure, re-dispatch the same task with the prior error text appended so the agent self-corrects. Cap attempts (nexus default 3). **Never retry** on auth/permission/schema errors — escalate immediately, or you retry-storm the dependency.
- **Overlap guard:** prevent two runs of the same single-writer agent at once. Nexus's cron daemon keeps a per-job `inFlight` set; the open issue it documents is that there's no global in-flight lock, so cron + manual can still collide — add one if your outputs are single-writer.
- **Completion callback retry:** if the worker reports completion over HTTP, give *that* call its own bounded retry (nexus's `finish.sh` retries 5× with linear backoff, then pages on failure) — a lost callback orphans the run in `running`.

## One dispatch path for scheduled and manual

A scheduled run and a "Run now" click should be **byte-identical**. Route both through a single dispatcher function so there's exactly one code path to reason about. See scheduling in [advanced.md](advanced.md).

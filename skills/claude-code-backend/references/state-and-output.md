# State & Output: Model Proposes, Code Disposes

The highest-leverage invariant in the whole architecture (invariant 5). Get this right and the rest is plumbing.

## The principle

**The model must never write your source of truth.** It can claim success it didn't achieve, forget a tenant id, or invent a row shape. So the model's only output is a **proposal artifact** — a structured file. A deterministic step is the **single write path**: it validates the file, stamps the ids the model can't forge, writes, and reports exactly what landed. A fabricated "I saved it" is then *structurally impossible* — only physically-written records count.

```
claude -p  →  writes  $PENDING_FILE (JSON)   [the proposal]
                         │
                         ▼
        persist step (deterministic, NOT the model):
          1. parse $PENDING_FILE — unparseable ⇒ hard failure (EXIT 1), never a silent skip
          2. validate every record against a schema
          3. auto-stamp tenant_id, run_id  (the model cannot set these)
          4. write through the ONE path (DB / API / files), let a dedup constraint arbitrate
          5. print a machine-readable result: {inserted, deduped, failed, errors}
                         │
                         ▼
        harness parses the result line ⇒ success/failure of the run
```

**Nexus:** the model writes a JSON array file; `persist.py` validates against `persist_schema.json`, auto-stamps `workspace_id` + `workflow_run_id`, `POST`s via PostgREST (`Prefer: return=representation`), and a DB `BEFORE INSERT` trigger dedups. It prints `{inserted, deduped, failed, errors}`; if the final line isn't valid JSON the harness treats the whole run as failed.

## Why a file, not stdout parsing

Parsing the model's free-text stdout for data is brittle and spoofable. A dedicated output file the agent is instructed to write (path passed in via env) is explicit, inspectable, and separates the *log* (stdout, for humans) from the *result* (the file, for the machine). Stdout becomes a pure log artifact (keep a tail of it on the run row for debugging).

## The single write path

Funnel **all** writes through one validated function/script — never let agents (or ad-hoc code) scatter inserts:

- **Validate** every record against a schema before writing. Reject unknown fields and wrong types loudly.
- **Stamp server-authoritative fields** (tenant id, run id, timestamps) in this layer so they can't be forged or forgotten.
- **Dedup** at the boundary (a unique constraint / upsert key) so a retried run is idempotent.
- **Return a structured result** the caller can branch on — counts + errors, not prose.

In nexus this is `persist.py` + `persist_schema.json`, fronted by a `pg.sh` curl helper (`apikey` + `Bearer` headers, `Prefer: return=representation`) that converged 91+ scattered curl sites. Your equivalent might be an ORM repository, a typed API client, or a file-writer — the invariant is *one path, validated, id-stamping*.

## Run state (invariant 6)

Separate from business output, track the **run** itself:

- Open a row at spawn: `{agent, status: "running", log_file, triggered_by, tenant, started_at}`; capture its id into the env so the worker and persist step can reference it.
- Patch to terminal: `{status: "completed" | "failed", completed_at, error_message}`.
- An empty/missing id must be loud — a run with no row is an invisible run.

This row is your observability spine: status dashboards, idempotency checks ("is this agent already running?"), and failure triage all read it.

## Structured handoff between agents (advanced)

When one agent feeds another, don't pass free text — pass the **typed rows it just wrote**, scoped to the run. Nexus collects the run's output rows from the agent's primary table (scoped to `workflow_run_id`) into `{items, summary, primary_ids}` and concatenates that into the next agent's task block. The downstream agent gets structured, already-persisted input — not the upstream's chat output. See workflow handoff in [advanced.md](advanced.md).

## Checklist

- [ ] The model writes a file; it never writes the datastore.
- [ ] One validated, id-stamping write path; no scattered inserts.
- [ ] Unparseable/invalid output ⇒ hard run failure, not a silent skip.
- [ ] A dedup key makes retries idempotent.
- [ ] A run row opens `running` and patches to a terminal status.
- [ ] stdout is logged, not parsed for data.

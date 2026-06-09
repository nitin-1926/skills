# Productionize Execute & Reconcile

Closing the loop. Plans aren't fire-and-forget: `execute` runs one and reviews it; `reconcile` keeps the whole backlog honest. Merging is always the user's call.

## execute <plan>

Run a single plan from `plans/` and review the result like a tech lead.

### 1. Drift check

Before anything, run the plan's own drift check: compare `git rev-parse HEAD` to the commit the plan was written against, and re-read the cited files. If reality no longer matches, STOP and refine the plan instead of executing a stale one.

### 2. Dispatch a cheaper executor

Spawn an executor subagent — a cheaper/weaker model is fine, that's what the plan is written for — **in an isolated git worktree** so the user's working tree is never touched:

```bash
git worktree add ../<repo>-plan-NNN -b plan-NNN
```

Hand it only the plan file. It implements, runs the verification gates, and reports.

### 3. Tech-lead review

Do not trust "done." Review like a tech lead:

- **Re-run every done criterion** yourself in the worktree.
- **Scope compliance** — diff stayed within the plan; nothing in the out-of-scope list was touched.
- **Diff vs. intent** — read the diff against the problem the plan set out to solve, not just whether it compiles.

### 4. Verdict

- **Approve** — gates pass, scope clean, intent met. Report the worktree/branch; the user merges.
- **Revise** — send back to the executor with specific corrections. Max 2 rounds.
- **Block + refine** — if 2 rounds fail or the plan proved wrong, mark the plan `BLOCKED`, write down the obstacle, and refine the plan rather than forcing the change.

Update the plan's status in `plans/INDEX.md` accordingly.

## reconcile

Refresh the backlog after work has landed (often independently of these plans). For each plan in `plans/INDEX.md`:

- **DONE** — verify it still holds (re-run its done criteria). If it regressed, reopen it.
- **BLOCKED** — investigate the obstacle; rewrite the plan around it, or retire it with a reason in the rejection ledger.
- **Drifted** — the cited code changed since the plan was written; refresh the current-state excerpts, conventions, and commit stamp.
- **Fixed independently** — the finding was resolved by other work; retire the plan and note it.

Reconcile reads and re-plans; it does not modify source. The output is an up-to-date `plans/INDEX.md` and refreshed plan files.

## --issues (optional)

When the user wants work tracked where it lives, publish plans as GitHub issues — the same self-contained body, so any agent or human can pick them up. Use the repo's issue tooling (e.g. `gh issue create`). The plan file stays the source of truth.

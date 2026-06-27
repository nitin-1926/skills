# Diff Scope

How to decide exactly what the reviewers see. Get this wrong and every downstream stage reviews the wrong code.

## Resolve the base

Review the branch against its **merge-base with the default branch**, never `git diff HEAD` (that silently misses already-committed branch work).

```sh
DEFAULT=$(git symbolic-ref --quiet --short refs/remotes/origin/HEAD 2>/dev/null | sed 's@^origin/@@' || echo main)
BASE=$(git merge-base HEAD "origin/$DEFAULT" 2>/dev/null || git merge-base HEAD "$DEFAULT")
```

If an explicit target was passed:

- **PR number / URL** — `gh pr checkout <n>` in an isolated worktree (or `gh pr diff <n>`), then base = that PR's merge-base.
- **Branch name** — base = `git merge-base HEAD <branch>`.
- **`base:<ref>`** — use `<ref>` directly, skip detection.

## Collect everything in one shot

One combined command keeps permission prompts and round-trips down:

```sh
echo "BASE:$BASE"; echo "FILES:"; git diff --name-only "$BASE"; \
echo "DIFF:"; git diff -U10 "$BASE"; \
echo "UNTRACKED:"; git ls-files --others --exclude-standard
```

`-U10` gives reviewers enough surrounding context to judge whether a change is locally safe.

## Exclusions (don't review these)

- Lockfiles (`package-lock.json`, `yarn.lock`, `Cargo.lock`, `poetry.lock`, …)
- Generated / compiled / minified output, vendored dependencies, snapshots
- Pure formatting-only churn (a formatter would own it)

**Exception:** database migration files are always in scope — they are the highest-risk diff there is.

## Tier every hunk

Tag each finding's location so the report can separate signal from noise:

| Tier | Definition | Treatment |
| --- | --- | --- |
| **primary** | lines the diff added or modified | full review, normal severity |
| **secondary** | unchanged code the change makes newly relevant (a caller now passing a new value, a now-reachable branch) | review, but only flag if the change makes it wrong |
| **pre-existing** | a problem that exists independent of this diff | separate, clearly-labeled section — never block the PR on it |

Test for pre-existing: *"would I flag this on an identical line in a file this diff never touched?"* If yes → pre-existing.

## Untracked files

Untracked files are **out of scope** until staged — mention their existence once, then skip them. Don't review work the author hasn't committed to including.

## Trivial-diff short-circuit

Before fanning out, skip the heavy machinery when the diff is a closed/draft/automated PR, a pure dependency bump, or a one-line obviously-safe change. Say so and stop. Security-sensitive paths (`auth/`, `crypto/`, payment, permissions) are **never** trivial regardless of size.

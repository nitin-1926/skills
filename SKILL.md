---
name: retroactive-commit-history
description: Splits existing or new code into multiple smaller, meaningful commits with realistic dates and author attribution. Use when retrofitting git history, backdating commits, future-dating commits, or creating a natural commit sequence from a batch of changes—ensuring changes are properly committed regardless of date, time, or timezone.
metadata:
  author: nitin-1926
  version: "1.0.0"
---

# Retroactive Commit History

## Purpose

Turn a batch of changes into ~N commits over date range X–Y with realistic development order, proper author/committer attribution, and contribution-graph-friendly dates.

## When to Use

Use this skill when you need to:

- **Retrofit git history** – split a batch of changes into logical commits
- **Backdate commits** – assign past dates to commits (e.g., for contribution graphs)
- **Future-date commits** – assign future dates when needed
- **Any date, time, or timezone** – ensure changes are properly committed regardless of temporal constraints
- **Create natural commit sequences** – turn uncommitted work into a realistic development timeline
- **Avoid Cursor Co-authored-by** – prevent `cursoragent` from appearing as a contributor on GitHub

## When NOT to Use

- **Shared branches** – Do not rewrite history on branches others are actively using without team agreement
- **Already-pushed commits** – Avoid rewriting commits that have been pushed to a shared remote unless you coordinate force-push with collaborators
- **Public release history** – Be cautious when altering history that has been tagged or released

## Commit Format

- **Pattern**: `feat/fix/chore/refact/docs/test: description` (max 100 chars)
- **Examples**: `feat: add canvas primitive types`, `chore: add .gitignore`, `fix: ensure type exports`, `docs: add API documentation`

## Cursor Co-authored-by Prevention (Critical)

**Cursor IDE automatically appends `Co-authored-by: Cursor <cursoragent@cursor.com>` to every commit made by the agent.** This causes GitHub to show cursoragent as a contributor. To prevent this:

1. **Always disable hooks when committing**: Use `git -c core.hooksPath=/dev/null commit` instead of `git commit`
2. **Or run commits via terminal** with explicit env vars (Cursor may still inject Co-authored-by via prepare-commit-msg hook)
3. **Post-commit check**: Run `git log --format="%B" -1 | grep -q "Co-authored-by"` – if match, amend or filter-branch to remove

## Git Environment Variables

Set before each `git commit`:

```bash
export GIT_AUTHOR_NAME="Your Name"
export GIT_AUTHOR_EMAIL="your@email.com"
export GIT_COMMITTER_NAME="Your Name"
export GIT_COMMITTER_EMAIL="your@email.com"
export GIT_AUTHOR_DATE="2026-02-16T09:00:00+05:30"
export GIT_COMMITTER_DATE="2026-02-16T09:00:00+05:30"
git add <files>
git -c core.hooksPath=/dev/null commit -m "chore: init package.json"
```

## Partial-File Strategy

For commits that add only part of a file:

1. **Build incrementally**: Create file with first section, commit, append next section, commit, repeat
2. **Logical sections**: Each commit should add a coherent unit (e.g. primitive types, then element types)
3. **Dependencies**: Add imports and types as needed; keep each commit buildable

## Verification

- `git log --format="%B" | grep -c "Co-authored-by"` – must be 0
- `git log --format="%H %s %an %ae"` – verify no cursor/claude in messages
- `git log --format="%ad" --date=short` – verify dates span target range
- `git diff HEAD~N..HEAD` – ensure no lost changes

## Anti-Patterns

- No empty commits
- No bot suffixes in messages (e.g. "Co-authored-by: Cursor")
- **Always** use `git -c core.hooksPath=/dev/null commit` when committing from Cursor agent
- Same author and committer for contribution graph

## Additional Resources

- For date formulas and env var reference, see [reference.md](reference.md)
- For sample commit sequences, see [examples.md](examples.md)

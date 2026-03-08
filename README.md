# Retroactive Commit History

Stop committing 'WIP' at 2am. Ship clean history.

An AI agent skill that splits batch changes into multiple smaller, meaningful commits with realistic dates and proper author attribution. Ensures changes are properly committed regardless of date, time, or timezone.

**Compatible with:** Cursor, Claude Code, Codex, Windsurf, and other agents that support the [Agent Skills](https://agentskills.io/) format.

## What It Does

This skill guides AI agents to:

- Turn a batch of uncommitted changes into a logical sequence of commits
- Assign realistic or custom dates (past, present, or future) to commits
- Use proper author/committer attribution for contribution graphs
- Prevent Cursor or others from injecting `Co-authored-by: Cursor/Claude` into commit messages
- Build commit history incrementally with coherent, buildable steps

## When to Use

Use this skill when you need to:

- **Retrofit git history** – split a batch of changes into logical commits
- **Backdate commits** – assign past dates (e.g., for contribution graphs)
- **Future-date commits** – assign future dates when needed
- **Any date, time, or timezone** – ensure changes are properly committed regardless of temporal constraints
- **Create natural commit sequences** – turn uncommitted work into a realistic development timeline
- **Avoid Cursor Co-authored-by** – prevent `cursoragent` from appearing as a contributor on GitHub

## Installation

```bash
npx skills add nitin-1926/retroactive-commit-history
```

When prompted, prefer **Symlink** (the default) for easy updates via `npx skills update`. Use `--copy` only if symlinks are not supported on your system.

### Install to specific agents

```bash
npx skills add nitin-1926/retroactive-commit-history -a cursor -a claude-code
```

### Global installation

```bash
npx skills add nitin-1926/retroactive-commit-history -g
```

## Features

- **Commit format** – `feat/fix/chore/refact/docs/test: description` (conventional commits)
- **Date control** – ISO 8601 dates with timezone for `GIT_AUTHOR_DATE` and `GIT_COMMITTER_DATE`
- **Cursor hook bypass** – `git -c core.hooksPath=/dev/null commit` to avoid Co-authored-by injection
- **Partial-file strategy** – build files incrementally across multiple commits
- **Verification commands** – validate no bot mentions, correct dates, no lost changes
- **Reference docs** – date formulas, env vars, filter-repo, rebase workflows
- **Example sequences** – 50-commit package, 15-commit feature branch, 5-commit bugfix

## Quick Reference

### Git environment variables (set before each commit)

```bash
export GIT_AUTHOR_NAME="Your Name"
export GIT_AUTHOR_EMAIL="your@email.com"
export GIT_COMMITTER_NAME="Your Name"
export GIT_COMMITTER_EMAIL="your@email.com"
export GIT_AUTHOR_DATE="2026-02-16T09:00:00+05:30"
export GIT_COMMITTER_DATE="2026-02-16T09:00:00+05:30"
git add <files>
git -c core.hooksPath=/dev/null commit -m "feat: add feature"
```

### Verification

```bash
# Must be 0
git log --format="%B" | grep -c "Co-authored-by"

# Verify dates span target range
git log --format="%ad" --date=short

# Ensure no lost changes
git diff HEAD~N..HEAD
```

## Examples

<img width="1020" height="908" alt="Screenshot 2026-03-09 at 12 09 20 AM" src="https://github.com/user-attachments/assets/33cbd368-d172-4485-80f9-a79a09fb2285" />

See [examples.md](examples.md) for sample commit sequences:

- **New package** – 50 commits over 5 days (bootstrap → types → utils → adapter → polish)
- **Feature branch** – 15 commits over 3 days (API, validation, tests, docs)
- **Bugfix** – 5 commits in 1 day (fixes, test, changelog)

## Troubleshooting

### Removing Co-authored-by from existing commits

Use `git filter-repo` (recommended) or `git filter-branch`. See [reference.md](reference.md) for full commands.

### Fixing author date after commit

```bash
export GIT_AUTHOR_DATE="2026-02-20T14:00:00+05:30"
export GIT_COMMITTER_DATE="2026-02-20T14:00:00+05:30"
git commit --amend --no-edit
```

### Rebase to change multiple commit dates

```bash
git rebase -i HEAD~N
# Mark commits as "edit", then for each:
export GIT_AUTHOR_DATE="..."
export GIT_COMMITTER_DATE="..."
git commit --amend --no-edit
git rebase --continue
```

## Additional Resources

- [reference.md](reference.md) – Date format, env vars, filter-repo, timezone handling
- [examples.md](examples.md) – Sample commit sequences

## License

MIT

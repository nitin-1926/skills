# Retroactive Commit History – Reference

## Date Format

ISO 8601 with timezone for `GIT_AUTHOR_DATE` and `GIT_COMMITTER_DATE`:

```
YYYY-MM-DDTHH:MM:SS+05:30
```

Example: `2026-02-16T09:00:00+05:30` (IST)

## Timezone Handling

Use a consistent timezone for all commits in a sequence to keep the contribution graph coherent. Common choices:

- **IST**: `+05:30` (e.g. `2026-02-16T09:00:00+05:30`)
- **UTC**: `+00:00` (e.g. `2026-02-16T03:30:00+00:00`)
- **EST**: `-05:00` (e.g. `2026-02-15T22:30:00-05:00`)

GitHub's contribution graph uses the commit's author date in UTC. Pick one timezone and stick with it for the entire sequence.

## Date Distribution

For ~10 commits/day over 5 days:

- Day 1: `2026-02-16T09:00:00+05:30` … `2026-02-16T13:30:00+05:30` (30-min intervals)
- Day 2: `2026-02-17T09:00:00+05:30` … `2026-02-17T13:30:00+05:30`
- Repeat for days 3–5

## Environment Variables

| Variable | Purpose |
|----------|---------|
| `GIT_AUTHOR_NAME` | Shown as author in `git log` |
| `GIT_AUTHOR_EMAIL` | Author email |
| `GIT_AUTHOR_DATE` | Date for contribution graph |
| `GIT_COMMITTER_NAME` | Committer (usually same as author) |
| `GIT_COMMITTER_EMAIL` | Committer email |
| `GIT_COMMITTER_DATE` | Committer date |

## Why Cursor Adds Co-authored-by

Cursor IDE injects `Co-authored-by: Cursor <cursoragent@cursor.com>` into commit messages when the agent runs `git commit`. This happens via a prepare-commit-msg hook or similar mechanism. GitHub then shows cursoragent as a contributor. Disabling hooks (`core.hooksPath=/dev/null`) prevents the injection.

## Filtering Bot Mentions (Removing Co-authored-by)

If commits already contain Co-authored-by, rewrite history.

### Option 1: git filter-repo (Recommended)

`git filter-branch` is deprecated. Use `git filter-repo` for faster, safer history rewriting:

```bash
# Install: pip install git-filter-repo
git filter-repo --message-callback 'return re.sub(r"^Co-authored-by:.*\n?", "", message)' --force
```

Then force push: `git push origin main --force`

### Option 2: git filter-branch (Legacy)

```bash
FILTER_BRANCH_SQUELCH_WARNING=1 git filter-branch -f --msg-filter 'grep -v "^Co-authored-by:"' -- main
```

Then force push: `git push origin main --force`

To amend a single commit:

```bash
git -c core.hooksPath=/dev/null commit --amend -m "your message"
```

## Fixing Author Date After Commit

```bash
export GIT_AUTHOR_DATE="2026-02-20T14:00:00+05:30"
export GIT_COMMITTER_DATE="2026-02-20T14:00:00+05:30"
git commit --amend --no-edit
```

## Post-Push: Removing Co-authored-by from Existing Commits

1. Verify: `git log --format="%B" | grep -c "Co-authored-by"`
2. Rewrite: Use `git filter-repo` (preferred) or `git filter-branch` as shown above
3. Clean (filter-branch only): `rm -rf .git/refs/original && git reflog expire --expire=now --all && git gc --prune=now`
4. Push: `git push origin main --force`

## Rebase to Change Date

```bash
git rebase -i HEAD~N
# Mark commits as "edit", then:
export GIT_AUTHOR_DATE="..."
export GIT_COMMITTER_DATE="..."
git commit --amend --no-edit
git rebase --continue
```

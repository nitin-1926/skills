---
name: setup-devlog
description: One-shot, idempotent setup of a project devlog (DEVLOG.md) plus CLAUDE.md/AGENTS.md discipline snippets that enforce per-change updates. Use when the user says "set up devlog", "start tracking decisions in this project", "init devlog", "add a devlog system here", or wants a journal of decisions, tradeoffs, issues, and fixes that future blog posts, LLM-mistake pattern analysis, or context-restoration sessions can draw from. Detects what's already in place and only adds what's missing — safe to re-run.
metadata:
  author: nitin-1926
  version: "1.0.0"
---

# Setup Devlog

## When to use

- User wants to initialize a devlog for this repo
- User wants the "keep a log of decisions and tradeoffs" workflow but doesn't have a system yet
- User has a partial setup (some pieces in place, others missing) and wants it completed
- User is starting a new project and wants devlog discipline from day one

The skill **does not append entries**. Once setup is done, the discipline lives in CLAUDE.md/AGENTS.md and runs every session via cascade.

## Workflow

This is a four-check, idempotent setup. For each check, only act if the artifact is missing or wrong. Always confirm before writing.

### 1. Resolve repo root

```bash
ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
```

If not in a git repo, ask the user: "Use current directory `<pwd>` as the project root, or point me at a different path?"

### 2. Check DEVLOG.md

```bash
test -f "$ROOT/DEVLOG.md" && echo present || echo absent
```

If **absent**: gather two short answers from the user — they populate the template:

- "What is this project's purpose? (one paragraph)"
- "Baseline state — what already exists, what is intentionally out of scope? (3-6 bullets)"

Then copy [`references/devlog-template.md`](references/devlog-template.md) to `$ROOT/DEVLOG.md`, replacing `{{PROJECT_NAME}}`, `{{PROJECT_PURPOSE}}`, and `{{BASELINE}}` with the user's answers. The template already includes the entry template and 2 example entries inline so the agent knows the shape.

If **present**: leave it alone. Do not edit existing devlogs.

### 3. Check `.gitignore`

Ask: "Should DEVLOG.md be local-only (gitignored) or committed (shared with team)?" Default: local-only — matches the maintainer-journal use case.

If local-only and `.gitignore` does not already contain `DEVLOG.md`:

```bash
echo "" >> "$ROOT/.gitignore"
echo "# Maintainer-only devlog" >> "$ROOT/.gitignore"
echo "DEVLOG.md" >> "$ROOT/.gitignore"
```

If committed: skip — also confirm DEVLOG.md is not already gitignored from a prior local-only setup; if it is, ask before removing the line.

### 4. Check CLAUDE.md and AGENTS.md

For each of `$ROOT/CLAUDE.md` and `$ROOT/AGENTS.md`:

- If file exists and already contains the marker `<!-- devlog-discipline -->`: skip
- If file exists without the marker: append the snippet from [`references/claude-md-snippet.md`](references/claude-md-snippet.md) (for CLAUDE.md) or [`references/agents-md-snippet.md`](references/agents-md-snippet.md) (for AGENTS.md), wrapped in the marker comments
- If CLAUDE.md does NOT exist: ask the user "Create CLAUDE.md with just the devlog discipline section, or skip CLAUDE.md entirely?" Don't auto-create — many projects have specific CLAUDE.md conventions and a skill-created stub may surprise.
- If AGENTS.md does NOT exist: skip silently. AGENTS.md is opt-in for projects that use it.

### 5. Print summary

```
Devlog setup complete.

Created:    DEVLOG.md
Updated:    .gitignore (DEVLOG.md added)
Updated:    CLAUDE.md (devlog discipline section appended)
Skipped:    AGENTS.md (file does not exist)

Next: every substantive change in this repo should append a new entry at
the top of `## Log` in DEVLOG.md, in the same session as the change. The
discipline is also documented in CLAUDE.md so future Claude Code sessions
follow it automatically.
```

## Anti-patterns (do not)

- Overwrite an existing DEVLOG.md without asking
- Auto-create CLAUDE.md or AGENTS.md if absent
- Inject the discipline section more than once (the marker comment prevents this — always grep for `<!-- devlog-discipline -->` first)
- Hard-code the project name — derive from `$(basename $ROOT)` or ask
- Forget to add DEVLOG.md to `.gitignore` when the user said local-only — silent loss of privacy is worse than asking twice

## Bundled resources

- [`references/devlog-template.md`](references/devlog-template.md) — full DEVLOG.md template with placeholders, entry shape, and 2 example entries
- [`references/claude-md-snippet.md`](references/claude-md-snippet.md) — discipline section for CLAUDE.md, wrapped in marker comments
- [`references/agents-md-snippet.md`](references/agents-md-snippet.md) — discipline section for AGENTS.md, slightly different framing (more directive)
- [`references/entry-examples.md`](references/entry-examples.md) — 4 well-written sample entries showing the _why_-not-_what_ style
- [`scripts/setup.sh`](scripts/setup.sh) — non-interactive setup orchestrator with `--dry-run`, `--committed`, `--gitignored` flags. Use this for scripted setups; the SKILL.md walks the interactive path.

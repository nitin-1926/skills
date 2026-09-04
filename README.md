# Skills

My personal collection of agent skills — modular instructions that I use almost daily and teach coding agents (Cursor, Claude Code, Codex, and others) how to perform specialized workflows.

Each skill lives in its own folder under `skills/` with a `SKILL.md` entry point and optional reference files. Install one skill, several, or the whole collection.

**Distribution:** install from this GitHub repo via `npx skills add nitin-1926/skills` (see [Installation](#installation)). Listing on [skills.sh](https://skills.sh/) is optional discoverability and may appear after installs — it is not required for the skills to work.

## Skills catalog

| Skill                                                                      | What it does                                                                                                                                                                                                                                                                                                                             | Invoke when you…                                                                                                                                 |
| -------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------ |
| [`setup-devlog`](skills/setup-devlog/SKILL.md)                             | One-shot, idempotent setup of `DEVLOG.md` plus CLAUDE.md/AGENTS.md discipline so agents log decisions and tradeoffs in the same session as each change.                                                                                                                                                                                  | Want to "set up devlog", start tracking decisions, or init a maintainer journal in a project.                                                    |
| [`productionize`](skills/productionize/SKILL.md)                           | Master skill that routes to the right path (audit, architecture-deepen, plan, execute, reconcile), grilling you one question at a time when intent is unclear. Runs a vetted parallel audit, applies an architecture-deepening lens, writes self-contained executable plans, and closes the loop — with mandatory approval before edits. | Want to make a prototype production-ready, audit a repo, remove AI slop, clean up tech debt, deepen architecture, or "productionize" a codebase. |
| [`god-review`](skills/god-review/SKILL.md) | GOD-tier review of the current branch's diff: fans out parallel specialist reviewer personas (correctness, security, performance, architecture-depth, maintainability, tests, concurrency, observability, i18n, a11y, git-history, and more), gates findings on anchored 0–100 confidence, promotes cross-reviewer agreement, validates each survivor independently, then emits a ranked report with a provable coverage ledger and a merge verdict. | Want a deep, exhaustive, "miss nothing" code review — a strict maintainability + security + architecture audit of a diff, or a thermo-nuclear review of the current branch/PR before merge. |
| [`claude-code-backend`](skills/claude-code-backend/SKILL.md) | Wire the `claude` CLI into an app as an agentic backend (spawn `claude -p` as a headless worker per task instead of calling an LLM API directly). Routes explain → plan → scaffold: distills the portable gold-standard invariants from the rocketium-nexus architecture (dumb HTTP spawner + watchdog, layered system prompt, deny-by-default tools/MCP/skills, model-proposes/code-disposes write path, run-tracking rows), detects the target stack, and scaffolds a minimal core spine with opt-in advanced layers. | Want Claude Code as a backend / an agent runtime, to run the claude CLI server-side per request, or to build an autonomous-agent platform instead of normal API configuration. |
| [`retroactive-commit-history`](skills/retroactive-commit-history/SKILL.md) | Splits a batch of changes into smaller, meaningful commits with realistic dates and author attribution.                                                                                                                                                                                                                                  | Need to retrofit git history, backdate or future-date commits, or build a natural commit timeline from uncommitted work.                         |
| [`ship-npm-package`](skills/ship-npm-package/SKILL.md) | Sets up one-command, verifiable release automation for an npm package: a preflight-gated `release.sh`, a smoke test that installs the real packed tarball into a throwaway consumer (catching broken `exports` maps, missing types, and bloated `files` globs that unit tests structurally cannot), and CI + tag-triggered publish workflows with npm provenance. | Want to "set up publishing", make a package publishable, automate `npm publish`, add a release script, or turn a hand-rolled publish ritual into something repeatable. |
| [`nextjs-app-fast`](skills/nextjs-app-fast/SKILL.md) | Diagnoses and fixes Next.js App Router performance when the slowness is or isn't in the React — distribution-first measurement, latency attribution, bounded concurrency, payload pagination, platform walls, geography, perceived performance, and silent-failure design (field-tested on a production Amplify + Prisma + Supabase CRM). | Want to make a Next.js app fast, chase p99/timeouts, fix slow directories or cron hangs, cut TTFB, or improve Core Web Vitals without guessing at the median. |

---

## Quick start

```bash
# See what's in this repo
npx skills add nitin-1926/skills --list

# Install one skill globally for Cursor + Claude Code
npx skills add nitin-1926/skills --skill productionize -g -a cursor -a claude-code -y
```

Then open any project and ask your agent to use the skill (see [Usage](#usage)).

---

## Installation

Skills are installed with the [Skills CLI](https://skills.sh/) (`npx skills`). You need Node.js and network access for `npx`.

### List available skills

```bash
npx skills add nitin-1926/skills --list
```

### Install a single skill

```bash
# Project-local (current directory's agent config)
npx skills add nitin-1926/skills --skill productionize

# Global (available in all projects on this machine)
npx skills add nitin-1926/skills --skill productionize -g

# Skip confirmation prompts
npx skills add nitin-1926/skills --skill productionize -g -y
```

Replace `productionize` with `setup-devlog`, `retroactive-commit-history`, or any other skill name from `--list`.

### Install all skills

```bash
npx skills add nitin-1926/skills --all

# Global, non-interactive
npx skills add nitin-1926/skills --all -g -y
```

### Target specific agents

Use `-a` to install into particular agent directories (repeat for multiple agents):

```bash
npx skills add nitin-1926/skills --skill productionize \
  -a cursor \
  -a claude-code \
  -g -y
```

Common agent flags include `cursor` and `claude-code`. Run `npx skills --help` for the full list supported by your CLI version.

### Global vs project-local

| Flag     | Scope                              | Best for                                               |
| -------- | ---------------------------------- | ------------------------------------------------------ |
| _(none)_ | Project-local                      | Skills only for one repo; checked in or per-developer. |
| `-g`     | Global (`~/.cursor/skills/`, etc.) | Skills you want everywhere (e.g. `productionize`).     |

You can install the same skill both ways; prefer **global** for cross-repo workflows and **project-local** when a skill is team-specific.

### Manual installation

If you prefer not to use the CLI, copy or symlink a skill folder into your agent's skills directory:

| Agent       | Personal (global)                | Project                        |
| ----------- | -------------------------------- | ------------------------------ |
| Cursor      | `~/.cursor/skills/<skill-name>/` | `.cursor/skills/<skill-name>/` |
| Claude Code | `~/.claude/skills/<skill-name>/` | `.claude/skills/<skill-name>/` |

Each installed folder must contain `SKILL.md` at its root (same layout as this repo's `skills/<skill-name>/`).

Example (global, Cursor):

```bash
git clone https://github.com/nitin-1926/skills.git /tmp/nitin-skills
mkdir -p ~/.cursor/skills
cp -R /tmp/nitin-skills/skills/productionize ~/.cursor/skills/productionize
```

### Update installed skills

```bash
npx skills check
npx skills update
```

---

## Usage

After installation, agents discover skills from the `description` in each `SKILL.md`. How you invoke them depends on the product:

### Cursor

- **Automatic**: The agent may load a skill when your request matches its description (e.g. "productionize this repo").
- **Explicit**: Attach or mention the skill in chat, e.g. `@productionize` or "use the productionize skill".
- **Slash commands**: If you map a skill to a command, run that command in the target project.

### Claude Code

- Mention the skill by name in your prompt: "Follow the productionize skill" or `/productionize` if configured.
- Skills in `~/.claude/skills/` apply globally; project skills apply only in that repo.

### Tips

- Run skills **in the repo you want to change** (especially `productionize` and `setup-devlog`).
- `setup-devlog` modifies the **target project** (creates `DEVLOG.md`, updates `.gitignore`, appends discipline to `CLAUDE.md`/`AGENTS.md`). Run it inside the project you want to journal, not inside this skills collection repo unless you intend to.
- `productionize` is phased: investigate → interview → plan → **your approval** → execute. Do not expect it to rewrite the repo without confirming the plan.
- `retroactive-commit-history` rewrites git history; avoid on shared branches without team agreement.

---

## Skill details

### Setup devlog

One-shot, idempotent setup of a project devlog (`DEVLOG.md`) plus agent discipline snippets so every substantive change gets a _why_-focused journal entry in the same session.

**What it creates in the target repo:**

- `DEVLOG.md` — append-only decision log (from template, with your purpose + baseline)
- `.gitignore` entry — optional; default is local-only (gitignored)
- `CLAUDE.md` / `AGENTS.md` — devlog discipline section (appended if files exist; never auto-creates)

**Workflow:** resolve repo root → create or skip `DEVLOG.md` → gitignore vs committed → inject discipline snippets → summary.

- Skill: [`skills/setup-devlog/SKILL.md`](skills/setup-devlog/SKILL.md)
- Devlog template: [`references/devlog-template.md`](skills/setup-devlog/references/devlog-template.md)
- CLAUDE.md snippet: [`references/claude-md-snippet.md`](skills/setup-devlog/references/claude-md-snippet.md)
- AGENTS.md snippet: [`references/agents-md-snippet.md`](skills/setup-devlog/references/agents-md-snippet.md)
- Entry examples: [`references/entry-examples.md`](skills/setup-devlog/references/entry-examples.md)
- Non-interactive script: [`scripts/setup.sh`](skills/setup-devlog/scripts/setup.sh)

```bash
# Install, then run in the project you want to journal
npx skills add nitin-1926/skills --skill setup-devlog -g -y
# In target repo: "set up devlog" or attach @setup-devlog

# Or scripted setup (from installed skill path)
bash ~/.cursor/skills/setup-devlog/scripts/setup.sh --dry-run
bash ~/.cursor/skills/setup-devlog/scripts/setup.sh --gitignored
```

### Productionize

The master skill for moving any repo toward production. It first **decides its path** — and when intent is unclear it grills you one question at a time (the `grill-me` discipline) before doing anything.

**Paths**:

- `audit` (default) — recon → end-state interview → parallel fan-out across dimensions → vet every finding by re-reading the cited lines → leverage-ranked findings table → self-contained `plans/`. Focus filters: `quick`, `deep`, `branch`, `next`, or a single dimension (`security`, `perf`, `tests`, …).
- `architecture` — find deepening opportunities (shallow → deep modules) using the deletion test and locality/leverage vocabulary, then grill the chosen design.
- `plan <description>` — skip the audit and spec one already-decided change.
- `execute <plan>` — dispatch a cheaper executor subagent in an isolated worktree, then review the diff like a tech lead.
- `reconcile` — refresh the backlog: verify done, unblock, retire stale findings.

Audit and plan paths never modify source; executors edit only in disposable worktrees and merging stays your call.

- Skill: [`skills/productionize/SKILL.md`](skills/productionize/SKILL.md)
- Path catalog + grilling decision tree: [`references/router.md`](skills/productionize/references/router.md)
- Repo recon → verification gates: [`references/recon.md`](skills/productionize/references/recon.md)
- Parallel audit, vetting, leverage ranking: [`references/audit.md`](skills/productionize/references/audit.md)
- Dimension checklists: [`references/dimensions.md`](skills/productionize/references/dimensions.md)
- Architecture-deepening lens: [`references/deepening.md`](skills/productionize/references/deepening.md)
- Self-contained plan artifacts: [`references/plans.md`](skills/productionize/references/plans.md)
- Execute + reconcile loops: [`references/execute.md`](skills/productionize/references/execute.md)
- Interview questions: [`references/interview.md`](skills/productionize/references/interview.md)

### God review

The most thorough code review a single command can run. Reviews the **current branch's diff** by fanning out one specialist reviewer per dimension, then surviving only what an independent validator can re-confirm — output is a ranked report that **proves what it checked**, not a wall of nitpicks. It fuses four lenses: structured persona fan-out (`/code-review`, `ce-code-review`), attacker-mindset security (`ce-security-reviewer`, `/security-review`), architecture-depth (`improve-codebase-architecture`), and ambitious maintainability "code judo" (thermo-nuclear).

**Pipeline:** scope (merge-base diff, tiered) → dispatch (always-on + warranted conditional + gap-dimension personas, in parallel) → collect (structured findings) → merge (fingerprint/dedup, cross-reviewer promotion, **late** confidence gate keeping `P0@50+`) → validate (one independent validator per survivor) → report (ranked P0–P3 tables + Coverage Ledger + Verdict).

**Modes:** `report` (default, read-only) · `--comment` (post findings on the PR via `gh`) · `--fix` (apply only `safe_auto` findings, then stop and ask — never commits).

- Skill: [`skills/god-review/SKILL.md`](skills/god-review/SKILL.md)
- Diff scoping + base resolution + tiers: [`references/diff-scope.md`](skills/god-review/references/diff-scope.md)
- Persona roster + hunt-lists + "what NOT to flag": [`references/personas.md`](skills/god-review/references/personas.md)
- Anchored confidence, merge/dedup, validator pass: [`references/confidence.md`](skills/god-review/references/confidence.md)
- Attacker-mindset security lens: [`references/security-lens.md`](skills/god-review/references/security-lens.md)
- Architecture-depth + thermo-nuclear lens: [`references/architecture-lens.md`](skills/god-review/references/architecture-lens.md)
- Output: ranked tables + Coverage Ledger + Verdict: [`references/output.md`](skills/god-review/references/output.md)

### Claude Code as a backend

Stand up an architecture where the **`claude` CLI is your backend worker** — spawned headless (`claude -p`, prompt piped via stdin) once per task — instead of calling an LLM API with a hand-built prompt+tools loop. The gold standard is the **rocketium-nexus** architecture; this skill distills it into portable invariants and maps them onto whatever stack the target project already uses.

**Routes explain → plan → scaffold** (productionize-style, with an approval gate before any source is written): confirm the pattern fits → detect the stack → map each core invariant to a concrete file → scaffold the minimal core spine → verify a real `claude -p` run lands validated state end-to-end.

**The portable invariants (the spine):** ① CLI-as-backend, not SDK · ② the server is a dumb spawner (+ watchdog) · ③ one deterministically layered system prompt · ④ deny-by-default tools/MCP/skills, resolved per run · ⑤ **model proposes, deterministic code disposes** (the model writes a file; one validating, tenant-stamping path is the only write) · ⑥ every run is a tracked row · ⑦ retry/locking live above the worker · ⑧ auth is the CLI's own login. Scheduling, workflow DAG handoff, the review/approval gate, a learning loop, multi-tenant workspaces, and a dashboard are **opt-in advanced layers**.

- Skill: [`skills/claude-code-backend/SKILL.md`](skills/claude-code-backend/SKILL.md)
- The portable invariants, in depth: [`references/invariants.md`](skills/claude-code-backend/references/invariants.md)
- Invoking `claude -p` (flags, stdin, auth, model, timeout): [`references/cli-invocation.md`](skills/claude-code-backend/references/cli-invocation.md)
- The dumb-spawner runner + watchdog + retry: [`references/runner.md`](skills/claude-code-backend/references/runner.md)
- Agent contract + layered prompt + run tracking: [`references/agent-contract.md`](skills/claude-code-backend/references/agent-contract.md)
- Model-proposes / code-disposes write path: [`references/state-and-output.md`](skills/claude-code-backend/references/state-and-output.md)
- Deny-by-default tools / MCP / skills + secrets: [`references/capabilities.md`](skills/claude-code-backend/references/capabilities.md)
- Opt-in advanced layers: [`references/advanced.md`](skills/claude-code-backend/references/advanced.md)
- Stack detection + scaffold procedure + verification: [`references/scaffold.md`](skills/claude-code-backend/references/scaffold.md)

### Retroactive commit history

Split existing or new code into multiple smaller, meaningful commits with realistic dates and author attribution.

- Skill: [`skills/retroactive-commit-history/SKILL.md`](skills/retroactive-commit-history/SKILL.md)
- Reference: [`references/reference.md`](skills/retroactive-commit-history/references/reference.md)
- Examples: [`references/examples.md`](skills/retroactive-commit-history/references/examples.md)

### Next.js app-fast

Diagnostic-first performance skill for Next.js App Router when the slowness may not be in the React. Measures the distribution before optimising, attributes latency when host logs have no route, bounds concurrency across a region, respects observed platform walls, paginates payloads without lying client-side, and designs out silent "green but did nothing" failures. Spine is a measured production field record (Amplify SSR, Prisma, Supabase, sync jobs, ~135k-row CRM); playbooks cover instrument → fan-out → counts → payload → jobs → geography → perceived/mobile → React/Next best-of.

**Workflow:** diagnose (p50/p90/p99, attribution, tail owner, platform wall) → classify → one playbook → verify same-env before/after + silent-failure check. Does not start with `memo` or a denormalised column.

- Skill: [`skills/nextjs-app-fast/SKILL.md`](skills/nextjs-app-fast/SKILL.md)
- Field record: [`references/field-record.md`](skills/nextjs-app-fast/references/field-record.md)
- Playbooks: [`references/playbooks.md`](skills/nextjs-app-fast/references/playbooks.md)

```bash
npx skills add nitin-1926/skills --skill nextjs-app-fast -g -y
# In target repo: "make this Next.js app fast" or attach @nextjs-app-fast
```

---

## Repository layout

```text
README.md
LICENSE
skills/
  setup-devlog/
    SKILL.md
    references/
      devlog-template.md
      claude-md-snippet.md
      agents-md-snippet.md
      entry-examples.md
    scripts/
      setup.sh
  productionize/
    SKILL.md
    references/
      router.md
      recon.md
      audit.md
      dimensions.md
      deepening.md
      plans.md
      execute.md
      interview.md
  god-review/
    SKILL.md
    references/
      diff-scope.md
      personas.md
      confidence.md
      security-lens.md
      architecture-lens.md
      output.md
  claude-code-backend/
    SKILL.md
    references/
      invariants.md
      cli-invocation.md
      runner.md
      agent-contract.md
      state-and-output.md
      capabilities.md
      advanced.md
      scaffold.md
  retroactive-commit-history/
    SKILL.md
    references/
      reference.md
      examples.md
  ship-npm-package/
    SKILL.md
    references/
      recon.md
      adapt.md
      npm-setup.md
      manifest.md
    assets/
      release.sh
      smoke-test.sh
      ci.yml
      release.yml
  nextjs-app-fast/
    SKILL.md
    references/
      field-record.md
      playbooks.md
```

To add a skill to this collection: create `skills/<skill-name>/SKILL.md` with YAML frontmatter (`name`, `description`, optional `metadata`), add reference files under `references/` if needed, and update this README's catalog and layout sections.

---

## Deprecated install path

The old single-skill repo is deprecated:

```bash
npx skills add nitin-1926/retroactive-commit-history   # deprecated
```

Use this collection instead:

```bash
npx skills add nitin-1926/skills --skill retroactive-commit-history
```

---

## License

MIT — see [LICENSE](LICENSE).

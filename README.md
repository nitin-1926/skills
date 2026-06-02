# Skills

Nitin's personal collection of [agent skills](https://skills.sh/) — modular instructions that teach coding agents (Cursor, Claude Code, Codex, and others) how to perform specialized workflows.

Each skill lives in its own folder under `skills/` with a `SKILL.md` entry point and optional reference files. Install one skill, several, or the whole collection.

## Skills catalog

| Skill                                                                      | What it does                                                                                                                                                                                                                                         | Invoke when you…                                                                                                         |
| -------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------ |
| [`productionize`](skills/productionize/SKILL.md)                           | Investigates any repo, interviews you on the intended end state, proposes a risk-ranked plan, then carefully removes slop, reshapes architecture, and hardens correctness, security, tests, config, and docs — with mandatory approval before edits. | Want to make a prototype production-ready, remove AI slop, clean up tech debt, or "productionize" a codebase.            |
| [`retroactive-commit-history`](skills/retroactive-commit-history/SKILL.md) | Splits a batch of changes into smaller, meaningful commits with realistic dates and author attribution.                                                                                                                                              | Need to retrofit git history, backdate or future-date commits, or build a natural commit timeline from uncommitted work. |

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

Replace `productionize` with `retroactive-commit-history` or any other skill name from `--list`.

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

- Run skills **in the repo you want to change** (especially `productionize`).
- `productionize` is phased: investigate → interview → plan → **your approval** → execute. Do not expect it to rewrite the repo without confirming the plan.
- `retroactive-commit-history` rewrites git history; avoid on shared branches without team agreement.

---

## Skill details

### Productionize

Understand any repo in any state, then carefully productionize it — remove AI slop, reshape toward the intended end state, and harden correctness, security, tests, config, and docs, all behind explicit approval gates.

**Workflow**: Investigate → interview on end state → risk-ranked plan → approved execution in small batches.

- Skill: [`skills/productionize/SKILL.md`](skills/productionize/SKILL.md)
- Dimension checklists: [`references/dimensions.md`](skills/productionize/references/dimensions.md)
- Interview questions: [`references/interview.md`](skills/productionize/references/interview.md)

### Retroactive commit history

Split existing or new code into multiple smaller, meaningful commits with realistic dates and author attribution.

- Skill: [`skills/retroactive-commit-history/SKILL.md`](skills/retroactive-commit-history/SKILL.md)
- Reference: [`references/reference.md`](skills/retroactive-commit-history/references/reference.md)
- Examples: [`references/examples.md`](skills/retroactive-commit-history/references/examples.md)

---

## Repository layout

```text
README.md
LICENSE
skills/
  productionize/
    SKILL.md
    references/
      dimensions.md
      interview.md
  retroactive-commit-history/
    SKILL.md
    references/
      reference.md
      examples.md
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

# Skills

Nitin's personal collection of agent skills.

This repo is organized as a multi-skill collection. Each skill lives in its
own folder under `skills/` and can be installed individually or all together.

## Skills

### Retroactive Commit History

Split existing or new code into multiple smaller, meaningful commits with
realistic dates and author attribution.

- Skill: [`retroactive-commit-history`](skills/retroactive-commit-history/SKILL.md)
- References: [`reference.md`](skills/retroactive-commit-history/references/reference.md)
- Examples: [`examples.md`](skills/retroactive-commit-history/references/examples.md)

## Installation

List available skills:

```bash
npx skills add nitin-1926/skills --list
```

Install one skill:

```bash
npx skills add nitin-1926/skills --skill retroactive-commit-history
```

Install all skills:

```bash
npx skills add nitin-1926/skills --all
```

Install to specific agents:

```bash
npx skills add nitin-1926/skills --skill retroactive-commit-history -a cursor -a claude-code
```

Install globally:

```bash
npx skills add nitin-1926/skills --skill retroactive-commit-history -g
```

## Repository Layout

```text
README.md
LICENSE
skills/
  retroactive-commit-history/
    SKILL.md
    references/
      reference.md
      examples.md
```

## Deprecated Install Path

The old single-skill repo path is deprecated:

```bash
npx skills add nitin-1926/retroactive-commit-history
```

Use `nitin-1926/skills` instead.

## License

MIT

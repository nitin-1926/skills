# Productionize Recon

The first phase of an `audit`. Build an accurate mental model of the repo **before forming any opinion**. Recon is read-only.

The single most important output: the **exact build / test / lint / deploy commands**. These are captured verbatim and become the verification gates in every plan (see [plans.md](plans.md)). A plan whose gates don't match the repo's real commands is not executable.

## Map the repo

- **Stack & package manager** — language(s), framework(s), and the package manager actually in use (lockfile decides: `package-lock.json` → npm, `pnpm-lock.yaml` → pnpm, `yarn.lock` → yarn, `uv.lock`/`poetry.lock` → the matching Python tool, `Cargo.lock` → cargo, `go.sum` → go).
- **Entry points** — how the app is built, run, tested, linted, and deployed. Read `package.json` scripts, `Makefile`, `justfile`, `Taskfile`, CI workflow files, and any README.
- **Conventions** — formatting, naming, error-handling style, test layout, directory structure. Note one **exemplar file** per pattern to inline into plans.
- **What works vs. scaffolding** — which flows are real and exercised vs. dead, unreachable, or placeholder code.
- **Domain language** — if `CONTEXT.md` exists, read it; its vocabulary names the seams. If `docs/adr/` (or `docs/decisions/`) exists, skim the ADRs in the area you'll touch — they record decisions not to re-litigate.

## Capture the verification gates

Record the precise commands, not paraphrases:

```
build:  <exact command>            # e.g. pnpm build
test:   <exact command>            # e.g. pnpm test, cargo test, pytest -q
lint:   <exact command>            # e.g. pnpm lint, ruff check .
types:  <exact command, if any>    # e.g. tsc --noEmit
run:    <exact command>            # e.g. pnpm dev
```

If a category has no command (no tests, no linter), record that explicitly — it is itself an audit finding for the tests / docs-CI dimensions.

## Output

Produce an **inline production-readiness snapshot**: current state per dimension with concrete findings (file paths, line refs) and the captured commands. Do not write a file unless the user asks. Do not propose fixes yet — that's the audit and plan phases.

## Scope by focus filter

- `quick` — map only the hotspots (largest / most-changed / entry-point modules); capture commands; skip exhaustive walking.
- `deep` — walk every package and capture per-package commands where they differ.
- `branch` — diff against the base branch first; scope recon to the changed files and their immediate callers.

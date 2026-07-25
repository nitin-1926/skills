# Recon

Establish these before writing anything. The answers change what the templates need.

## Commands

```bash
cat package.json
ls .github/workflows scripts 2>/dev/null
git remote get-url origin
git branch --show-current

PKG="$(node -p "require('./package.json').name")"
npm view "$PKG" version 2>/dev/null || echo "not published"
npm view "$PKG" maintainers 2>/dev/null

# What would actually ship, without publishing anything
npm pack --dry-run
```

`npm pack --dry-run` is the single most informative command here. It lists every file that would be published. Read it before touching anything else — it is where you find the `.env` that a wrong `files` field was about to publish.

## What to determine

| Question                       | How to tell                                                        | Why it matters                                                          |
| ------------------------------ | ------------------------------------------------------------------ | ----------------------------------------------------------------------- |
| Already published?             | `npm view <name> version`                                          | First publish vs. a version bump are different risk profiles            |
| Scoped package?                | Name starts with `@`                                               | Scoped packages default to private — need `--access public`             |
| Who owns the name?             | `npm view <name> maintainers`                                      | An unrelated package may already hold it                                |
| Library, CLI, or types-only?   | `bin`, `exports`, `types` fields                                   | Determines what the smoke test must assert                              |
| Build tool                     | `scripts.build` — tsup, tsc, rollup, vite, unbuild, none           | Whether `dist/` exists and what shape it has                            |
| Package manager                | Lockfile name                                                      | `npm ci` vs `pnpm i --frozen-lockfile` vs `yarn --immutable`            |
| Monorepo?                      | `workspaces`, `pnpm-workspace.yaml`, `turbo.json`                  | Changes everything — see below                                          |
| ESM, CJS, or both?             | `type`, `exports` conditions                                       | The smoke test must cover every combination actually claimed            |
| Existing CI?                   | `.github/workflows/`                                               | Extend rather than duplicate                                            |

## Package type → what the smoke test must assert

**Library** — every entry point resolves in every module system the `exports` map claims, types resolve for each subpath, and the public API is actually exported (not just the module loading).

**CLI** — the `bin` entry is executable after install, `npx <pkg> --version` works, and the shebang survived the build. A CLI whose shebang was stripped installs fine and fails on first run.

**Types-only** — `tsc` against a probe importing the real types. Runtime checks are meaningless.

**Framework plugin** (Vite, ESLint, Babel…) — load it through the host framework, not just `import()`. Plugins have shape requirements a bare import will not catch.

**Multi-entry-point package** — every subpath, in both ESM and CJS, plus types for each. This is where `exports` maps break most often, and where the failure is completely invisible to unit tests.

## Monorepos

The templates assume a single package at the repo root. In a monorepo:

- `scripts/` and the version bump move into the package directory, or the script takes a package argument.
- Building may require the whole workspace (`turbo run build --filter=<pkg>`), because a package can depend on a sibling.
- `npm pack` from a workspace can leave `workspace:*` protocol specifiers in the tarball if the publish tool does not rewrite them. Check `npm pack --dry-run` output and the packed `package.json`.
- Multiple packages releasing together usually want changesets rather than this script. If the repo already has `.changeset/`, adapt to that instead of replacing it — offer the smoke test alone.

## Red flags to raise before proceeding

- **A secret in `npm pack --dry-run` output.** Stop. Fix `files` first. If it was already published, the secret is public forever — rotate it now, no matter what `npm unpublish` claims.
- **Package name already taken by someone else.** The name must change before anything else matters.
- **No lockfile.** `npm ci` fails without one, so CI cannot be reproducible.
- **`version: 0.0.0` or `1.0.0` on an unpublished package with a long history.** Confirm the intended starting version — it is the one number nobody can change later.
- **No LICENSE file.** Publishing without one leaves consumers unable to use it legally.

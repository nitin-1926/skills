---
name: ship-npm-package
description: Sets up one-command, verifiable release automation for an npm package — a preflight-gated release.sh, a packaged-artifact smoke test that installs the real tarball, and CI + tag-triggered publish workflows with npm provenance. Use when the user says "set up publishing", "make this package publishable", "add a release script", "automate npm publish", "set up CI for this package", or is about to publish an npm package for the first time. Also use when a package publishes by hand and the user wants that made repeatable. Detects what is already in place and only adds what is missing — safe to re-run.
metadata:
  author: nitin-1926
  version: "1.0.0"
---

# Ship an npm package

Turns "publish this" from a risky manual ritual into `npm run release patch`.

## The problem this solves

Manual publishing fails in ways that are permanent. npm versions are immutable — a bad tarball cannot be replaced, only deprecated. The usual failures are all preventable by a gate:

- Published from a dirty tree, so the tarball does not match any commit.
- `exports` map broken, so `require('pkg')` fails for every consumer. Unit tests pass; nobody tested the tarball.
- Secrets or 200 MB of source shipped because `files` was wrong.
- Tag and `package.json` version disagree.
- Published from a laptop, so there is no provenance and no audit trail.

## Core principle

**Test the tarball, not the source tree.** Everything between "tests pass" and "consumers can use it" — `exports` maps, `files` globs, bundler output, type resolution — is invisible to `npm test`. The smoke test installs the real packed artifact into a throwaway project and imports it the way a consumer would.

**Stage from CI, approve with 2FA from your machine.** Trusted publishing (OIDC) means no long-lived token exists anywhere, and provenance requires an OIDC token only a cloud runner can obtain. Staging keeps the human gate: CI can stage a version, but only a person with a 2FA device can make it installable. Never build a pipeline on a 2FA-bypass publish token — npm is removing them ([details](references/npm-setup.md#the-landscape-as-of-now)).

## Workflow

Idempotent. For each step, only act if the artifact is missing or wrong. Confirm before writing.

### 1. Recon

```bash
cat package.json
ls .github/workflows scripts 2>/dev/null
git remote get-url origin
npm view "$(node -p "require('./package.json').name")" version 2>/dev/null || echo "unpublished"
```

Establish: package name, whether scoped, current version, whether already on npm, repo slug, package manager, build tool, and whether it is a library, CLI, or types-only package. See [references/recon.md](references/recon.md).

### 2. Fix the package manifest first

A release script cannot rescue a broken manifest. Verify `files`, `exports`, `types`, `engines`, `repository`, `license`, and `publishConfig` before automating anything. Checklist in [references/manifest.md](references/manifest.md).

### 3. Install the smoke test

Copy [assets/smoke-test.sh](assets/smoke-test.sh) to `scripts/`, then adapt: entry points, size budgets, and any package-specific invariant worth asserting (a CLI's `--version`, a boundary that must not be crossed). Adaptation guide in [references/adapt.md](references/adapt.md).

Run it. **It must pass before continuing** — if it fails, that is a real bug found before publishing, which is the entire point.

### 4. Install the release script

Copy [assets/release.sh](assets/release.sh) to `scripts/`, fill the placeholders at the top, `chmod +x`, and wire up:

```json
"scripts": {
	"smoke": "bash scripts/smoke-test.sh",
	"release": "bash scripts/release.sh"
}
```

Verify with `npm run release patch -- --dry-run`. It should stop before mutating anything.

### 5. Install the workflows

Copy [assets/ci.yml](assets/ci.yml) and [assets/release.yml](assets/release.yml) into `.github/workflows/`. CI runs tests plus the same smoke script; release fires on a `v*` tag, asserts tag/version parity, and stages the package via OIDC. No `NPM_TOKEN` anywhere.

### 6. One-time account setup

Trusted publisher (stage-only), "disallow tokens", scoped-package access, and the manual bootstrap publish that a brand-new package unavoidably needs. Walk the user through [references/npm-setup.md](references/npm-setup.md) — these are actions only they can take.

### 7. Report

State what was added, what the user must do themselves, and the exact first release command. Never run `git commit`, `git tag`, `git push`, or `npm publish` without an explicit instruction.

## Keeping the copies in sync

These are templates, so every project gets its own copy and they drift. When you fix a bug in one, port it — a fix that lives in only one copy is how a known bug ships again. `nitin-1926/UpLifty` is the reference implementation: its `scripts/` and `.github/workflows/` are the most-exercised version of these files.

## Guardrails

- **Never publish or push without being told to.** This skill sets up the machinery; the user pulls the trigger.
- **Never weaken a gate to make a release pass.** A failing smoke test is a finding, not an obstacle.
- **Never write credentials to a file.** Tokens go in CI secrets or an interactive `npm login`.
- **If the package is already published**, check for breaking changes and get the semver bump right before anything else — see [references/manifest.md](references/manifest.md#versioning).

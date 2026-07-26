# npm account setup

Actions only the user can take. Walk them through it; never do these silently, and never write a token to a file.

## The landscape, as of now

npm is actively removing long-lived publish tokens from the ecosystem. Granular access tokens with "bypass 2FA" — the thing CI/CD used to need — are on a deprecation path:

| When          | What happens to 2FA-bypass tokens                                                     |
| ------------- | -------------------------------------------------------------------------------------- |
| ~August 2026  | Lose sensitive account, package, and org actions (token/settings/access/member changes)  |
| ~January 2027 | Lose direct publishing. Reduced to staging a publish that a human must then approve      |

Classic token creation is already disabled. **Do not build a release pipeline on a publish token.** It will break, and npm's own UI now warns you while you create one.

## The options, ranked

| Option                                                 | Long-lived token | Human 2FA gate | Provenance | Survives the deprecation |
| ------------------------------------------------------ | ---------------- | -------------- | ---------- | ------------------------ |
| **Trusted publishing, stage-only + `npm stage approve`** | none             | yes            | **yes**    | yes                      |
| Trusted publishing, direct publish                       | none             | no             | yes        | yes                      |
| Local `npm publish` with interactive OTP                 | none in CI       | yes            | **no**     | yes                      |
| GAT with bypass-2FA in CI                                | yes              | no             | yes        | **no**                   |

**Default to the first row.** It is the only one with every property. The instinct to "just publish from my machine so I control the 2FA" is right about the gate and wrong about the mechanism — staged publishing gives the same human gate *and* keeps provenance.

## How staged publishing works

```
CI (OIDC, no token)          You (2FA device)              Registry
  npm stage publish  ──────►  staging queue
                              npm stage approve  ─────────►  live
```

- `npm stage publish` needs no 2FA — that is what makes it safe for CI.
- `npm stage approve` **requires 2FA** and **cannot be done with an OIDC token**. Approval is deliberately human-only, via the CLI or npmjs.com.
- Until approved, nothing is installable. A compromised workflow can stage a malicious version; it cannot ship one.
- Provenance is generated automatically when staging via trusted publishing from a public repo — do not pass `--provenance`.

Commands: `npm stage publish` · `list` · `view` · `approve` · `reject` · `download`. Requires npm 11+ (`npm stage --help` to check).

## Setup

### 1. First publish — manual, once

A trusted publisher is configured in the *package's* npm settings, which do not exist until the package does. So the very first release bootstraps by hand:

```bash
npm login                      # interactive, 2FA prompt
npm run smoke                  # the gate — must be green
npm publish --access public    # prompts for your 2FA code
```

Or `scripts/release.sh <version> --local-publish`, which does the same inside the full preflight.

**That one version has no provenance.** Unavoidable — provenance requires an OIDC token only a cloud CI runner can obtain. Every subsequent release gets it.

### 2. Configure the trusted publisher

npmjs.com → your package → **Settings** → **Trusted Publisher** → **GitHub Actions**:

- **Repository**: `owner/repo`
- **Workflow filename**: `release.yml` (the filename, not a path)
- **Allowed actions**: **`npm stage publish` only** — leave `npm publish` unchecked

That last field is the whole security posture. Allowing only staging means CI physically cannot ship without you.

### 3. Lock out tokens

npmjs.com → package → **Settings** → **Publishing access** → **"Require two-factor authentication and disallow tokens"**.

This does not affect trusted publishing, which uses OIDC rather than token auth. It does mean no token, stolen or otherwise, can publish this package.

### 4. Delete any NPM_TOKEN

```bash
gh secret delete NPM_TOKEN --repo owner/repo
```

Then revoke it on npmjs.com → **Access Tokens**. A secret you no longer use is still a secret that can leak.

## Per-release flow after that

```bash
npm run release patch
```

The script bumps, verifies, tags, pushes, watches CI stage the package, then prompts for the stage id and runs `npm stage approve` — npm asks for your 2FA code. Approve on npmjs.com instead if you prefer.

## Other account settings

**Two-factor authentication**: npmjs.com → **Account** → **Two-Factor Authentication** → enable for **Authorization and Publishing**. Required for approvals to mean anything.

**Scoped packages** (`@scope/name`) default to private and fail the first publish with a paywall error that does not explain itself:

```json
"publishConfig": { "access": "public" }
```

**Verify the name is available** before writing the README: `npm view <name>` → `404` means free. npm blocks names too similar to existing packages and permanently blocks names of unpublished ones.

## Recovery

| Situation                            | What to do                                                                                       |
| ------------------------------------ | ------------------------------------------------------------------------------------------------ |
| Staged a bad version                 | `npm stage reject <stage-id>` — nothing was ever installable. This is the gate working            |
| Published a broken version           | Publish a fixed patch, then `npm deprecate` the broken one. Unpublishing is almost never possible |
| Published a secret                   | **Rotate it immediately.** It is public permanently, regardless of what you do to the package     |
| Tag pushed but CI failed             | Fix, `git push --delete origin vX.Y.Z`, delete the local tag, re-run the release                  |
| Wrong version number published       | Nothing to undo — npm versions are immutable. Publish the intended one next                       |
| Approval failed midway               | The version is still staged. Retry `npm stage approve <stage-id>`                                 |

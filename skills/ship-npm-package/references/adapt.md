# Adapting the templates

Copy from `assets/`, then make these edits. Nothing here is optional — a template run unmodified asserts almost nothing.

## `release.sh`

Fill the CONFIGURATION block:

```bash
readonly REPO_SLUG="nitin-1926/UpLifty"
readonly NPM_PACKAGE="uplifty"
readonly DEFAULT_BRANCH="main"
```

Then adjust `run_project_checks()` to the project's real scripts. If there is no linter, drop the lint line rather than leaving a call that fails.

**Other package managers:**

```bash
# pnpm
write_version() { pnpm version "$1" --no-git-tag-version >/dev/null; }
# and in commit_tag_push: git add package.json pnpm-lock.yaml

# yarn berry
write_version() { yarn version "$1" --no-git-tag-version >/dev/null; }
```

**Want CI to publish directly instead of staging?** Swap `npm stage publish` for `npm publish` in `release.yml`, allow that action on the trusted publisher, and replace `wait_for_staged_release` with a plain `confirm_live` call. You keep provenance and zero tokens; you lose the human 2FA gate. Only worth it for a package where releases are frequent and low-risk.

Then:

```bash
chmod +x scripts/release.sh scripts/smoke-test.sh
# chmod alone is NOT enough. Git stores the exec bit itself, and a file already
# committed as 100644 stays 100644 no matter what the local filesystem says - so
# the scripts land un-executable on the CI runner and the "Scripts are
# executable" gate fails on a tree that works fine locally.
git update-index --chmod=+x scripts/release.sh scripts/smoke-test.sh
git ls-files -s scripts/          # both must read 100755, not 100644

npm run release patch -- --dry-run    # must stop before mutating anything
```

## `smoke-test.sh`

This is the one that matters, and the one people leave generic. A smoke test that only checks "the module loads" catches almost nothing.

### 1. Size budgets

```bash
SIZE_BUDGETS=(
  "dist/index.js:4500"
  "dist/server/index.js:5500"
)
```

Measure first, then set the ceiling ~20% above:

```bash
gzip -9 -c dist/index.js | wc -c
```

Budgets exist so an accidental dependency fails the build rather than quietly tripling what consumers download. Raise them deliberately, in a commit that says why.

### 2. Entry points — import the real API

The template's probe only checks that the module loads. Replace it with the actual public surface:

```bash
node --input-type=module -e "
  import { Uplifty, UpliftyError } from '$PKG_NAME';
  import { S3, R2 } from '$PKG_NAME/server';
  const missing = Object.entries({ Uplifty, UpliftyError, S3, R2 })
    .filter(([, v]) => typeof v !== 'function')
    .map(([k]) => k);
  if (missing.length) { console.error('not exported:', missing.join(', ')); process.exit(1); }
"
```

Naming each expected export means a rename shows up here, in a message that says which one.

### 3. Type probe — exercise the types

The template's probe imports a default and returns it, which proves nothing. Write one that uses the API the way a consumer will:

```ts
import { Uplifty, type UploadResult } from 'pkg';
import { S3 } from 'pkg/server';

const client: Uplifty = new Uplifty({ getTicket: '/api/upload' });
const store = new S3({ accessKeyId: 'a', secretAccessKey: 'b', region: 'c', bucket: 'd' });

export const check = async (file: File): Promise<UploadResult> => {
	await store.createUploadTicket({ fileName: file.name, contentType: file.type, size: file.size });
	return client.upload(file);
};
```

If a required option disappears or a return type changes, `tsc` fails here — before consumers find out.

### 4. Package-specific invariants

The highest-value checks are the ones only this package needs. Some patterns:

**A boundary that must hold.** If part of the package must never reach a browser bundle:

```bash
if grep -qE 'aws4_request|secretAccessKey' dist/index.js; then
  fail "server code leaked into the browser entry point"
else
  pass "browser entry point is clean"
fi
```

Always pair it with the inverse — assert the server bundle *does* contain the signer — or deleting the code entirely makes the first check pass.

**A CLI actually runs:**

```bash
(cd "$CONSUMER" && npx "$PKG_NAME" --version >/dev/null 2>&1) \
  && pass "the bin entry runs" || fail "the bin entry does not run"
```

Catches a stripped shebang and a missing `bin` in `files`, both of which install cleanly and fail on first use.

**Correctness survived the build.** If the package does something verifiable — signing, parsing, formatting — run one known-good case against the *packaged* artifact. A minifier mangling a crypto path is not hypothetical.

**Zero dependencies, if that is a promise you make:**

```bash
[[ "$dep_count" == "0" ]] && pass "zero runtime dependencies" \
  || fail "expected 0 runtime dependencies, found $dep_count"
```

### 5. Run it

```bash
npm run smoke
```

**It must pass before you continue.** A failure here is a real bug found before publishing — which is the whole point of the gate. Never weaken a check to make it green.

## The workflows

- Match the Node matrix to `engines`. Testing only Node 22 while claiming `>=18` is an unverified promise.
- Adjust script names in both files.
- If the repo already has a CI workflow, add the `smoke` job to it rather than adding a second workflow.
- Non-npm package managers need their setup action and install command changed in both files.

## Sanity check the whole thing

```bash
bash -n scripts/release.sh && bash -n scripts/smoke-test.sh   # syntax
npm run smoke                                                 # the real gate
npm run release patch -- --dry-run                            # preflight, no mutation
```

The dry run should report the plan and stop. If it gets further, something is wrong with the guard.

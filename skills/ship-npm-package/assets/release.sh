#!/usr/bin/env bash
# Release script — version bump, verify, tag, and watch CI publish.
#
# TEMPLATE: fill in the CONFIGURATION block below, then delete this line.
#
# Usage:
#   scripts/release.sh <patch|minor|major|X.Y.Z> [flags]
#
# What this does (in order):
#   1. Preflight: tooling present; clean tree; on the default branch; in sync
#      with origin; gh authenticated; tag unused; version not already on npm.
#   2. Bumps package.json + lockfile.
#   3. Verifies: the project's own checks, then the packaged-artifact smoke test.
#   4. Commits "chore: release vX.Y.Z", tags, pushes both.
#   5. Watches the release workflow, which STAGES the package.
#   6. Walks you through approving the staged version with your 2FA.
#
# THIS SCRIPT DOES NOT PUBLISH, and that is deliberate. The tag push triggers
# the release workflow, which runs `npm stage publish` via trusted publishing
# (OIDC); you approve with 2FA from your own machine. Do not "fix" a CI failure
# by running `npm publish` here: provenance needs an OIDC token only a cloud
# runner can get, so a local publish silently ships an unverifiable tarball.
# Full reasoning, and the --local-publish escape hatch: references/npm-setup.md.

set -euo pipefail

# ─────────────────────────────────────────────────────────────────────────────
# CONFIGURATION — fill these in
# ─────────────────────────────────────────────────────────────────────────────

readonly REPO_SLUG="OWNER/REPO"          # e.g. nitin-1926/UpLifty
readonly NPM_PACKAGE="PACKAGE_NAME"      # e.g. uplifty, or @scope/name
readonly DEFAULT_BRANCH="main"
readonly RELEASE_WORKFLOW="release.yml"
readonly RELEASE_WAIT_TIMEOUT=900        # seconds

# Commands run before tagging. Adjust to the project's actual scripts.
run_project_checks() {
  npm run typecheck --silent
  ok "typecheck green"
  npm run lint --silent
  ok "lint green"
  npm test --silent
  ok "tests green"
}

# ─────────────────────────────────────────────────────────────────────────────
# UI helpers
# ─────────────────────────────────────────────────────────────────────────────

if [[ -t 1 ]]; then
  C_RED="$(printf '\033[31m')"; C_GREEN="$(printf '\033[32m')"
  C_YELLOW="$(printf '\033[33m')"; C_BLUE="$(printf '\033[34m')"
  C_CYAN="$(printf '\033[36m')"; C_BOLD="$(printf '\033[1m')"
  C_RESET="$(printf '\033[0m')"
else
  C_RED="" C_GREEN="" C_YELLOW="" C_BLUE="" C_CYAN="" C_BOLD="" C_RESET=""
fi

step()  { printf '\n%s▸%s %s%s%s\n' "$C_BLUE" "$C_RESET" "$C_BOLD" "$1" "$C_RESET"; }
info()  { printf '  %s\n' "$1"; }
ok()    { printf '  %s✓%s %s\n' "$C_GREEN" "$C_RESET" "$1"; }
warn()  { printf '  %s!%s %s\n' "$C_YELLOW" "$C_RESET" "$1"; }
fatal() { printf '\n%s✗ %s%s\n' "$C_RED" "$1" "$C_RESET" >&2; exit 1; }
confirm() {
  [[ "$ASSUME_YES" == "1" ]] && return 0
  printf '  %s?%s %s [y/N] ' "$C_CYAN" "$C_RESET" "$1"
  local ans; read -r ans
  [[ "$ans" =~ ^[Yy]$ ]]
}

# ─────────────────────────────────────────────────────────────────────────────
# Arg parsing
# ─────────────────────────────────────────────────────────────────────────────

usage() {
  cat <<EOF
Usage: $(basename "$0") <patch|minor|major|X.Y.Z> [flags]

Flags:
  --dry-run       Print planned actions. Changes nothing.
  --local-publish Publish from this machine with an interactive 2FA prompt
                  instead of letting CI stage it. First publish only. No provenance.
  --skip-tests    Skip verification. Use only when CI already proved this commit.
  --stash         Auto-stash uncommitted changes for the release, pop on exit.
  --allow-dirty   Release with a dirty tree (uncommitted changes will NOT ship).
  -y, --yes       Skip the confirmation prompt.
  -h, --help      Show this help.
EOF
}

[[ $# -eq 0 ]] && { usage; exit 1; }

BUMP=""; DRY_RUN=0; SKIP_TESTS=0; ALLOW_DIRTY=0; AUTO_STASH=0; ASSUME_YES=0; LOCAL_PUBLISH=0
# UTC stamp taken immediately before the tag push, so the run watcher can tell
# our run apart from an earlier run on the same commit. See push_all.
PUSH_STARTED_AT=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    -h|--help) usage; exit 0 ;;
    --dry-run) DRY_RUN=1 ;;
    --local-publish) LOCAL_PUBLISH=1 ;;
    --skip-tests) SKIP_TESTS=1 ;;
    --stash) AUTO_STASH=1 ;;
    --allow-dirty) ALLOW_DIRTY=1 ;;
    -y|--yes) ASSUME_YES=1 ;;
    patch|minor|major) [[ -z "$BUMP" ]] || fatal "version given twice"; BUMP="$1" ;;
    v[0-9]*) fatal "drop the leading v: use ${1#v}, not $1" ;;
    [0-9]*)
      # The case pattern is a glob, so it also matches 1.2.3-beta and 1abc.2.3.
      [[ "$1" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || fatal "not a plain semver version: $1"
      [[ -z "$BUMP" ]] || fatal "version given twice"
      BUMP="$1" ;;
    *) fatal "unknown argument: $1" ;;
  esac
  shift
done

[[ -n "$BUMP" ]] || { usage; exit 1; }
[[ "$AUTO_STASH" == "1" && "$ALLOW_DIRTY" == "1" ]] && fatal "--stash and --allow-dirty are mutually exclusive"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$REPO_ROOT"

readonly STASH_LABEL="release-autostash-$$"
STASH_PUSHED=0

pop_stash_on_exit() {
  local exit_code=$?
  [[ "$STASH_PUSHED" == "1" ]] || exit "$exit_code"
  echo; step "Restoring stashed changes"
  local stash_ref
  stash_ref="$(git stash list --format='%gd %s' | awk -v l="$STASH_LABEL" '$0 ~ l {print $1; exit}')"
  if [[ -z "$stash_ref" ]]; then
    warn "could not find the auto-stash ($STASH_LABEL)"; exit "$exit_code"
  fi
  if git stash pop --index "$stash_ref" 2>&1; then
    ok "restored working tree from $stash_ref"
  else
    warn "stash pop had conflicts — your work is safe in $stash_ref"
  fi
  exit "$exit_code"
}

# ─────────────────────────────────────────────────────────────────────────────
# Version helpers
# ─────────────────────────────────────────────────────────────────────────────

current_version() { node -p "require('./package.json').version"; }

bump_semver() {
  local cur="$1" level="$2"
  if [[ "$level" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then printf '%s' "$level"; return; fi
  local major minor patch
  IFS='.' read -r major minor patch <<<"$cur"
  case "$level" in
    patch) patch=$((patch + 1)) ;;
    minor) minor=$((minor + 1)); patch=0 ;;
    major) major=$((major + 1)); minor=0; patch=0 ;;
    *) fatal "invalid bump level: $level" ;;
  esac
  printf '%d.%d.%d' "$major" "$minor" "$patch"
}

# `npm version` without git side effects. Updates package.json AND the lockfile,
# which a hand-rolled sed would leave stale.
write_version() { npm version "$1" --no-git-tag-version --allow-same-version >/dev/null; }

# ─────────────────────────────────────────────────────────────────────────────
# Preflight
# ─────────────────────────────────────────────────────────────────────────────

preflight() {
  step "Preflight checks"

  for tool in git node npm gh; do
    command -v "$tool" >/dev/null 2>&1 || fatal "$tool is not installed or not on PATH"
  done
  ok "git, node, npm, gh are installed"

  [[ -d .git ]] || fatal "not a git repo"
  ok "inside a git repo ($REPO_ROOT)"

  local node_major
  node_major="$(node -p "process.versions.node.split('.')[0]")"
  (( node_major >= 18 )) || fatal "node >= 18 required, found $(node --version)"
  ok "node $(node --version)"

  local branch; branch="$(git rev-parse --abbrev-ref HEAD)"
  [[ "$branch" == "$DEFAULT_BRANCH" ]] \
    || fatal "currently on '$branch'; release must be cut from '$DEFAULT_BRANCH'"
  ok "on branch $DEFAULT_BRANCH"

  if [[ -n "$(git status --porcelain)" ]]; then
    if [[ "$AUTO_STASH" == "1" ]]; then
      info "working tree is dirty; stashing for the release..."
      git stash push --include-untracked --message "$STASH_LABEL" >/dev/null \
        || fatal "git stash push failed"
      STASH_PUSHED=1; trap pop_stash_on_exit EXIT
      ok "stashed uncommitted changes"
      [[ -z "$(git status --porcelain)" ]] || fatal "tree still dirty after stash"
    elif [[ "$ALLOW_DIRTY" == "1" ]]; then
      warn "working tree is dirty; --allow-dirty set (uncommitted changes will NOT ship)"
    else
      git status --short >&2
      fatal "working tree is not clean — commit what you want to release, then re-run with --stash"
    fi
  else
    ok "working tree is clean"
  fi

  info "fetching origin..."
  git fetch origin --tags --quiet
  [[ "$(git rev-parse HEAD)" == "$(git rev-parse "origin/$DEFAULT_BRANCH")" ]] \
    || fatal "local $DEFAULT_BRANCH is not in sync with origin/$DEFAULT_BRANCH; pull/push first"
  ok "in sync with origin/$DEFAULT_BRANCH"

  gh auth status >/dev/null 2>&1 || fatal "gh CLI is not authenticated — run 'gh auth login'"
  ok "gh CLI is authenticated as $(gh api user --jq '.login' 2>/dev/null || echo '?')"

  # `npm stage` arrived in npm 11. Without it there is no way to approve what CI
  # stages, so the release would complete and then strand the version.
  if npm stage --help >/dev/null 2>&1; then
    ok "npm $(npm --version) supports 'npm stage'"
  else
    fatal "this npm ($(npm --version)) has no 'npm stage' subcommand — upgrade with 'npm i -g npm@latest'"
  fi

  # Approving a staged version, and publishing locally, both need an interactive
  # npm session. CI needs no token: it authenticates with a short-lived OIDC token.
  # Hard failure, not a warning. The flow ends in `npm stage approve`, which
  # needs an authenticated session - warning here lets a release tag, push and
  # stage, then strand with no way to finish it.
  local npm_user
  if npm_user="$(npm whoami 2>/dev/null)"; then
    ok "npm logged in as $npm_user"
  else
    warn "a stale token in ~/.npmrc is sent and rejected before any prompt appears,"
    warn "so 'npm login' can look like it worked while 'npm whoami' still 401s. If so:"
    warn "  npm config delete //registry.npmjs.org/:_authToken && npm login"
    fatal "not logged in to npm — 'npm whoami' failed"
  fi

  [[ -f package.json ]] || fatal "missing package.json"
  ok "package.json present"
}

check_changelog() {
  local new="$1"
  [[ -f CHANGELOG.md ]] || { warn "no CHANGELOG.md"; return; }
  if grep -qE "^#+ +\[?v?${new//./\\.}\]?" CHANGELOG.md; then
    ok "CHANGELOG.md has a section for $new"
  else
    warn "CHANGELOG.md has no section for $new"
    confirm "continue anyway?" || fatal "aborted; add the changelog entry first"
  fi
}

check_tag_unused() {
  local tag="$1"
  git rev-parse "$tag" >/dev/null 2>&1 && fatal "tag $tag already exists locally"
  git ls-remote --exit-code --tags origin "$tag" >/dev/null 2>&1 && fatal "tag $tag exists on origin"
  gh release view "$tag" --repo "$REPO_SLUG" >/dev/null 2>&1 && fatal "GitHub release $tag already exists"
  ok "tag $tag is unused"
}

check_version_unpublished() {
  local new="$1" published
  published="$(npm view "$NPM_PACKAGE@$new" version 2>/dev/null || true)"
  [[ -z "$published" ]] \
    || fatal "$NPM_PACKAGE@$new is already on npm — versions are immutable, pick a new one"
  ok "$NPM_PACKAGE@$new is not yet on npm"
}

# ─────────────────────────────────────────────────────────────────────────────
# Verification
# ─────────────────────────────────────────────────────────────────────────────

# Undo the version bump. Verification failing is the likeliest failure in the
# whole script, and by then package.json and the lockfile are already mutated.
restore_version() { git checkout -- package.json package-lock.json 2>/dev/null || true; }

run_verification() {
  if [[ "$SKIP_TESTS" == "1" ]]; then warn "skipping verification (--skip-tests)"; return; fi

  step "Verification"
  trap 'restore_version' ERR
  run_project_checks
  trap - ERR

  # The packaged-artifact gate: builds, packs, installs the tarball into a
  # throwaway consumer, and asserts the entry points, types, and any
  # package-specific invariant survived the build. Catches the class of bug
  # unit tests structurally cannot — a broken `exports` map ships green.
  info "scripts/smoke-test.sh"
  local smoke_log; smoke_log="$(mktemp)"
  if bash "$SCRIPT_DIR/smoke-test.sh" >"$smoke_log" 2>&1; then
    ok "packaged smoke test green ($(grep -oE '[0-9]+ passed' "$smoke_log" | head -1))"
    rm -f "$smoke_log"
  else
    printf '%s\n' "----- smoke test output -----" >&2
    cat "$smoke_log" >&2; rm -f "$smoke_log"
    restore_version
    fatal "packaged smoke test FAILED — aborting. Debug with: scripts/smoke-test.sh"
  fi
}

# ─────────────────────────────────────────────────────────────────────────────
# Commit, tag, push, watch
# ─────────────────────────────────────────────────────────────────────────────

commit_and_tag() {
  local tag="v$1"
  step "Committing and tagging"
  git add package.json package-lock.json 2>/dev/null || git add package.json
  # An explicit version equal to the current one is a legitimate case — the very
  # first release of a package whose version was set by hand. There is then
  # nothing to commit, and `git commit` would exit non-zero and abort the run.
  if git diff --cached --quiet; then
    info "version is already $1 — nothing to commit, tagging HEAD as-is"
  else
    git commit -m "chore: release $tag"; ok "committed"
  fi
  git tag -a "$tag" -m "$NPM_PACKAGE $tag"; ok "tagged $tag (local only so far)"
}

push_all() {
  local tag="v$1"
  step "Pushing"
  # Both pushes carry an undo. Branch protection, or someone else pushing between
  # the preflight fetch and now, would otherwise abort with a bare git error and
  # a local commit plus tag that block every re-run.
  git push origin "$DEFAULT_BRANCH" || { warn "undo: git tag -d $tag && git reset --hard origin/$DEFAULT_BRANCH"; fatal "could not push $DEFAULT_BRANCH"; }
  ok "pushed $DEFAULT_BRANCH"
  # Stamped before the push that triggers the workflow. The documented recovery
  # for a failed release is to delete and re-push the tag, which produces
  # several runs sharing one commit - so the SHA alone cannot identify ours.
  # 60 seconds of slack absorbs clock skew. GNU date first, BSD/macOS second.
  PUSH_STARTED_AT="$(date -u -d '-60 seconds' +%Y-%m-%dT%H:%M:%SZ 2>/dev/null \
    || date -u -v-60S +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || true)"
  git push origin "$tag" || { warn "undo: git tag -d $tag"; fatal "could not push $tag"; }
  ok "pushed $tag — CI takes over from here"
}

confirm_live() {
  local new="$1" elapsed=0
  info "polling the npm registry (timeout: ${RELEASE_WAIT_TIMEOUT}s)..."
  while (( elapsed < RELEASE_WAIT_TIMEOUT )); do
    if [[ "$(npm view "$NPM_PACKAGE@$new" version 2>/dev/null || true)" == "$new" ]]; then
      echo; ok "npm confirms $NPM_PACKAGE@$new is live"; return 0
    fi
    sleep 10; elapsed=$((elapsed + 10)); printf '.'
  done
  echo; warn "timed out (the registry may just be catching up)"; return 1
}

# Bootstrap path only. A brand-new package cannot use trusted publishing: the
# trusted publisher lives in the package's npm settings, which do not exist
# until the package does.
publish_locally() {
  local new="$1"
  step "Publishing from this machine"
  warn "no provenance on this version — provenance requires an OIDC token only CI can obtain"
  info "npm will prompt for your 2FA code"
  # --no-provenance is mandatory if package.json sets publishConfig.provenance:
  # that forces npm to demand a CI OIDC provider and abort with EUSAGE off a
  # runner, so without this flag the whole --local-publish path cannot work.
  npm publish --access public --no-provenance || fatal "npm publish failed"
  ok "published $NPM_PACKAGE@$new"
  confirm_live "$new" || true

  step "Do this next, once"
  info "Now that the package exists, switch off local publishing for good:"
  info "  1. npmjs.com → $NPM_PACKAGE → Settings → Trusted Publisher"
  info "     → GitHub Actions, repo $REPO_SLUG, workflow 'release.yml'"
  info "     → Allowed actions: 'npm stage publish' ONLY"
  info "  2. Settings → Publishing access → 'Require two-factor authentication and disallow tokens'"
}

wait_for_staged_release() {
  local new="$1" tag="v$1"

  step "Waiting for the Release workflow"
  info "the tag push triggers '$RELEASE_WORKFLOW', which stages the package via OIDC"
  sleep 5

  # Poll for the run belonging to THIS push. A flat `--limit 1` returned the
  # PREVIOUS release's run whenever GitHub had not created ours yet, so
  # `gh run watch` exited 0 instantly and reported a success that never happened.
  #
  # Matching on headSha alone is not enough either. Deleting and re-pushing a
  # tag is the documented recovery, and it re-points the tag at the SAME commit
  # - so a stale, already-failed run matches immediately and the loop breaks on
  # it before our run is even created. That inverts the outcome: it reports a
  # failure for a release that in fact succeeded. Require the run to have been
  # created after the push, so nothing that predates it can match.
  local head_sha run_id=''
  head_sha="$(git rev-parse HEAD)"
  local since="${PUSH_STARTED_AT:-}"
  if [[ -z "$since" ]]; then
    warn "no push timestamp recorded; falling back to matching on commit alone"
    since="0000"  # sorts before every ISO-8601 stamp, so the filter is a no-op
  fi
  for _ in $(seq 1 30); do
    run_id="$(gh run list --workflow="$RELEASE_WORKFLOW" --limit 20 \
      --json databaseId,headSha,createdAt \
      --jq "[.[] | select(.headSha==\"$head_sha\" and .createdAt >= \"$since\")][0].databaseId" 2>/dev/null || true)"
    [[ -n "$run_id" && "$run_id" != "null" ]] && break
    sleep 5
  done
  if [[ -n "$run_id" && "$run_id" != "null" ]]; then
    info "found workflow run $run_id — streaming..."
    gh run watch "$run_id" --exit-status \
      || fatal "release workflow failed — 'gh run view $run_id --log-failed', then fix, 'git push --delete origin $tag', re-run"
    ok "workflow succeeded — $NPM_PACKAGE@$new is STAGED, not yet installable"
  else
    warn "couldn't locate the workflow run; check it manually before approving"
  fi

  step "Approve the staged version"
  info "This is the 2FA gate. Nothing is installable until you approve it."
  echo
  npm stage list "$NPM_PACKAGE" 2>&1 || warn "run 'npm stage list $NPM_PACKAGE' yourself"
  echo

  # The stage id is read, not parsed out of the listing above: `npm stage list`
  # is a human-facing format, and guessing at it would break silently the first
  # time npm reformats it.
  if [[ "$ASSUME_YES" == "1" ]]; then
    warn "-y given; not approving automatically — approval is a deliberate human step"
    info "approve with: npm stage approve <stage-id>"
    return 0
  fi

  printf '  %s?%s stage-id to approve (empty to skip and approve later): ' "$C_CYAN" "$C_RESET"
  # `|| true` because a bare `read` returns 1 at EOF, and under `set -e` that
  # killed the script silently right after the package was staged.
  local stage_id=''; read -r stage_id || true

  if [[ -z "$stage_id" ]]; then
    warn "skipped — $NPM_PACKAGE@$new is staged but NOT published"
    info "approve later: npm stage approve <stage-id>   |   discard: npm stage reject <stage-id>"
    return 0
  fi

  info "npm will prompt for your 2FA code"
  npm stage approve "$stage_id" \
    || fatal "approval failed — still staged; retry 'npm stage approve $stage_id'"
  ok "approved"
  confirm_live "$new" || true
}

# ─────────────────────────────────────────────────────────────────────────────
# Main
# ─────────────────────────────────────────────────────────────────────────────

main() {
  preflight

  local cur new tag
  cur="$(current_version)"; new="$(bump_semver "$cur" "$BUMP")"; tag="v$new"

  step "Plan"
  info "current version : $C_BOLD$cur$C_RESET"
  info "new version     : $C_BOLD$C_GREEN$new$C_RESET"
  info "tag             : $C_BOLD$tag$C_RESET"
  info "skip tests      : $( [[ $SKIP_TESTS == 1 ]] && echo yes || echo no )"
  info "dry run         : $( [[ $DRY_RUN    == 1 ]] && echo yes || echo no )"
  if [[ "$LOCAL_PUBLISH" == "1" ]]; then
    info "publishes via   : ${C_YELLOW}this machine, interactive 2FA, NO provenance${C_RESET}"
  else
    info "publishes via   : CI stages it (OIDC, provenance), you approve with 2FA"
  fi

  check_tag_unused "$tag"
  check_version_unpublished "$new"
  check_changelog "$new"

  [[ "$DRY_RUN" == "1" ]] && { warn "dry run — stopping before any mutation"; exit 0; }

  confirm "proceed with release $tag?" || fatal "aborted by user"

  step "Bumping version"
  write_version "$new"; ok "wrote $new to package.json"

  run_verification
  commit_and_tag "$new"

  if [[ "$LOCAL_PUBLISH" == "1" ]]; then
    # Publish BEFORE pushing the tag. The tag push triggers the Release
    # workflow, which skips staging when the version is already on the registry
    # — so this order turns what would be a guaranteed failed run into a green
    # one that still cuts the GitHub release. It also means a failed publish
    # leaves the tag local and trivially undoable.
    publish_locally "$new"
    push_all "$new"
  else
    push_all "$new"
    wait_for_staged_release "$new"
  fi

  step "Done"
  ok "$NPM_PACKAGE $tag tagged and released"
  info "github : https://github.com/$REPO_SLUG/releases/tag/$tag"
  info "npm    : https://www.npmjs.com/package/$NPM_PACKAGE/v/$new"
}

main "$@"

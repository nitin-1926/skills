#!/usr/bin/env bash
#
# Packaged-artifact smoke test
# ============================
# TEMPLATE: adapt the CONFIGURATION block and the package-specific checks at the
# bottom, then delete this line.
#
# Everything here tests the TARBALL, not the source tree. `npm test` already
# covers the source; this covers the thing consumers actually install — which is
# where `exports` maps, `files` globs, and bundler output go wrong silently.
#
# Usage:
#   scripts/smoke-test.sh [--skip-build]
#
# Exit code 0 = all checks passed. Runs every check before reporting, so one
# failure does not hide the others.

set -uo pipefail   # NOT -e: we want the full report, not the first failure.

SKIP_BUILD=0
for arg in "$@"; do
  case "$arg" in
    --skip-build) SKIP_BUILD=1 ;;
    -h|--help) grep '^#' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "unknown flag: $arg (try --help)"; exit 2 ;;
  esac
done

# ─────────────────────────────────────────────────────────────────────────────
# CONFIGURATION
# ─────────────────────────────────────────────────────────────────────────────

# Gzipped byte budgets per built entry point: "path:budget". Ceilings, not
# targets — the point is that a dependency sneaking in fails the build instead
# of quietly tripling what every consumer downloads. Raise deliberately.
SIZE_BUDGETS=(
  "dist/index.js:20000"
)

# Extra peer/optional deps the sandbox consumer needs to load every entry point.
EXTRA_INSTALL=()

# ─────────────────────────────────────────────────────────────────────────────

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="$(dirname "$SCRIPT_DIR")"
cd "$REPO"

if [[ -t 1 ]]; then
  C_RED="$(printf '\033[31m')"; C_GREEN="$(printf '\033[32m')"
  C_BOLD="$(printf '\033[1m')"; C_RESET="$(printf '\033[0m')"
else
  C_RED="" C_GREEN="" C_BOLD="" C_RESET=""
fi

PASSED=0; FAILED=0
pass() { PASSED=$((PASSED + 1)); printf '  %s✓%s %s\n' "$C_GREEN" "$C_RESET" "$1"; }
fail() { FAILED=$((FAILED + 1)); printf '  %s✗%s %s\n' "$C_RED" "$C_RESET" "$1"; }
step() { printf '\n%s%s%s\n' "$C_BOLD" "$1" "$C_RESET"; }

SANDBOX=""
cleanup() { [[ -n "$SANDBOX" ]] && rm -rf "$SANDBOX"; }
# An INT/TERM handler must exit itself. Without the explicit `exit`, bash runs
# cleanup and then RESUMES at the next statement, so Ctrl-C deletes the sandbox
# and then produces a cascade of bogus failures against the deleted directory.
trap cleanup EXIT
trap 'cleanup; exit 130' INT TERM

PKG_NAME="$(node -p "require('./package.json').name")"

# ─────────────────────────────────────────────────────────────────────────────
# Build
# ─────────────────────────────────────────────────────────────────────────────
if [[ "$SKIP_BUILD" == "0" ]]; then
  step "Building"
  if npm run build >/dev/null 2>&1; then
    pass "npm run build"
  else
    fail "npm run build — aborting, nothing to smoke test"; exit 1
  fi
fi

# ─────────────────────────────────────────────────────────────────────────────
# Static checks on the built output
# ─────────────────────────────────────────────────────────────────────────────
step "Dependencies"
dep_count="$(node -p "Object.keys(require('./package.json').dependencies || {}).length")"
pass "$dep_count runtime dependencies"
# To assert zero, replace the line above with:
#   [[ "$dep_count" == "0" ]] && pass "zero runtime dependencies" || fail "expected 0, found $dep_count"

step "Bundle size budgets"
for entry in ${SIZE_BUDGETS[@]+"${SIZE_BUDGETS[@]}"}; do
  file="${entry%%:*}"; budget="${entry##*:}"
  if [[ ! -f "$file" ]]; then fail "$file does not exist"; continue; fi
  size="$(gzip -9 -c "$file" | wc -c | tr -d ' ')"
  if (( size <= budget )); then
    pass "$file: ${size}B gzipped (budget ${budget}B)"
  else
    fail "$file: ${size}B gzipped EXCEEDS budget ${budget}B"
  fi
done

# ─────────────────────────────────────────────────────────────────────────────
# Install the real tarball into a throwaway consumer
# ─────────────────────────────────────────────────────────────────────────────
step "Packaged install"
SANDBOX="$(mktemp -d)"
if ! npm pack --pack-destination "$SANDBOX" >/dev/null 2>&1; then
  fail "npm pack"; echo; echo "$FAILED failed, $PASSED passed"; exit 1
fi
TARBALL="$(find "$SANDBOX" -name '*.tgz' | head -1)"
pass "packed $(basename "$TARBALL")"

CONSUMER="$SANDBOX/consumer"
mkdir -p "$CONSUMER"
(
  cd "$CONSUMER"
  npm init -y >/dev/null 2>&1
  # ${arr[@]+"${arr[@]}"} because bash 3.2 - still the default on macOS - treats
  # an empty array expansion as an unbound variable under `set -u`, and the
  # resulting failure blames npm rather than the shell.
  npm install "$TARBALL" ${EXTRA_INSTALL[@]+"${EXTRA_INSTALL[@]}"} >/dev/null 2>&1
) || { fail "npm install of the tarball"; echo; echo "$FAILED failed, $PASSED passed"; exit 1; }
pass "installed into a clean consumer project"

# A bloated tarball is a slow install for everyone. `files` should have trimmed
# this to the built output plus docs.
if [[ -d "$CONSUMER/node_modules/$PKG_NAME/src" ]]; then
  fail "the published package shipped src/ (check the \"files\" field)"
else
  pass "the published package ships no source"
fi

TARBALL_KB="$(du -k "$TARBALL" | cut -f1)"
pass "tarball is ${TARBALL_KB} kB"

# ─────────────────────────────────────────────────────────────────────────────
# PACKAGE-SPECIFIC CHECKS — adapt everything below
# ─────────────────────────────────────────────────────────────────────────────
step "Entry points"

if (cd "$CONSUMER" && node --input-type=module -e "
  import pkg from '$PKG_NAME';
  if (!pkg) process.exit(1);
" 2>&1); then
  pass "ESM: $PKG_NAME"
else
  fail "ESM entry point"
fi

if (cd "$CONSUMER" && node --input-type=commonjs -e "
  const pkg = require('$PKG_NAME');
  if (!pkg) process.exit(1);
" 2>&1); then
  pass "CJS: $PKG_NAME"
else
  fail "CJS entry point"
fi

step "Type resolution"
# A broken exports.types map is invisible at runtime but breaks every consumer's
# editor and `tsc`. Resolve it the way a bundler-mode consumer does.
(
  cd "$CONSUMER"
  npm install --no-save typescript >/dev/null 2>&1
  cat > tsconfig.json <<'JSON'
{
  "compilerOptions": {
    "module": "esnext",
    "moduleResolution": "bundler",
    "target": "es2022",
    "lib": ["es2022", "dom"],
    "strict": true,
    "noEmit": true,
    "skipLibCheck": true
  },
  "include": ["probe.ts"]
}
JSON
  # Import the real public API here — a probe that imports nothing proves nothing.
  cat > probe.ts <<TS
import pkg from '$PKG_NAME';
export const check = () => pkg;
TS
) >/dev/null 2>&1
if (cd "$CONSUMER" && npx --no-install tsc -p tsconfig.json 2>&1); then
  pass "types resolve under moduleResolution: bundler"
else
  fail "type resolution (run tsc in the sandbox to see the errors)"
fi

# For a CLI, add:
# step "CLI"
# if (cd "$CONSUMER" && npx "$PKG_NAME" --version >/dev/null 2>&1); then
#   pass "the bin entry runs"
# else
#   fail "the bin entry does not run"
# fi

# ─────────────────────────────────────────────────────────────────────────────
step "Summary"
if (( FAILED == 0 )); then
  printf '  %s%d passed, 0 failed%s\n\n' "$C_GREEN" "$PASSED" "$C_RESET"; exit 0
fi
printf '  %s%d failed%s, %d passed\n\n' "$C_RED" "$FAILED" "$C_RESET" "$PASSED"
exit 1

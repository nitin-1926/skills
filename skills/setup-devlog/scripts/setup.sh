#!/usr/bin/env bash
# Idempotent setup of a project devlog. Safe to re-run — only adds what is
# missing.
#
# Usage:
#   bash setup.sh [--dry-run] [--committed | --gitignored] [--root <path>]
#
# Flags:
#   --dry-run      Print what would change; do not touch any file.
#   --committed    DEVLOG.md will NOT be added to .gitignore (team-shared mode).
#   --gitignored   DEVLOG.md will be added to .gitignore (default; maintainer mode).
#   --root <path>  Override the project root (defaults to git root or pwd).
#
# Without --committed or --gitignored, the script defaults to gitignored. The
# slash skill `/setup-devlog` should ask the user explicitly before invoking.

set -euo pipefail

DRY_RUN=0
MODE="gitignored"
ROOT=""

while [ $# -gt 0 ]; do
  case "$1" in
    --dry-run)    DRY_RUN=1 ;;
    --committed)  MODE="committed" ;;
    --gitignored) MODE="gitignored" ;;
    --root)       ROOT="$2"; shift ;;
    -h|--help)
      sed -n '1,18p' "$0" | sed 's/^# \{0,1\}//'
      exit 0 ;;
    *)
      echo "Unknown flag: $1" >&2
      exit 2 ;;
  esac
  shift
done

if [ -z "$ROOT" ]; then
  ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
fi
if [ ! -d "$ROOT" ]; then
  echo "Root does not exist: $ROOT" >&2
  exit 1
fi

SKILL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TEMPLATE="$SKILL_DIR/references/devlog-template.md"
CLAUDE_SNIPPET="$SKILL_DIR/references/claude-md-snippet.md"
AGENTS_SNIPPET="$SKILL_DIR/references/agents-md-snippet.md"

for f in "$TEMPLATE" "$CLAUDE_SNIPPET" "$AGENTS_SNIPPET"; do
  if [ ! -f "$f" ]; then
    echo "Missing skill resource: $f" >&2
    exit 1
  fi
done

say() { printf '%s\n' "$1"; }
do_or_dry() {
  if [ "$DRY_RUN" -eq 1 ]; then
    say "[dry-run] would: $1"
  else
    eval "$2"
    say "[ok] $1"
  fi
}

PROJECT_NAME="$(basename "$ROOT")"

# 1. DEVLOG.md
DEVLOG="$ROOT/DEVLOG.md"
if [ -f "$DEVLOG" ]; then
  say "[skip] DEVLOG.md already exists at $DEVLOG"
else
  GITIGNORE_LINE=""
  if [ "$MODE" = "gitignored" ]; then
    GITIGNORE_LINE="DEVLOG.md added to .gitignore (local-only maintainer journal)"
  else
    GITIGNORE_LINE="DEVLOG.md committed (team-shared decision log)"
  fi
  # Render template with placeholders. PURPOSE/BASELINE left as TODO markers
  # for the user (or the slash skill, when running interactively) to fill.
  if [ "$DRY_RUN" -eq 1 ]; then
    say "[dry-run] would: write $DEVLOG from template ($(wc -l < "$TEMPLATE") lines)"
  else
    sed -e "s/{{PROJECT_NAME}}/$PROJECT_NAME/g" \
        -e "s|{{PROJECT_PURPOSE}}|TODO: describe this project's purpose in one paragraph (replace this line).|" \
        -e "s|{{BASELINE}}|TODO: list 3-6 bullets capturing what already exists and what is intentionally out of scope (replace this section).|" \
        -e "s|{{GITIGNORE_DECISION}}|$GITIGNORE_LINE|" \
        "$TEMPLATE" > "$DEVLOG"
    say "[ok] created $DEVLOG"
  fi
fi

# 2. .gitignore (only when mode = gitignored)
GITIGNORE="$ROOT/.gitignore"
if [ "$MODE" = "gitignored" ]; then
  if [ -f "$GITIGNORE" ] && grep -qxF "DEVLOG.md" "$GITIGNORE"; then
    say "[skip] DEVLOG.md already in .gitignore"
  else
    do_or_dry "append DEVLOG.md to $GITIGNORE" "
      { echo ''; echo '# Maintainer-only devlog'; echo 'DEVLOG.md'; } >> '$GITIGNORE'
    "
  fi
elif [ "$MODE" = "committed" ]; then
  if [ -f "$GITIGNORE" ] && grep -qxF "DEVLOG.md" "$GITIGNORE"; then
    say "[warn] mode=committed but $GITIGNORE has 'DEVLOG.md' — remove the line manually if you intend to commit"
  fi
fi

# 3. CLAUDE.md
inject_snippet() {
  local target="$1" snippet="$2" label="$3"
  if [ ! -f "$target" ]; then
    say "[skip] $label does not exist at $target — not auto-creating"
    return
  fi
  if grep -q "<!-- devlog-discipline -->" "$target"; then
    say "[skip] $label already has devlog-discipline section"
    return
  fi
  do_or_dry "append devlog-discipline section to $target" "
    { echo ''; echo ''; cat '$snippet'; } >> '$target'
  "
}

inject_snippet "$ROOT/CLAUDE.md" "$CLAUDE_SNIPPET" "CLAUDE.md"
inject_snippet "$ROOT/AGENTS.md" "$AGENTS_SNIPPET" "AGENTS.md"

say ""
say "Devlog setup pass complete (mode: $MODE, root: $ROOT)."
say "Next: open DEVLOG.md and replace the TODO placeholders for purpose + baseline."

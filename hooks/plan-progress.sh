#!/bin/bash
# UserPromptSubmit hook — compact plan progress line injected alongside the intent hint.

set -euo pipefail

find_plans_dir() {
  local dir="$PWD"
  while [ -n "$dir" ] && [ "$dir" != "/" ]; do
    [ -d "$dir/docs/plans" ] && { echo "$dir/docs/plans"; return 0; }
    dir=$(dirname "$dir")
  done
  return 1
}

PLANS_DIR=$(find_plans_dir) || exit 0

PLAN_FILES=$(find "$PLANS_DIR" -maxdepth 1 -type f -name "*.md" \
  ! -iname "template*" ! -iname "*.template.md" 2>/dev/null | sort || true)
[ -z "$PLAN_FILES" ] && exit 0

bar() {
  local done=$1 total=$2 width=8 filled empty i out=""
  filled=$(( done * width / total ))
  empty=$(( width - filled ))
  for ((i=0; i<filled; i++)); do out="${out}█"; done
  for ((i=0; i<empty; i++)); do out="${out}░"; done
  printf '%s' "$out"
}

while IFS= read -r f; do
  [ -f "$f" ] || continue
  DONE=$(grep -c '^\s*- \[x\]' "$f" 2>/dev/null || true); DONE=${DONE:-0}
  OPEN=$(grep -c '^\s*- \[ \]' "$f" 2>/dev/null || true); OPEN=${OPEN:-0}
  TOTAL=$(( DONE + OPEN ))
  [ "$TOTAL" -eq 0 ] && continue

  NAME=$(basename "$f" .md)
  [ "${#NAME}" -gt 36 ] && NAME="${NAME:0:33}…"
  [ "$DONE" -eq "$TOTAL" ] && STATUS="✓" || STATUS="$(( DONE * 100 / TOTAL ))%"

  jq -nc --arg ctx "📋  $(bar "$DONE" "$TOTAL")  ${DONE}/${TOTAL}  ${STATUS}  ${NAME}" \
    '{hookSpecificOutput:{hookEventName:"UserPromptSubmit",additionalContext:$ctx}}'
  exit 0
done <<< "$PLAN_FILES"

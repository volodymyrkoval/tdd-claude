#!/bin/bash
# PreToolUse Bash hook — before `git commit`, run the project's linter and test suite.
# Both are opt-in per project via sentinel files at the repo root:
#
#   .claude/lint-cmd   — e.g. `npm run lint` or `ruff check .`
#   .claude/test-cmd   — e.g. `npm test --silent` or `pytest -q`
#
# Lint runs first; if it fails the commit is denied without running tests.
# No sentinel file = that check is inactive. Both can coexist independently.

set -euo pipefail

INPUT=$(cat)
TOOL=$(echo "$INPUT" | jq -r '.tool_name // empty')
[ "$TOOL" = "Bash" ] || exit 0

CMD=$(echo "$INPUT" | jq -r '.tool_input.command // empty')
[ -n "$CMD" ] || exit 0

# Only intercept `git commit`. `git commit --amend` and `-m` variants still match.
echo "$CMD" | grep -qE '(^|[;&|[:space:]])git[[:space:]]+commit([[:space:]]|$)' || exit 0

# Walk up from cwd to find a repo root containing either sentinel file.
# Stop at $HOME so ~/.claude/ cannot activate the hook from unrelated directories.
dir="$PWD"
REPO_ROOT=""
while [ -n "$dir" ] && [ "$dir" != "/" ] && [ "$dir" != "$HOME" ]; do
  if [ -f "$dir/.claude/lint-cmd" ] || [ -f "$dir/.claude/test-cmd" ]; then
    REPO_ROOT="$dir"
    break
  fi
  dir=$(dirname "$dir")
done

[ -n "$REPO_ROOT" ] || exit 0

deny() {
  local reason="$1"
  jq -nc --arg reason "$reason" '{
    hookSpecificOutput: {
      hookEventName: "PreToolUse",
      permissionDecision: "deny",
      permissionDecisionReason: $reason
    }
  }'
  exit 0
}

run_check() {
  local label="$1"
  local cmd="$2"
  local log
  log=$(mktemp)
  if (cd "$REPO_ROOT" && eval "$cmd") >"$log" 2>&1; then
    rm -f "$log"
    return 0
  fi
  local tail
  tail=$(tail -30 "$log")
  rm -f "$log"
  deny "$(printf 'Denied: %s failed. Running `%s` produced errors. Fix before committing.\n\nLast 30 lines:\n%s' "$label" "$cmd" "$tail")"
}

# Lint first (fast feedback).
if [ -f "$REPO_ROOT/.claude/lint-cmd" ]; then
  LINT_CMD=$(head -n1 "$REPO_ROOT/.claude/lint-cmd" | tr -d '\r' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
  [ -n "$LINT_CMD" ] && run_check "lint" "$LINT_CMD"
fi

# This hook deliberately does NOT consult `.claude/integration-test-cmd`.
# Integration tests are allowed to be red during dev — the gate lives in `/done`.
# Adding integration-test consultation here would prevent commit during an iteration's
# red phase, breaking outside-in TDD. See plans/ui-integration-tester-agent.md.

# Tests second.
if [ -f "$REPO_ROOT/.claude/test-cmd" ]; then
  TEST_CMD=$(head -n1 "$REPO_ROOT/.claude/test-cmd" | tr -d '\r' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
  [ -n "$TEST_CMD" ] && run_check "tests" "$TEST_CMD"
fi

exit 0

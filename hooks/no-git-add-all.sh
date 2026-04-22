#!/bin/bash
# PreToolUse Bash hook — deny `git add -A`, `git add --all`, `git add .`.
#
# Scoped to TDD-mode repos only: the hook fires only when `.claude/test-cmd`
# exists in the tree (walking up from cwd, stopping at $HOME). This matches
# pre-commit-green.sh's opt-in model so third-party repos, quick prototypes,
# and any non-TDD work stay unblocked.
#
# CLAUDE.md's prompt-level rule still discourages `git add -A` everywhere — the
# hook only adds mechanical enforcement where the project has opted in.

set -euo pipefail

INPUT=$(cat)
TOOL=$(echo "$INPUT" | jq -r '.tool_name // empty')
[ "$TOOL" = "Bash" ] || exit 0

CMD=$(echo "$INPUT" | jq -r '.tool_input.command // empty')
[ -n "$CMD" ] || exit 0

# Match `git add -A`, `git add --all`, `git add .` at a shell-command boundary.
# Word-boundary-ish so paths like `./src/foo` or args like `-Afile` don't trip.
echo "$CMD" | grep -qE '(^|[;&|[:space:]])git[[:space:]]+add[[:space:]]+(-A|--all|\.)([[:space:]]|$)' || exit 0

# Opt-in check: is there a `.claude/test-cmd` in the tree above cwd?
# Stop at $HOME so the user's global ~/.claude/ can never activate the hook
# from arbitrary working directories.
dir="$PWD"
FOUND=""
while [ -n "$dir" ] && [ "$dir" != "/" ] && [ "$dir" != "$HOME" ]; do
  if [ -f "$dir/.claude/test-cmd" ]; then
    FOUND="$dir"
    break
  fi
  dir=$(dirname "$dir")
done

# No `.claude/test-cmd` in the tree → not a TDD-mode repo → allow.
[ -n "$FOUND" ] || exit 0

REASON=$(printf 'Denied: `git add -A|--all|.` bypasses named-file discipline (can sweep in secrets or unrelated work). Stage files explicitly: `git add src/foo.ts tests/foo.test.ts`. See CLAUDE.md > TDD Phase Boundaries.\n\nThis gate is active because the project at `%s` declares TDD mode via `.claude/test-cmd`. To disable for this repo, remove that file.' "$FOUND")

jq -nc --arg reason "$REASON" '{
  hookSpecificOutput: {
    hookEventName: "PreToolUse",
    permissionDecision: "deny",
    permissionDecisionReason: $reason
  }
}'
exit 0

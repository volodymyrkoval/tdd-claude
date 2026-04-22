#!/bin/bash
# PreToolUse hook — when ANY plan file exists in docs/plans/ (walking up from cwd),
# deny TaskCreate/TaskUpdate. The plan's `- [ ]`/`- [x]` checkboxes ARE the todo list.
# Works with or without git, on any branch. Archived plans live in docs/archive/
# and do not trigger the rule.

set -euo pipefail

INPUT=$(cat)
TOOL=$(echo "$INPUT" | jq -r '.tool_name // empty')

# Only gate mutation tools; reads (TaskList/Get/Output) are harmless.
case "$TOOL" in
  TaskCreate|TaskUpdate) ;;
  *) exit 0 ;;
esac

# Walk up from cwd to find docs/plans/. Works without git.
find_plans_dir() {
  local dir="$PWD"
  while [ -n "$dir" ] && [ "$dir" != "/" ]; do
    if [ -d "$dir/docs/plans" ]; then
      echo "$dir/docs/plans"
      return 0
    fi
    dir=$(dirname "$dir")
  done
  return 1
}

PLANS_DIR=$(find_plans_dir) || exit 0

# Collect non-template plan files at depth 1 only. Archived plans live in
# .claude/archive/ (separate dir) so they never appear here.
PLANS=$(find "$PLANS_DIR" -maxdepth 1 -type f -name "*.md" \
  ! -iname "template*" ! -iname "*.template.md" 2>/dev/null || true)
[ -z "$PLANS" ] && exit 0

# Short list for the deny message (up to 5 entries).
PLAN_LIST=$(printf '%s\n' "$PLANS" | sed "s|^${PLANS_DIR}/|  - |" | head -5)

REASON=$(printf 'Active plan(s) in %s:\n%s\n\nThose plan files ARE the todo list. Do not use %s. Workflow: Read the relevant plan, find the first unchecked `- [ ]` under Todos, dispatch the matching dev-tier agent. After the dev agent commits, Edit the plan to flip `- [ ]` -> `- [x]`. See the todo-tracking skill. If a listed plan is actually complete, archive it: `git mv docs/plans/<slug>.md docs/archive/`.' "$PLANS_DIR" "$PLAN_LIST" "$TOOL")

jq -nc --arg reason "$REASON" '{
  hookSpecificOutput: {
    hookEventName: "PreToolUse",
    permissionDecision: "deny",
    permissionDecisionReason: $reason
  }
}'
exit 0

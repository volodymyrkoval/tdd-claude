#!/bin/bash
# UserPromptSubmit hook — injects orchestrator routing hints based on the user's intent verbs.
# Output schema: { hookSpecificOutput: { hookEventName: "UserPromptSubmit", additionalContext: "..." } }
# Exit 0 without output if no match (no hint injected).

set -euo pipefail

INPUT=$(cat)
PROMPT=$(echo "$INPUT" | jq -r '.prompt // empty' 2>/dev/null || true)
[ -z "$PROMPT" ] && exit 0

# Lowercase + trim leading whitespace; only need the first ~200 chars for intent detection.
LOWER=$(echo "$PROMPT" | tr '[:upper:]' '[:lower:]' | sed 's/^[[:space:]]*//' | head -c 200)

HINT=""
case "$LOWER" in
  "add "*|"build "*|"implement "*|"create "*|"new feature"*)
    HINT='Route: `/feature <slug>` → `/plan <slug>` → `/implement --all`. Dispatch to planner, then dev agents per todo tier. Do not implement inline.' ;;
  "fix "*|*"bug "*|*"broken"*|"why is "*"failing"*|"why is "*"broken"*)
    HINT='Route: if root cause is clear, dispatch senior-dev (TDD). If cause is unclear, flaky, concurrency, perf → dispatch `/debug` (debugger agent) first, then lead-dev for the fix under TDD.' ;;
  "refactor "*|"clean up "*|"cleanup "*|"tidy "*)
    HINT='Route: `/refactor` → senior-dev in Refactor phase. Tests must be green first; behavior must not change.' ;;
  "review "*|"review this"*|"is this good"*|"is this correct"*|"is this ok"*|"look at my "*)
    HINT='Route: `/review` → dispatch reviewer agent. If diff touches auth/crypto/injection/secrets/session handling, promote to `/security-audit` (security-auditor agent).' ;;
  "debug "*|"diagnose "*|"why is this"*|"why does "*|"investigate "*)
    HINT='Route: `/debug` → dispatch debugger agent. Produces a diagnosis, not a fix. Hand off to lead-dev for TDD fix once root cause is named.' ;;
  "explain "*|"how does "*|"how is "*|"where is "*|"where does "*|"what does "*|"what is "*)
    HINT='Route: `/expert` → dispatch project-expert (read-only). Do not edit files.' ;;
  "scaffold "*|"bootstrap "*|"new project"*|"start a new "*)
    HINT='Route: `/bootstrap <stack>` → dispatch bootstrapper agent.' ;;
  "document "*|"documentation "*|"update readme"*|"update claude.md"*|"update claude md"*|"sync docs"*|"sync readme"*)
    HINT='Route: `/docs`, `/readme`, or `/sync` → dispatch docs-writer agent.' ;;
esac

if [ -n "$HINT" ]; then
  jq -nc --arg hint "$HINT" '{hookSpecificOutput:{hookEventName:"UserPromptSubmit", additionalContext:$hint}}'
fi
exit 0

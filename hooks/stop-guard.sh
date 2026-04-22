#!/bin/bash
# Stop hook — warn when session ends with uncommitted changes OR mid-flight
# iteration state. Silent when all is clean.
# This hook does not inspect `.claude/integration-test-cmd` status. Red integration tests during an iteration are silent — the gate lives in `/done`.

set -euo pipefail

# Not a git repo? Nothing to check.
if ! git rev-parse --git-dir >/dev/null 2>&1; then
  exit 0
fi

# Compute the latest N for a dev/* tag family (returns 0 if none exist).
latest_n() {
  local family="$1"
  git tag --list "dev/${family}-*" \
    | sed "s|^dev/${family}-||" \
    | grep -E '^[0-9]+$' \
    | sort -n \
    | tail -1 \
    | grep -E '^[0-9]+$' || echo "0"
}

# Returns one of: idle | planning | implementing | done
iteration_state() {
  local plan_n impl_n done_n
  plan_n=$(latest_n plan)
  impl_n=$(latest_n impl)
  done_n=$(latest_n done)

  # No plan tags at all → idle
  if [ "$plan_n" = "0" ]; then
    echo "idle"
    return
  fi

  # plan written, no impl yet → planning
  if [ "$impl_n" -lt "$plan_n" ] 2>/dev/null; then
    echo "planning"
    return
  fi

  # impl written, done not caught up → implementing
  if [ "$done_n" -lt "$impl_n" ] 2>/dev/null; then
    echo "implementing"
    return
  fi

  echo "done"
}

# Warn if HEAD looks like a doc commit but has no dev/doc-* tag.
doc_drift_check() {
  local subject
  subject=$(git log -1 --format='%s' 2>/dev/null || true)
  if echo "$subject" | grep -qE '^docs(\(|:)'; then
    if ! git tag --points-at HEAD | grep -qE '^dev/doc-[0-9]+$'; then
      jq -nc --arg msg "🟡 HEAD looks like a doc commit (message: ${subject}) but no dev/doc-NNN points at HEAD. Run \`git tag dev/doc-NNN HEAD\` to anchor it, or amend." '{systemMessage: $msg}'
    fi
  fi
}

STATE=$(iteration_state)

# Emit iteration-state warnings
case "$STATE" in
  planning)
    PLAN_TAG=$(git tag --list 'dev/plan-*' | sort | tail -1)
    jq -nc --arg msg "🟡 Iteration in 'planning' state — plan tagged but not implemented. Run /implement --all or delete ${PLAN_TAG} to abandon." '{systemMessage: $msg}'
    ;;
  implementing)
    IMPL_TAG=$(git tag --list 'dev/impl-*' | sort | tail -1)
    jq -nc --arg msg "🟡 Iteration in 'implementing' state — ${IMPL_TAG} written but not done. Run /done to finalise." '{systemMessage: $msg}'
    ;;
esac

# Doc-without-tag drift check (additive — runs regardless of iteration state)
doc_drift_check

# Early exit if state is idle/done AND working tree is clean
if [ "$STATE" = "idle" ] || [ "$STATE" = "done" ]; then
  if git diff --quiet 2>/dev/null && git diff --quiet --cached 2>/dev/null; then
    exit 0
  fi
fi

# Warn on uncommitted source changes (original behavior — preserved)
NON_META=$(git status --porcelain 2>/dev/null | awk '{print $2}' | grep -vE '^\.claude/' | head -1 || true)
if [ -n "$NON_META" ]; then
  jq -nc '{systemMessage:"Uncommitted source changes remain. Consider `/review` (and `/commit`) before continuing."}'
fi

exit 0

---
description: Close a completed feature — verify plan complete, squash commits.
model: sonnet
allowed-tools: Read, Glob, Bash(git:*), Bash(find:*), Bash(mv:*)
---

# Close Feature (`/done`)

Finalise the current iteration: archive the plan, squash all impl commits into one, write `dev/done-NNN`.

## Context

- Branch: !`git branch --show-current`
- Base branch: !`git for-each-ref --format='%(refname:lstrip=3)' refs/remotes/origin/HEAD 2>/dev/null || echo "main"`
- Status: !`git status --short`
- Active plan: !`find docs/plans -name "*.md" ! -name "_*" 2>/dev/null | sort | tail -1 || echo "none"`

## Steps

### 1. Preflight checks (D1)

Run all four checks; stop on any failure:

**(i) Active plan exists with all checkboxes done:**
```bash
# Find the active plan
PLAN_FILE=$(find docs/plans -name "*.md" ! -name "_*" 2>/dev/null | sort | tail -1)
if [ -z "$PLAN_FILE" ]; then
  echo "⚠️ No active plan found in docs/plans/ — cannot close."
  exit 1
fi
# Extract slug from filename
SLUG=$(basename "$PLAN_FILE" .md | sed 's/^[0-9]*-//')
# Check for unchecked todos
if grep -q '^\s*- \[ \]' "$PLAN_FILE"; then
  echo "⚠️ Plan has unchecked todos:"
  grep '^\s*- \[ \]' "$PLAN_FILE"
  echo "Fix or explicitly defer before /done."
  exit 1
fi
```

**(ii) Working tree clean:**
```bash
if ! git diff --quiet || ! git diff --cached --quiet; then
  echo "⚠️ Uncommitted changes — commit or stash before /done."
  exit 1
fi
```

**(iii) dev/plan-NNN exists and is reachable:**
```bash
LATEST_PLAN_TAG=$(git tag --list 'dev/plan-*' | sort | tail -1)
if [ -z "$LATEST_PLAN_TAG" ]; then
  echo "⚠️ dev/plan-NNN missing — was /plan run?"
  exit 1
fi
PLAN_N=$(echo "$LATEST_PLAN_TAG" | sed 's|^dev/plan-||')
```

**(iv) dev/impl-NNN exists with matching N:**
```bash
LATEST_IMPL_TAG=$(git tag --list 'dev/impl-*' | sort | tail -1)
if [ -z "$LATEST_IMPL_TAG" ]; then
  echo "⚠️ dev/impl-$(printf '%03d' $PLAN_N) missing. Run /implement --all to finish the iteration."
  exit 1
fi
IMPL_N=$(echo "$LATEST_IMPL_TAG" | sed 's|^dev/impl-||')
if [ "$IMPL_N" != "$PLAN_N" ]; then
  echo "⚠️ dev/plan-${PLAN_N} active but latest dev/impl is ${IMPL_N}. Run /implement --all."
  exit 1
fi
```

### 2. Archive the plan (D2)

```bash
git mv "docs/plans/$(basename "$PLAN_FILE")" "docs/archive/$(basename "$PLAN_FILE")"
# --no-verify justified: this commit only moves a markdown file from docs/plans/ → docs/archive/.
# Source code is unchanged, so pre-commit-green's lint+test would be 100% redundant work.
git commit --no-verify -m "chore(archive): ${SLUG}"
```

### 2a. Integration test gate

```bash
REPO_ROOT=$(git rev-parse --show-toplevel)
if [ -f "$REPO_ROOT/.claude/integration-test-cmd" ]; then
  ITEST_CMD=$(head -n1 "$REPO_ROOT/.claude/integration-test-cmd" | tr -d '\r' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
  if [ -n "$ITEST_CMD" ]; then
    if ! (cd "$REPO_ROOT" && eval "$ITEST_CMD"); then
      cat <<EOF
⚠️ Integration tests red — /done refused.

The seam tests are showing real component-boundary failures. Pick the right next move:

  • /plan  — add fix todos for the seam bug (most common)
  • /diagnose <symptom>  — if the failure mode is unclear
  • Drop scope — remove the failing seam from the iteration

Re-run /done once tests are green.
EOF
      exit 1
    fi
  fi
fi
```

**Behavior:**
- Missing or empty `.claude/integration-test-cmd` → silent pass (no integration tests configured).
- Red command → refuse, print the three-option re-plan message (`/plan`, `/diagnose <symptom>`, "Drop scope"), exit 1.
- Archive commit is intentionally NOT rolled back on red — the iteration is in a recoverable state; user re-runs `/done` after fixing via `/plan`.

> **Placement note:** The gate runs after archive but before squash. A red gate leaves the iteration recoverable — archive commit is in history, squash hasn't happened, user fixes via /plan and re-runs /done.

### 3. Compute N for done tag and PLAN_N (D3)

```bash
next_tag_n() {
  local family="$1"
  local last
  last=$(git tag --list "dev/${family}-*" \
         | sed "s|^dev/${family}-||" \
         | grep -E '^[0-9]+$' \
         | sort -n \
         | tail -1)
  printf "%03d" $(( ${last:-0} + 1 ))
}

DONE_N=$(next_tag_n done)
# PLAN_N already set in Step 1
```

### 4. Defensive audit-OR-doc preservation pre-pass (D4)

```bash
PRESERVE_SHAS=()
PRESERVE_TAGS=()
# Scan range (dev/plan-${PLAN_N}, HEAD] for audit/doc commits to preserve through the squash.
# Under normal flow this range contains no dev/audit-* or dev/doc-* commits — this is a safety net.
while IFS= read -r sha; do
  tag=$(git tag --points-at "$sha" | grep -E '^dev/(audit|doc)-[0-9]+$' | head -1 || true)
  if [ -n "$tag" ]; then
    PRESERVE_SHAS+=("$sha")
    PRESERVE_TAGS+=("$tag")
  fi
done < <(git log --format='%H' --reverse "dev/plan-${PLAN_N}..HEAD")

if [ ${#PRESERVE_SHAS[@]} -gt 0 ]; then
  echo "⚠️ Found ${#PRESERVE_SHAS[@]} audit/doc commit(s) inside squash range — will cherry-pick after squash to preserve tags:"
  for i in "${!PRESERVE_SHAS[@]}"; do
    echo "   ${PRESERVE_TAGS[$i]} @ ${PRESERVE_SHAS[$i]}"
  done
fi
```

### 5. Type detection — walk from dev/plan-N^, skip doc tags (D5)

```bash
# Walk back from dev/plan-${PLAN_N}'s parent, skipping dev/doc-* tags.
# First non-doc tag: dev/audit-* → refactor; anything else → feat.
walk_sha=$(git rev-parse "dev/plan-${PLAN_N}" 2>/dev/null || true)
TYPE=feat
DOC_SKIP_COUNT=0
while [ -n "$walk_sha" ]; do
  tags_here=$(git tag --points-at "$walk_sha" 2>/dev/null || true)
  if echo "$tags_here" | grep -qE '^dev/audit-[0-9]+$'; then
    TYPE=refactor
    break
  fi
  if echo "$tags_here" | grep -qE '^dev/doc-[0-9]+$'; then
    DOC_SKIP_COUNT=$(( DOC_SKIP_COUNT + 1 ))
    walk_sha=$(git rev-parse "${walk_sha}^" 2>/dev/null || true)
    continue
  fi
  break
done
echo "🏷️ type detected: ${TYPE}"
if [ "$DOC_SKIP_COUNT" -gt 0 ]; then
  echo "🏷️ skipped ${DOC_SKIP_COUNT} doc tag(s) during type detection"
fi
```

### 6. Read plan goal for commit message

```bash
PLAN_ARCHIVE="docs/archive/$(basename "$PLAN_FILE")"
PLAN_GOAL=$(grep -m1 '^##\? *Goal' "$PLAN_ARCHIVE" -A1 | tail -1 | sed 's/^[#* ]*//' | head -c 80 || echo "implement ${SLUG}")
```

### 7. Squash: soft-reset to dev/plan-N, commit (D7)

```bash
git reset --soft "dev/plan-${PLAN_N}"
# --no-verify justified: the working tree at this point is identical to the state at the
# last /implement commit (soft reset preserves the index). pre-commit-green already ran
# on this exact tree during the last impl commit; rerunning lint+test is redundant.
git commit --no-verify -m "$(cat <<EOF
${TYPE}(${SLUG}): ${PLAN_GOAL}

- Implementation via TDD across all plan todos
- Plan archived to docs/archive/${SLUG}

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>
EOF
)"
```

### 8. Replay preserved audit/doc commits (D6)

```bash
# Replay preserved audit/doc commits on top of the squash.
# Force-move each tag to its new SHA — the tag's identity (which audit/doc event) is what survives.
for i in "${!PRESERVE_SHAS[@]}"; do
  if ! git cherry-pick "${PRESERVE_SHAS[$i]}"; then
    echo "⚠️ cherry-pick of ${PRESERVE_TAGS[$i]} (${PRESERVE_SHAS[$i]}) failed — manual resolution required."
    echo "   Resolve the conflict, run 'git cherry-pick --continue', then force-move the tag:"
    echo "   git tag -f ${PRESERVE_TAGS[$i]} HEAD"
    exit 1
  fi
  git tag -f "${PRESERVE_TAGS[$i]}" HEAD
  echo "✓ ${PRESERVE_TAGS[$i]} replayed and re-anchored at $(git rev-parse --short HEAD)"
done
```

### 9. Write dev/done-N tag (D8)

```bash
git tag "dev/done-${DONE_N}" HEAD
echo "🏷️ dev/done-${DONE_N} anchored."
```

## Notes (D10)

### Triggering the defensive cherry-pick path manually (verification)

These snippets are for manual verification (Verification plan steps 9a and 9b) — not run by this command automatically:

```bash
# 9a — Force an audit commit inside the iteration range:
git tag dev/audit-099 <some-sha-between-dev/plan-N-and-HEAD>
/done  # → should warn and cherry-pick dev/audit-099 to after squash

# 9b — Force a doc commit inside the iteration range:
git tag dev/doc-099 <some-sha-between-dev/plan-N-and-HEAD>
/done  # → should warn and cherry-pick dev/doc-099 to after squash, force-moving the tag
```

## Output (D9)

```
✓ Feature closed: <slug>
  Squashed: N commits → 1
  Type: feat|refactor
  Tag: dev/done-NNN

Next: /design-audit (optional) or start a new feature with /plan.
```

---
description: Create a new feature plan.
argument-hint: <feature-name> [--deep]
model: opus
allowed-tools: Read, Grep, Glob, Bash(git:*)
---

# Create Plan: $ARGUMENTS

## Context
- Branch: !`git branch --show-current`
- Existing plans: !`ls docs/plans/ 2>/dev/null | grep -v TEMPLATE || echo "None"`

## Task

Derive the kebab-case slug from `$ARGUMENTS` (strip `--deep` flag). Call it `<slug>`.

### Step 1: Preflight — clean working tree

```bash
if ! git diff --quiet || ! git diff --cached --quiet; then
  echo "⚠️ Working tree dirty — commit/stash before /plan (need a clean HEAD to anchor dev/plan-N)."
  exit 1
fi
```

### Step 2: Idempotency — plan file exists and tag already written

```bash
if [ -f "docs/plans/${slug}.md" ] && git tag --list 'dev/plan-*' | grep -qE '^dev/plan-[0-9]+$'; then
  EXISTING_TAG=$(git tag --list 'dev/plan-*' | sort | tail -1)
  echo "ℹ️ ${EXISTING_TAG} already exists and docs/plans/${slug}.md exists; nothing to do."
  echo "   Pass --force to re-create (deletes tag and re-runs planner)."
  exit 0
fi
```

### Step 3: Recovery — plan file exists but tag missing (tag write crashed after planner committed)

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

if [ -f "docs/plans/${slug}.md" ]; then
  # Planner committed the plan file but the tag write never happened — recover by
  # finding the exact commit that added the plan file and tagging it.
  PLAN_SHA=$(git log --diff-filter=A --format='%H' -- "docs/plans/${slug}.md" | head -1)
  N=$(next_tag_n plan)
  PLAN_TAG="dev/plan-$(printf '%03d' $N)"
  echo "🛟 Plan file exists but ${PLAN_TAG} missing — recovering tag at plan commit ${PLAN_SHA:0:7}."
  git tag "${PLAN_TAG}" "${PLAN_SHA}"
  echo "Tag: ${PLAN_TAG} (recovered)"
  exit 0
fi
```

### Step 4: Compute N

```bash
N=$(next_tag_n plan)
```

### Step 5: Dispatch planner

Invoke the **planner** agent with:
- Feature name: `<slug>` (kebab-case)
- Plan filename: `docs/plans/<N>-<slug>.md` (use the exact N computed in Step 4)
- `--deep` flag if present in `$ARGUMENTS`
- Context: branch, existing plans
- Note for planner: `After committing the plan file, do not create or modify any dev/* tags — the orchestrator writes dev/plan-N after the planner returns`

Do **not** gather requirements, design, or write to `docs/plans/` yourself. The planner owns all of that, including committing the plan file.

UI-stack detection is performed by the planner agent based on its prompt instructions — the slash command does not detect or pre-emit UI tier-groups. See `agents/planner.md` > UI integration tests subsection.

### Step 6: Write `dev/plan-N` at the plan commit

After the planner returns, tag HEAD (the plan commit):

```bash
echo "📐 anchoring dev/plan-${N} at plan commit (HEAD)"
git tag "dev/plan-${N}" HEAD
```

## Stop conditions

- **Working tree dirty** → refused in Step 1 with `⚠️` message.
- **Idempotency** → Step 2 catches "rerun without progress" — plan file + any dev/plan tag exists → no-op.
- **Recovery** → Step 3 catches "tag write crashed after planner committed" — plan file exists but no tag → find the plan commit via `git log --diff-filter=A`, write tag there.

## Output

Forward the planner's structured output verbatim, prefixed with:
```
Tag: dev/plan-NNN (anchored at plan commit)
```

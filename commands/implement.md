---
description: Implement the next todo from the current plan via TDD.
argument-hint: [--all] [--todo <n>]
model: sonnet
allowed-tools: Read, Grep, Glob, Edit, Write, Bash
---

# Implement Plan Todo

Drive one plan todo through Red → Green → Refactor → `/commit`.

## Context

- Branch: !`git branch --show-current`
- Plans: !`ls docs/plans/ 2>/dev/null | grep -v TEMPLATE || echo "None"`
- Working tree: !`git status --porcelain 2>/dev/null || echo "n/a"`

## Task

### Step 1: Locate Plan

Find `docs/plans/<slug>.md` matching the current branch (`feature/<slug>`). If missing, stop: "⚠️ No plan for this branch. Run `/plan <name>` first."

Also verify `dev/plan-NNN` exists and is reachable from HEAD:
```bash
if [ -z "$(git tag --list 'dev/plan-*')" ]; then
  echo "⚠️ dev/plan-NNN missing — run /plan first."
  exit 1
fi
```

### Step 2: Pick Todo

- Default: first unchecked todo under `## Todo`.
- `--todo <n>`: target the Nth unchecked todo.
- `--all`: iterate through every remaining todo in order.

Stop if none remain: "✓ All todos complete. Next: `/review`."

### Step 3: Validate Tier Tag

Each todo must carry an effort tag (S/M/L) and a dev-tier tag (`junior-dev|senior-dev|lead-dev|ui-integration-tester`) from the planner. If the selected todo has **no tier tag**, stop:

```
⚠️ Todo lacks dev-tier tag: "<todo text>"
   Re-run /plan to re-tag, or tag manually: junior-dev | senior-dev | lead-dev | ui-integration-tester
```

Do **not** silently default — a mistagged todo costs the wrong model tier.

### Step 4: Dispatch to Dev Tier

Dispatch to the agent matching the tag:

| Tier | Agent | When |
|------|-------|------|
| tester | **ui-integration-tester** | UI integration tests at component seams (writes red, never fixes) |
| junior | **junior-dev** | Trivial, obvious-pattern changes |
| senior | **senior-dev** | Non-trivial but understood work |
| lead | **lead-dev** | Unknown root cause, concurrency, perf, security |

Escalate senior → lead if the problem reveals hidden depth mid-cycle.

### Tier-group precedence within a section

Within a section, dispatch order is: any `*-tester` tier-group(s) → `**junior-dev**` → `**senior-dev**` → `**lead-dev**`. Multiple `*-tester` groups dispatch in plan-listed order. Today only `ui-integration-tester` exists in the `*-tester` family.

**Scaffolding constraint:** If a section contains both scaffolding work (junior-dev) AND a `*-tester` group, the planner must split the section into two sections — scaffolding section first (junior-dev only), then integration section (`*-tester` first, then dev groups). The precedence rule does not allow scaffolding-junior to dispatch before a `*-tester` in the same section.

### Step 5: Drive TDD (the dev agent owns this)

The dispatched dev agent runs the full cycle end-to-end:
1. 🔴 **Red** — one failing test
2. 🟢 **Green** — minimal code to pass
3. 🔵 **Refactor** — tests stay green
4. ✅ **Commit** — conventional message, staged by name, inside the same cycle

The dev agent commits itself — do **not** invoke `/commit` here. `/commit` is a standalone command for ad-hoc commits outside a TDD cycle.

### Step 6: Mark Todo Complete

After the dev agent returns, edit the plan: flip `- [ ]` → `- [x]` for the completed todo. Do **not** uncheck anything.

Plan stays active — archival is `/done`'s job (Decision D2 of plan dev-tag-workflow-iron-clock).

### Step 7: Tag iteration end (--all only)

If `--all` is set and this was the last unchecked todo AND all checkboxes are now `- [x]`:

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

N=$(next_tag_n impl)
git tag "dev/impl-${N}" HEAD
echo "🏁 dev/impl-${N} anchored — run /done to finalise."
```

Stop with: `✅ All todos complete. dev/impl-NNN anchored. Next: /review (optional) or /done.`

If `--all` and todos remain, loop to Step 2. Otherwise (single-todo mode) stop normally.

## Rules
- One todo per cycle (unless `--all`)
- Never edit the plan's Design or Acceptance Criteria mid-implementation — if scope shifts, stop and suggest `/plan` update
- Working tree should be clean between cycles

## Output
```
✓ Todo complete: <todo text>
  Tier: <junior|senior|lead>
  Commit: <sha> <message>
  Remaining: N todos
[dev/impl-NNN anchored]
Next: /implement  (or /review if done, or /done for archival)
```

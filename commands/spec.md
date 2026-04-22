---
description: Write a short, human-readable live-spec for the most recently shipped feature, and patch any docs the change made stale. Run right after `/done`.
model: sonnet
allowed-tools: Read, Glob, Grep, Edit, Write, Bash(git:*), Bash(ls:*), Bash(mkdir:*), Bash(basename:*), Bash(sed:*), Bash(printf:*)
---

# Live Spec (`/spec`)

Dispatch to the **feature-documenter** agent. The agent reads the latest `dev/done-NNN` squashed commit and its archived plan, writes a < 100-line descriptive spec to `docs/features/<slug>.md`, and updates any other docs the feature made stale.

Opus is intentional on the agent side — the drift sweep needs to hold the whole project's doc surface in context at once.

## Context

- Branch: !`git branch --show-current`
- Latest done tag: !`git tag --list 'dev/done-*' | sort | tail -1 || echo "none"`
- Latest archived plan: !`ls -t docs/archive/*.md 2>/dev/null | head -1 || echo "none"`
- Existing features dir: !`ls docs/features/ 2>/dev/null | head -5 || echo "(will be created)"`

## Steps

### 1. Preflight checks

**(i) A `dev/done-NNN` tag must exist.**
```bash
LATEST_DONE=$(git tag --list 'dev/done-*' | sort | tail -1)
if [ -z "$LATEST_DONE" ]; then
  echo "⚠️ No dev/done-NNN tag found. /spec runs after /done."
  exit 1
fi
```

**(ii) Working tree must be clean.** A live-spec commit should never fold in unrelated work-in-progress.
```bash
if ! git diff --quiet || ! git diff --cached --quiet; then
  echo "⚠️ Uncommitted changes — commit, stash, or discard before /spec."
  exit 1
fi
```

**(iii) An archived plan must exist for the latest done.**
```bash
LATEST_PLAN=$(ls -t docs/archive/*.md 2>/dev/null | head -1)
if [ -z "$LATEST_PLAN" ]; then
  echo "⚠️ No archived plan in docs/archive/ — cannot derive feature spec."
  exit 1
fi
SLUG=$(basename "$LATEST_PLAN" .md | sed 's/^[0-9]*-//')
```

**(iv) HEAD-vs-done advisory.** If HEAD is past the latest done (e.g. doc commits already landed), warn but continue — the agent always sources from `$LATEST_DONE`, not HEAD.
```bash
if [ "$(git rev-parse HEAD)" != "$(git rev-parse "$LATEST_DONE")" ]; then
  echo "ℹ️ HEAD is past ${LATEST_DONE}. Sourcing spec from the done tag, not HEAD."
fi
```

**(v) Idempotency check.** If the spec already exists, the agent treats this as an update — flag it for the orchestrator's awareness.
```bash
if [ -f "docs/features/${SLUG}.md" ]; then
  echo "ℹ️ docs/features/${SLUG}.md already exists — agent will run as an update, patching only drift."
fi
```

### 2. Dispatch the agent

Spawn `feature-documenter` (model: opus). Pass the slug, plan path, and done tag in the prompt so the agent doesn't have to re-derive them.

The agent will:
1. Apply `feature-doc-rubric` (five-section discipline, all checkboxes).
2. Read `git show $LATEST_DONE` and `docs/archive/<plan>` end-to-end.
3. Draft `docs/features/<slug>.md` (< 100 lines).
4. Run the **drift sweep** against `CLAUDE.md`, `README.md`, every existing `docs/features/**`, and every other top-level `*.md`. Update any claim the feature contradicts.
5. Emit a drift report.
6. Commit only the new spec and the drifted docs (named files, never `git add -A`):
   `docs(features): live-spec for <slug>` (+ `... + drift fixes in <files>` when applicable).

### 3. Tag the doc commit

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

N=$(next_tag_n doc)
git tag "dev/doc-${N}" HEAD
echo "🏷️ dev/doc-${N} anchored."
```

## Workflow integration

`/spec` tags its commit `dev/doc-NNN`. Doc commits are preserved by `/done`'s squash (defensive path) and skipped over by type detection — they will never flip the next iteration's `feat:`/`refactor:` classification. Run right after `/done`; running later is fine but the input is always the *most recent* `dev/done-NNN`.

## When to run

- Right after `/done` — the standard case.
- After a `/done` that introduced behavior the AI will need to reason about in future sessions (i.e. almost always).

## When NOT to run

- Mid-iteration, before `/done` has squashed and tagged. The agent has no stable input.
- For pure-mechanical iterations (rename-only, formatting-only) where there is genuinely nothing to spec. Skip rather than produce filler.

## Output

```
✓ Live spec written: docs/features/<slug>.md
  Drift: <"no drift" | "N docs updated">
  Tag: dev/doc-NNN

Next: continue with /plan, or run /design-audit on the same dev/done-NNN.
```

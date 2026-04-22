---
description: Check if CLAUDE.md needs updates based on project evolution, and proactively update it.
model: sonnet
allowed-tools: Read, Grep, Glob, Edit, Write, Bash
---

# Sync Configuration

Dispatch to the **docs-writer** agent targeting `CLAUDE.md`. The agent audits project state against documented conventions and updates only what's drifted. The agent's auto-add rules (major deps, patterns used 3+ times, structure changes) and never-auto-add rules (minor utilities, one-off patterns) still apply.

## Context
- CLAUDE.md: @CLAUDE.md
- Structure: !`find . -type f \( -name "*.py" -o -name "*.ts" -o -name "*.js" \) 2>/dev/null | grep -v node_modules | head -20`
- Package: !`cat package.json 2>/dev/null || cat pyproject.toml 2>/dev/null | head -20`

## Task

**Dirty-tree warning (advisory):** If the working tree has pending changes before this step, they may be folded into the doc commit:
```bash
if ! git diff --quiet || ! git diff --cached --quiet; then
  echo "⚠️ Working tree had pending changes before the doc pass — they may be folded into the doc commit. Review the resulting commit before continuing."
fi
```
This check is advisory only — do not exit.

1. **Audit** project state:
   - New dependencies?
   - Structure changes?
   - New patterns (used 3+ times)?
   - Tooling changes?

2. **Compare** with CLAUDE.md - what's documented vs reality

3. **Report**:
   ```
   ✅ Up to date: [items]
   🔄 Needs update: [items]
   ```

4. **Update** (if approved):
   - Add new sections
   - Update structure
   - Preserve core philosophy

5. **Commit**: `docs(claude): sync with project state`

6. **Tag the doc commit.**
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

This command tags the resulting commit `dev/doc-NNN`. Doc commits are preserved by `/done`'s squash (defensive path) and skipped over by type detection — they will never flip the next iteration's `feat:`/`refactor:` classification. Run freely between iterations or, with caution, mid-iteration.

## Auto-add
- Major dependencies (db, frameworks)
- Patterns used 3+ times
- Significant structure changes

## Never auto-add
- Minor utilities
- One-off patterns
- Temporary code

## Output
```
✓ Sync complete
  Files: [list]
  Tag: dev/doc-NNN

Next: /review or continue feature work
```

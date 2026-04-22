---
description: Check if README.md needs updates based on project evolution, and proactively update it.
model: sonnet
allowed-tools: Read, Grep, Glob, Edit, Write, Bash
---

# Sync README

Dispatch to the **docs-writer** agent targeting `README.md`. The agent verifies each claim against code reality, classifies drift, and updates only what's wrong.

## Context
- README: !`cat README.md 2>/dev/null | head -50 || echo "No README.md"`
- Package: !`cat package.json 2>/dev/null || cat pyproject.toml 2>/dev/null | head -20`
- Entry points: !`grep -r "main\|cli\|bin" package.json pyproject.toml 2>/dev/null | head -5`

## Task

**Dirty-tree warning (advisory):** If the working tree has pending changes before this step, they may be folded into the doc commit:
```bash
if ! git diff --quiet || ! git diff --cached --quiet; then
  echo "⚠️ Working tree had pending changes before the doc pass — they may be folded into the doc commit. Review the resulting commit before continuing."
fi
```
This check is advisory only — do not exit.

1. **Verify installation**:
   - Commands actually work?
   - Prerequisites listed?
   - Version requirements current?

2. **Verify usage examples**:
   - CLI commands exist and work?
   - API examples match actual signatures?
   - Config options documented?

3. **Verify API docs**:
   - Public functions/classes documented?
   - Parameters/returns accurate?
   - Examples runnable?

4. **Report**:
   ```
   ✅ Accurate: [sections]
   🔄 Outdated: [sections + what's wrong]
   ❌ Missing: [sections]
   ```

5. **Update** (if approved) and commit: `docs(readme): update documentation`

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

## Priority Fixes
1. Broken install commands
2. Wrong CLI/API usage
3. Missing required config
4. Outdated examples

## Ask First
- Adding new sections
- Removing existing content
- Changing project description

## Output
```
✓ README updated
  Sections: [list]
  Tag: dev/doc-NNN

Next: /review or continue feature work
```

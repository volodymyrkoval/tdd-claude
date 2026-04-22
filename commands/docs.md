---
description: Generate technical documentation for an implemented feature.
model: sonnet
allowed-tools: Read, Grep, Glob, Edit, Write, Bash
---

# Generate Technical Documentation

Dispatch to the **docs-writer** agent. The agent owns doc-vs-code verification, drift classification, and the write/commit. Do not inline doc work here.

## Context
- Plan: !`cat .claude/plans/*.md 2>/dev/null | head -40 || echo "No plan"`
- Branch: !`git branch --show-current`
- Changed files: !`git diff main --name-only 2>/dev/null | head -20`

## Task

**Dirty-tree warning (advisory):** If the working tree has pending changes before this step, they may be folded into the doc commit:
```bash
if ! git diff --quiet || ! git diff --cached --quiet; then
  echo "⚠️ Working tree had pending changes before the doc pass — they may be folded into the doc commit. Review the resulting commit before continuing."
fi
```
This check is advisory only — do not exit.

1. **Identify what needs docs**:
   - New public APIs/functions
   - New CLI commands/flags
   - Configuration options
   - Integration points

2. **Generate documentation**:

   **Code-level** (in source files):
   - JSDoc/docstrings for public functions
   - Type annotations where missing
   - Inline comments for complex logic only

   **API docs** (if applicable):
   - Endpoint documentation
   - Request/response examples
   - Error codes

   **Usage docs** (in README or docs/):
   - How to use the feature
   - Configuration required
   - Examples

3. **Report**:
   ```
   📝 Documented:
     - [file]: [what was documented]

   ⏭️ Skipped (internal/obvious):
     - [items]
   ```

4. **Commit**: `docs: add documentation for <feature>`

5. **Tag the doc commit.**
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

## Document
- Public APIs and exports
- Non-obvious behavior
- Required configuration
- Breaking changes

## Skip
- Internal/private functions
- Self-explanatory code
- Implementation details
- Temporary code

## Output
```
✓ Documentation complete
  Added: N items
  Files: [list]
  Tag: dev/doc-NNN

Next: /review
```

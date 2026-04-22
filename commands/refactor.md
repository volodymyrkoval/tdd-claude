---
description: Clean up code without changing behavior. Refactor phase of TDD.
model: sonnet
allowed-tools: Read, Grep, Glob, Edit, Write, Bash
---

# 🔵 Refactor Phase

Proactively use the **senior-dev** agent to refactor safely.

## Context
- Branch: !`git branch --show-current`
- Tests: !`npm test 2>/dev/null || pytest 2>/dev/null || echo "Run tests"`

## Task

1. **Verify green** - all tests must pass first
2. **Identify smells** - duplication, unclear names, long functions
3. **One change at a time** - test after each
4. **Stop when clean** - don't over-refactor

## Common Refactorings
| Smell | Fix |
|-------|-----|
| Duplicate code | Extract function |
| Unclear name | Rename |
| Long function | Extract |
| Deep nesting | Guard clauses |

## Boundaries
✅ Rename, extract, inline, simplify
❌ Change behavior, add features, add tests

## Output
```
✓ Refactored: <what improved>
  Tests: green
Next: /commit
```

If nothing to refactor:
```
✓ Code is clean
Next: /commit
```

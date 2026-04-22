---
description: Start a new feature — create branch and estimate complexity.
argument-hint: <feature-name> [--legacy]
model: haiku
allowed-tools: Bash(git:*)
---

# Start New Feature: $ARGUMENTS

## Context

- Current branch: !`git branch --show-current`
- Working tree: !`git status --porcelain 2>/dev/null || echo "n/a"`
- Recent commits: !`git log --oneline -5 2>/dev/null || echo "No git history"`

## Task

### Step 1: Parse Arguments

Feature name: extract from `$ARGUMENTS` (kebab-case).
Flags:
- `--legacy`: working with existing codebase without tests — note for later planning.

### Step 2: Create Branch

**Pre-flight:**
- Working tree must be clean. If `git status --porcelain` is non-empty, stop: "⚠️ Commit or stash changes before starting a new feature."
- If already on a `feature/*` branch, confirm with the user before switching away.

```bash
git checkout -b feature/<feature-name>
```

### Step 3: Estimate Complexity

Assess the feature:

| Complexity | Indicators |
|------------|------------|
| **Simple** | Single component, clear scope, familiar patterns |
| **Medium** | Multiple components, some unknowns |
| **Complex** | Multiple integrations, security concerns, architectural decisions |

Report the estimate — do **not** plan or write code.

## Response Format

```
✓ Feature started: <feature-name>
  Branch: feature/<feature-name>
  Complexity: [Simple|Medium|Complex]
  Flags: [--legacy if set]

Next step: /plan <feature-name> to draft the plan.
```

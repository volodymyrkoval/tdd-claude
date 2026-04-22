---
description: Review code for quality, security, and maintainability issues.
model: sonnet
allowed-tools: Read, Grep, Glob, Edit, Bash(git:*), Bash(npm test:*), Bash(pytest:*)
---

# Code Review

Proactively use the **reviewer** agent to analyze code quality.

## Context
- Branch: !`git branch --show-current`
- Plan: !`ls docs/plans/ docs/archive/ 2>/dev/null | grep -v TEMPLATE | head -5`

## Determine Diff Range

1. Find the active plan in `docs/plans/` (or `docs/archive/` if already done).
2. Scan the plan for the last line matching `reviewed @ <sha>`. That SHA is the diff base.
3. If no such line exists, diff from `main` (or fall back to `HEAD~N` as before).

```bash
# example diff commands
git diff <last-reviewed-sha>..HEAD          # since last review
git diff main                               # first review on a feature branch
```

## Checklist

| Category | Check |
|----------|-------|
| **Correctness** | Logic correct, edge cases, errors handled |
| **Security** | No secrets, input validation, no injection |
| **Testing** | Behaviors covered, isolated, edge cases |
| **Quality** | Small functions, meaningful names, no duplication |
| **Performance** | No N+1, appropriate data structures |

## Classify Issues

- 🔴 **Critical**: Security, data loss, broken functionality
- 🟡 **Warning**: Bugs, performance, maintainability
- 🔵 **Suggestion**: Style, minor optimizations

## After Review

Append a review marker to the end of the plan file (active or archived):

```
reviewed @ <current HEAD short sha>
```

Fix commits made in response to review feedback are absorbed by the next `/done` squash. No `dev/*` tag is written by `/review` — the squash range `(dev/plan-N, HEAD]` automatically includes all commits since the plan was anchored, including review fixes.

## Output
```
# Review: <feature>

## Summary
[One paragraph — scope: "since <sha>" or "full branch"]

## Critical (N)
[List or "None"]

## Warnings (N)
[List or "None"]

## Good
[Positive observations]

## Verdict
[ ] ✅ Ready to merge
[ ] 🔄 Needs changes
[ ] ❌ Needs rework

To fix: /plan to add items, then TDD cycle.
```

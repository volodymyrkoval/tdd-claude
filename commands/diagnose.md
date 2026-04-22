---
description: Targeted debugging — reproduce, bisect, instrument. Produces a diagnosis, not a fix.
argument-hint: <symptom description>
model: opus
allowed-tools: Read, Grep, Glob, Edit, Write, Bash
---

# Diagnose: $ARGUMENTS

Dispatch to the **debugger** agent. The agent's job is to reproduce the symptom, identify the root cause, and hand off to lead-dev for the fix under TDD.

## Context
- Branch: !`git branch --show-current`
- Recent commits: !`git log --oneline -10 2>/dev/null`
- Working tree: !`git status --porcelain 2>/dev/null`

## Task

Invoke the debugger agent with:
- Symptom description from `$ARGUMENTS`
- Context above

Do not fix the bug yourself. The debugger investigates and diagnoses — the fix is a separate step via lead-dev under TDD.

## Output

Forward the debugger's structured diagnosis report. Then suggest the next step:
- If root cause identified → `/plan <fix-slug>` to plan the fix, then dispatch lead-dev.
- If repro failed → report blocker; ask user for more context (logs, env, exact steps).

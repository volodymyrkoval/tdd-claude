---
name: todo-tracking
description: Use when a `docs/plans/` file exists — the plan's checkboxes are the authoritative todo list. Governs how to pick the next item, mark it complete, and when TaskCreate is vs. isn't allowed. Use whenever dispatching dev agents against a plan, checking what's next, or archiving a finished plan.
---

# Todo Tracking

Progress = items completed. All boxes checked = feature done.

## Authority

**If any non-template plan file exists in `docs/plans/` (walking up from cwd), those plan files ARE the todo list** — not Claude Code's internal `TaskCreate` state. Applies regardless of git branch or whether the project is a git repo at all. The planner produces the plan; dev agents mutate its checkboxes as they complete work; commits (when in git) capture the diff.

- Do NOT call `TaskCreate` or `TaskUpdate` while a plan is present. A PreToolUse hook (`~/.claude/hooks/plan-as-todo.sh`) denies those calls with a message pointing to the active plan(s).
- To pick the next item: `Read` the plan → find first unchecked `- [ ]` under `## Todos` → dispatch the matching dev-tier agent.
- To complete an item: after the dev agent commits, `Edit` the plan to flip `- [ ]` → `- [x]`.
- When a plan is finished, archive it: move to `docs/archive/`. Once archived, `TaskCreate` unblocks for ad-hoc work.
- `TaskCreate`/`TaskUpdate` remain available when no plan file exists in `docs/plans/` — use them for ephemeral orchestration that shouldn't persist.

## Rules

1. Work in order (sequential unless dependencies require otherwise)
2. One todo at a time per TDD cycle
3. Update immediately after commit — **always append the short SHA** (`git rev-parse --short HEAD`): `- [x] <text> · <sha>`
4. Never add todos without approval

## Todo Item Requirements

- **Testable:** Can write a test proving it works
- **Single behavior:** One thing, not multiple
- **Clear completion:** Obvious when done
- **Small:** One TDD cycle

## Workflow

**Start:** Read plan → Find first unchecked → Announce → Begin TDD

**Complete:** Tests pass → Commit → `git rev-parse --short HEAD` → Update plan `[ ]` → `[x] <text> · <sha>` → Announce

## Progress Display Rules

**Always show progress card:**
- At **start** of agent work (after reading plan)
- At **end** of agent work (before handoff)

## Progress Card Template

```
╭─ Progress ──────────────────────────╮
│ 📋 feature-name                     │
│ 🔴 Phase: Red                       │
│ ▸ Current: <todo item>              │
│ Progress: ████░░░░░░ 2/5            │
╰─────────────────────────────────────╯
```

**Phase indicators:** 🔴 Red │ 🟢 Green │ 🔵 Refactor │ 📋 Planning │ 🔍 Review

**Progress bar:** Use █ for complete, ░ for remaining (10 chars total)

## Legacy Format (simple contexts)

```
Feature: <name>
Progress: X/Y todos (Z%)
Current: <current item>
Next: <next item>
```

## Feature Completion

1. All todos [x]
2. All acceptance criteria [x]
3. Full test suite passes
4. Move plan to `docs/archive/`
5. Report complete

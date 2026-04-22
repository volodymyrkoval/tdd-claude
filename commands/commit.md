---
description: Commit completed TDD cycle with conventional commit message.
model: haiku
allowed-tools: Bash(git:*), Read, Edit
---

# Commit TDD Cycle

## Context
- Branch: !`git branch --show-current`
- Status: !`git status --short`

## Steps

1. **Verify tests pass** - if failing, stop: "⚠️ Tests failing — fix before committing"
2. **Stage changes** - review `git status` and stage specific files by name (e.g. `git add src/foo.ts tests/foo.test.ts`). Never use `git add -A` / `git add .` — it can sweep in secrets or unrelated work.
3. **Commit** with Conventional Commits:
   ```
   type(scope): description
   ```
   Types: `feat`, `fix`, `refactor`, `test`, `docs`, `chore`
4. **Update plan** - find the active plan in `docs/plans/` and check off the completed todo, appending the short commit SHA inline:
   ```
   - [x] <todo text> — <effort>, <tier> · <sha>
   ```

## Output
```
✓ Committed: <message>
  Files: N changed
  Todo: <item checked> · <sha>
Next: continue TDD
```

---
description: Sweep code comments per the code-comments skill — fix violations, commit per file, behavior unchanged.
model: sonnet
allowed-tools: Read, Grep, Glob, Edit, Write, Bash, Task
argument-hint: "<full | paths:<glob> | path/to/dir> [--plan | --force] [--tier=junior|senior]"
---

# /audit-comments

Sweep the resolved scope, fix comments per the `code-comments` skill, commit per file. **Behavior must not change.**

Distinct from the inline opportunistic-cleanup that dev agents already do during normal TDD — `/audit-comments` is the deliberate pass when you want to fix existing code in bulk.

## Context
- Branch: !`git branch --show-current 2>/dev/null || echo "no-git"`
- Uncommitted: !`git status --porcelain 2>/dev/null | wc -l | tr -d ' '` files
- Test gate: !`test -f .claude/test-cmd && echo "✓ pre-commit-green active" || echo "⚠️ no .claude/test-cmd — behavior changes won't auto-fail"`

## Arguments

Raw: `$ARGUMENTS`

**Scope** (required, exactly one):

| Form | Means |
|------|-------|
| `full` | Entire repo from cwd, with skip patterns below |
| `paths:<glob>` | Explicit glob, e.g. `paths:src/billing/**/*.ts` |
| `<path>` (bare) | Shorthand for `paths:<path>/**` |
| (empty) | Refuse with usage |

**Flags:**
- `--plan` — invoke **planner** to break the sweep into per-file todos instead of dispatching directly. Recommended for large `full` sweeps when you want a review checkpoint.
- `--force` — proceed with direct dispatch even when scope is large (>50 files).
- `--tier=<junior|senior>` — override the dev tier (default `junior`). Use `senior` for security-sensitive code, complex domain logic, or public-facing API surface where comment quality is high-leverage.

## Skip patterns (always)

`node_modules/`, `dist/`, `build/`, `.next/`, `.nuxt/`, `vendor/`, `__pycache__/`, `.venv/`, `target/`, `coverage/`, `.git/`, `.claude/`, `docs/`, test fixtures, snapshots (`*.snap`, `__snapshots__/`), generated (`*.generated.*`, `*.g.ts`, `*_pb2.py`), lockfiles (`package-lock.json`, `yarn.lock`, `Cargo.lock`, `poetry.lock`, `Pipfile.lock`), migrations (`migrations/`, `db/migrate/`).

Source extensions: `*.{ts,tsx,js,jsx,py,go,rs,java,rb,cs,kt,swift,php,scala,ex}`

## Flow

### 1. Preflight

- Working tree must be clean. If dirty, refuse:
  > "Commit or stash first — per-file commits would otherwise mix with uncommitted work."
- Resolve scope to a file list. Print count + 5-file preview so the user can sanity-check.
- If `.claude/test-cmd` is absent, warn (don't refuse): behavior changes won't be caught by pre-commit-green; the agent's own "comments only" discipline is the only guard.

### 2. Safety gate (only for `full`)

If file count > 50 and neither `--plan` nor `--force` is set:
```
⚠️ N files in scope. A direct sweep of this size is hard to review.
   Re-run with --plan to break into per-file todos,
   or --force to proceed with sharded parallel dispatch.
```
Stop. Do not dispatch.

### 3a. `--plan` mode

Dispatch **planner** with:

> Audit code comments in `<scope>` per the `code-comments` skill. Resolved files: `<file list>`. Each file is one todo, effort `S`, tier `<resolved-tier>-dev`. Group todos by top-level source directory under sections, but commit per file. Each todo must: invoke `code-comments`, fix violations (§1 missing docs on exports, §3 inline-comment misuse, §5 anti-patterns, §6 nearby debt), commit `docs(comments): <relative-path>`. **Comments only — no signature, behavior, or refactor changes.** No new tests required.

Planner writes the plan to `docs/plans/`. After it returns, tell the user:
> Plan written. Run `/implement` to execute.

### 3b. Direct dispatch (default, or `--force`)

Group files by top-level source directory (`src/billing/`, `lib/`, `pkg/auth/`, …). Dispatch one agent per group **in parallel** (single message, multiple `Task` calls).

If the file list yields more than 4 groups, bucket into 4 by total file count (round-robin on size) so no agent's context blows up.

Per agent (default tier: `junior-dev`; `senior-dev` if `--tier=senior`):

```
Audit comments in this group per the `code-comments` skill.

Files (process each in order):
  <list>

For each file:
  1. Read it.
  2. Invoke the `code-comments` skill.
  3. Apply §1 (docstrings on exports), §3 (inline comments earn place),
     §5 (no anti-patterns), §6 (cleanup nearby debt).
  4. If changes are needed: edit, then commit
     `docs(comments): <relative-path>`.
  5. If already clean: skip, no commit.

Hard rules:
  - **Comments only.** No signature changes, no extracts, no refactors.
    If a §6 cleanup tempts a code change, leave the comment untouched
    and flag the file instead.
  - **One commit per file.** `git add <specific-file>`, never -A / .
  - **No invented invariants.** If a doc would assert something you
    can't verify from the code, omit it. Flag the file.
  - **Behavior conflict = stop.** If an existing comment contradicts
    current behavior and you can't tell which is right (the comment is
    stale vs. the code is buggy), do not edit that file. Add it to
    your flagged list and continue.
  - Pre-commit-green will run the existing test suite per commit. If
    it fails, your edit must have changed behavior — revert the file
    and flag it.

Return a short summary:
  - touched: <count>
  - skipped (already clean): <count>
  - flagged (need human): <list of "<file>: <reason>">
```

### 4. Synthesis

After all agents return, sum their counters and emit:

```
# Comment Audit: <scope>

Scope:    <description>
In-scope: N files
Touched:  M files (M commits)
Skipped:  K files (already clean)
Flagged:  P files

## Flagged for human review
- <relative-path> — <reason>
- ...

## Next
- /review to sanity-check the sweep
- git log --oneline --grep '^docs(comments)' to see the commit trail
- For each flagged file: decide whether the comment is stale (fix the
  comment) or the code drifted from intent (open a bug, plan a fix).
```

## Boundaries

| ✅ In scope | ❌ Out of scope |
|-------------|-----------------|
| Add JSDoc/docstrings missing on exports | Refactor names or extract functions |
| Fix anti-pattern comments (restatements, commented-out code, undated TODOs) | Change function signatures or behavior |
| Update headers contradicted by current behavior | Add or modify tests |
| Clean up §6 nearby debt within already-touched files | Sweep outside the resolved scope |
| Add file/module headers per §2 when the file qualifies | Batch multiple files into one commit |

## Notes

- Tag-family agnostic: `/audit-comments` does **not** write a `dev/*` tag. It's a maintenance sweep, not a workflow phase. Run anytime between iterations.
- Bisectability is the point of per-file commits. If a comment turns out to be wrong, `git log -p -- <file>` shows exactly when it landed.
- For incremental adoption: start with `paths:src/<core-module>/**` and high-traffic public API, not `full`. The goal is faster context-building on the code you re-read most, not 100% coverage.

---
description: Zero-tolerance structural audit against SOLID, Clean Code, Fowler's smells.
model: sonnet
allowed-tools: Read, Grep, Glob, Write, Bash(git:*), Bash(wc:*), Bash(find:*), Bash(ls:*), Bash(mkdir:*), Bash(date:*), Bash(sort:*), Bash(head:*), Bash(awk:*), Task
argument-hint: "[diff | full | paths:<glob>] [--parallel | --shards=N] [--plan]"
---

# Design Audit

Dispatch the **design-critic** agent. It is uncompromising — a structural bulldog. Use this when you want violations named, not softened.

Distinct from `/review`:
- `/review` = balanced pass (correctness + security + maintainability), produces verdict + suggestions
- `/design-audit` = structural pass only, zero tolerance, violations only, PASS/REWORK verdict

## Context
- Branch: !`git branch --show-current 2>/dev/null || echo "no-git"`
- Changes: !`git diff main --stat 2>/dev/null || git diff --stat "HEAD~$(( $(git rev-list --count HEAD 2>/dev/null || echo 1) > 5 ? 5 : $(git rev-list --count HEAD 2>/dev/null || echo 1) - 1 ))" 2>/dev/null || echo "no diff"`
## Arguments

Raw: `$ARGUMENTS`

Parse into three slots (flags may appear in any order):

**Scope** (one of):
- `diff` or empty → audit the current diff against `main` (or `HEAD~5` if no main)
- `full` → full codebase sweep
- `paths:<glob>` → audit files matching the glob (e.g. `paths:src/domain/**/*.ts`)

**Parallelism** (only meaningful with `full`; ignored otherwise):
- no flag → single sequential agent
- `--parallel` → shard by top-level source directories (auto-detect)
- `--shards=N` → force N shards, bucket files evenly

**Chaining:**
- `--plan` → after audit, if verdict is ❌ REWORK, dispatch **planner** with the unified audit file as input

## Thresholds (reminder — agent enforces these)

| Unit | Warn | FAIL |
|------|------|------|
| Method LOC | >20 | >40 |
| Class LOC | >200 | >400 |
| File LOC | >300 | >500 |
| Nesting depth | — | >2 |
| Parameters | — | >3 |

## Dispatch

Ensure `docs/design-audits/` exists (`mkdir -p docs/design-audits`).

### Preflight: require a finalised iteration

```bash
LATEST_DONE=$(git tag --list 'dev/done-*' | sort | tail -1)
if [ -z "$LATEST_DONE" ]; then
  echo "⚠️ No dev/done-NNN exists yet — run /done first."
  exit 1
fi
if ! git merge-base --is-ancestor "$LATEST_DONE" HEAD 2>/dev/null; then
  echo "⚠️ /design-audit must run on a finalised iteration (dev/done-NNN must be an ancestor of HEAD)."
  echo "   HEAD is at $(git rev-parse --short HEAD); latest dev/done is $(git rev-parse --short "$LATEST_DONE")."
  echo "   Run /done first."
  exit 1
fi
```

### Mode A: sequential (default, or any scope other than `full`)

Invoke one design-critic agent with the resolved scope. It writes `docs/design-audits/NNN-<scope-slug>.md` (sequential number, see agent Persistence section) and emits the report to stdout.

### Mode B: parallel (only for `full` + `--parallel` or `--shards=N`)

1. **Determine shards.**
   - If `--shards=N`: list all source files (respecting skips below), sort by size descending, bucket into N groups using round-robin on size (keeps buckets balanced).
   - If `--parallel` (no N): detect top-level source directories. Try in order: `src/*/`, then top-level project subdirs excluding skips. Each directory = one shard. If there are fewer than 2 candidates, fall back to `--shards=4`.
   - **Skip patterns** (never include): `node_modules/`, `dist/`, `build/`, `.next/`, `.nuxt/`, `vendor/`, `__pycache__/`, `.venv/`, `target/`, `coverage/`, `.git/`, `.claude/`, test fixtures, generated files (`*.generated.*`, `*.g.ts`, etc.), lockfiles.
   - **Shard slug**: kebab-case the path (`src/domain` → `src-domain`). For bucket mode without a dir label: `bucket-1`, `bucket-2`, etc.

2. **Spawn agents in parallel** — one Agent call per shard plus one for architecture, all in a single message:

   - For each shard, dispatch **design-critic** with:
     ```
     Scope: paths (the shard's file list)
     Files: <explicit list>
     output_path: docs/design-audits/<NNN>-full-<shard-slug>.partial.md
     ```
     Tell the agent to write its report to that exact path (it honors `output_path` per its Persistence section) and to emit a short stdout summary (verdict + violation count).

   - Dispatch one more **design-critic** with:
     ```
     Scope: architecture
     output_path: docs/design-audits/<NNN>-full-architecture.partial.md
     ```
     This agent runs in parallel with the shards since it reads only imports/module boundaries, not bodies.

3. **Wait for all agents to finish.** They return their verdicts.

4. **Synthesize.** Main thread reads every `*.partial.md` written above and produces the unified `docs/design-audits/<NNN>-full.md`:

   **Frontmatter** (compute from partials):
   ```markdown
   ---
   scope: full
   run: <NNN>
   verdict: <PASS if every partial is PASS, else REWORK>
   violation_count: <sum of partial counts>
   shards: [<list of shard slugs including "architecture">]
   ---
   ```

   **Body structure:**

   ```markdown
   # Design Audit: Full Codebase

   ## Verdict
   <PASS or REWORK>

   ## Summary
   <N total violations across M shards. One-line headline identifying the worst systemic issue — usually pulled from the architecture partial or the most violation-dense shard.>

   ## Architecture Findings
   <paste architecture partial's body — cross-module smells first, they set context>

   ## Per-Shard Findings
   ### <shard-slug-1>
   <paste that partial's Threshold violations + Violations by smell sections>

   ### <shard-slug-2>
   ...

   ## Systemic Patterns
   <if the same smell (e.g. Primitive Obsession on UserId) appears in 3+ shards, call it out here as a codebase-wide fix — don't make the user count occurrences>

   ## Priority
   1. <Cross-module issues from architecture partial — highest leverage>
   2. <Largest god classes across all shards>
   3. <Longest methods>
   4. <Most frequent smell codebase-wide>

   ## Partials
   - [docs/design-audits/<NNN>-full-<shard>.partial.md](...)
   - ...
   ```

   Keep partials on disk as the raw data trail.

5. **Emit to stdout**: the synthesis summary + the unified file path.

## After the audit

**Commit the report.** Always commit the audit file(s) before anything else:
```
git add docs/design-audits/<written-file(s)>
git commit -m "chore(design-audit): <scope-slug> — <PASS|REWORK> (<N> violations)"
```
Stage only the audit files — never `git add -A`.

**Tag the audit commit.**
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

N=$(next_tag_n audit)
git tag "dev/audit-${N}" HEAD
echo "🏷️ dev/audit-${N} anchored."
```

**If verdict is ✅ PASS:** Done.

**If verdict is ❌ REWORK and `--plan` was passed:**
Dispatch **planner** with:
> "Read `docs/design-audits/<unified-file>.md` and produce a refactor plan. Each violation (or violation cluster) becomes a todo. Prioritize per the audit's Priority section: cross-module issues first, then God classes, Long Methods, Primitive Obsession, everything else. Each refactor is its own commit — never mix refactoring with behavior change. Tag todos with effort (S/M/L) and recommended dev tier."

**If verdict is ❌ REWORK and no `--plan`:**
Report the unified path and suggest: "Run `/plan "refactor per <filename>"` to turn findings into todos, or rerun with `--plan` to chain automatically."

## Notes

- Refactoring fixes go through TDD (failing test pinning current behavior → refactor → green). Never fix inline from the audit.
- Parallel mode is best for full sweeps on projects >50 files. For smaller projects, sequential is simpler and cheaper.
- Partials are append-only (`-2`, `-3` suffixes on same-day reruns). Don't delete them — progress between audits is visible in the trail.
- **Output:** audit report written to `docs/design-audits/<NNN>-<scope-slug>.md`, tagged as `dev/audit-NNN` at the chore commit.

---
description: Run mutation testing on recent changes. Surfaces surviving mutants as new todos — real measure of test quality.
---

# /mutate

Run mutation testing (Stryker for TS/JS, mutmut for Python) on the current diff and report survivors.

## Flow

1. **Invoke the `mutation-testing` Skill** — reload the rubric (when to run, thresholds, survivor patterns).
2. **Detect stack:**
   - `package.json` contains `@stryker-mutator/core` → Stryker
   - `pyproject.toml` contains `mutmut` → mutmut
   - Neither → tell the user to install per `QUALITY_TOOLING.md` and stop.
3. **Determine scope:**
   - Default: files in `git diff main...HEAD` (fall back to `HEAD~1` if no `main`)
   - `--full` → entire `src/`
   - `--paths <glob>` → explicit paths
4. **Run the tool:**
   - Stryker: `npx stryker run --incremental --mutate "<files>"`
   - mutmut: `mutmut run --paths-to-mutate "<files>"` then `mutmut results`
5. **Parse the report:**
   - Stryker: `reports/mutation/mutation.json`
   - mutmut: `mutmut results` output
6. **Output:**
   - Mutation score (killed / total non-equivalent)
   - Each surviving mutant with `file:line` and the mutation diff
   - Verdict: ✅ ≥80%, 🟡 60–79%, ❌ <60%
7. **If a plan is active**, append each survivor as a new `- [ ]` todo under an "Uncovered mutations" heading in the plan file. Never overwrite existing todos.

## Guardrails

- Mutation testing is slow (minutes). Don't invoke inside the inner TDD loop.
- Survivors are *test gaps*. Only fix them by adding tests, never by modifying production code.
- If the project has no `.claude/test-cmd` or test command configured, stop and surface that to the user before running.

## Output format

```markdown
# Mutation Report: <scope>

Score: XX% (killed Y of Z non-equivalent)
Verdict: ✅ ship | 🟡 investigate | ❌ insufficient

## Survivors
- `src/foo.ts:42` — `<` → `<=` — no test covers the exact boundary
- `src/bar.ts:87` — deleted `return result` — return value never asserted
...

## Suggested todos (added to plan)
- [ ] Test: boundary at N for `computeThreshold`
- [ ] Test: assert return value of `bar()` in normal path
```

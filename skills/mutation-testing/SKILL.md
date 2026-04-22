---
name: mutation-testing
description: Measure real test quality by mutating source code and verifying that tests catch the changes. Use after significant Green phases, before /review, and when coverage looks complete but confidence is low.
---

# Mutation Testing

Coverage tells you the line executed. Mutation testing tells you the line was *tested*.

## When to run

✅ End of a plan, before merging
✅ When a reviewer suspects test theater (high coverage, low confidence)
✅ Before security-critical code ships
✅ After a refactor — surviving mutants reveal behavior tests didn't pin

❌ Mid-cycle (too slow — breaks the inner TDD loop)
❌ On trivial diffs (rename, typo, import reorder)

## How to run

Use `/mutate`. It detects the stack and runs on the diff by default.

| Stack | Tool | Invocation |
|-------|------|------------|
| TS/JS with Stryker | Stryker | `npx stryker run --incremental --mutate "<changed files>"` |
| Python with mutmut | mutmut | `mutmut run --paths-to-mutate "<changed files>"` |

If neither tool is installed, follow `QUALITY_TOOLING.md` or run `/bootstrap` on a fresh project.

## Reading the output

Each mutant is a deliberate code change (`<` → `<=`, `true` → `false`, delete a statement).

| Result | Meaning | Action |
|--------|---------|--------|
| **Killed** | A test failed — good | None. Tests did their job. |
| **Survived** | All tests passed despite the mutation — bad | Write a test that *would* have failed. Real gap. |
| **Timeout** | Tests hung (usually infinite loop from the mutation) | Review; may indicate a missing termination guard |
| **No coverage** | Line isn't exercised at all | Add a test, or delete the code |

**Every surviving mutant becomes a `- [ ]` todo** in the active plan (or a follow-up). Write the test that kills it in the next Red phase. Never "fix" by modifying production code to make the mutant die — that removes real behavior.

## Thresholds (gate, not target)

- **≥80% mutation score** — ship
- **60–79%** — acceptable; investigate survivors individually
- **<60%** — tests are insufficient; block merge

Don't chase 100%. Equivalent mutants (semantically identical changes) are unkillable. Focus survivors in business logic.

## Common survivor patterns

| Pattern | What it means | Test to add |
|---------|---------------|-------------|
| Boundary flip (`>` ↔ `>=`) | No test exercises the exact boundary | Input at the boundary value |
| Logical op (`&&` ↔ `\|\|`) | Missing case where only one operand is true | Both one-true-one-false combinations |
| Return value mutated | Return never asserted; only called for side effects | Assert on the return |
| Deleted statement | Statement is dead or untested side effect | Assert on observable consequence |
| `true` ↔ `false` constant | Constant is pass-through; no test checks the flipped path | Case where the flag changes behavior |

Each maps to a specific, narrow test.

## Discipline

- Run mutation testing *between* cycles, never inside one.
- Don't add mutation testing to commit hooks or CI gates that block everyday work — it's too slow. Treat it as a periodic quality sweep.
- A surviving mutant is a test gap, not a code bug. The fix is always a new test.

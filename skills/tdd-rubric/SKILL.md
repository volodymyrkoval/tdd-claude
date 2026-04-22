---
name: tdd-rubric
description: Checklist for three high-value TDD decisions — stub vs mock discipline, async test structure, and when to change an existing test. Use this skill whenever: deciding whether to use a stub or a mock; structuring tests for async functions that mix IO with logic; a test is failing and you're unsure whether to fix the test or the code; diagnosing too many mocks in a test file; spotting test code smells (conditional logic in tests, asserting on both a mock and a return value); dealing with flaky tests caused by time/date/randomness; deciding whether to delete a test after a feature is removed; doing a sanity check on a test after hitting green in a TDD cycle. Even when the user doesn't say "TDD" or "rubric" explicitly — if they're reasoning about test structure, mock discipline, or whether a test should change, this skill applies.
---

# TDD Rubric — Three Checks

Answer each one. If any answer is wrong, fix it before moving on.

---

## 1. Stub or Mock?

- **Stub** = incoming dep (data flowing in). Never assert on it.
- **Mock** = outgoing dep / exit point. Assert on it. **Max one per test.**

Wrong choice here means you're either asserting on the wrong thing or missing the real exit point entirely.

**~2–5% of tests need mocks.** If you're reaching for a mock, ask first: can I test this via return value or state change instead?

**Anti-patterns to catch now:**
- Asserting on a stub — it's not an exit point
- Verifying internal calls between things you own — only assert on calls to deps you don't control
- Over-specifying — exact object schemas, exact argument order unless order is a stated requirement; these break on refactoring even when behavior is correct
- Hardcoded dep (e.g. `new Date()` inline, `moment()` inline) — inject it or the test is flaky by design

**Jest:**
```js
jest.mock("./module-name")          // hoisted before imports
mockFn.mockReturnValue(value)       // stub indirect input
expect(mock).toHaveBeenCalledWith() // assert exit point
afterEach(jest.resetAllMocks)       // prevent state leaking between tests
```

---

## 2. Is this async? Split it.

Don't write async tests against logic you can test synchronously.

**Split into:**
- **Async shell** — one integration test for the fetch/IO
- **Sync logic core** — many unit tests for the processing; extract to a plain function, test it directly

**If you can't avoid async:**
- Timers → `jest.useFakeTimers()` + `jest.advanceTimersToNextTimer()`, not `global.setTimeout` monkey-patching
- Callbacks → extract success/error logic to named public fns, call via `done()`
- Await → move logic into plain fns that `return`/`throw`; the test stays synchronous

---

## 3. Should this test change?

Before touching an existing test, identify why it's failing:

| Cause | Action |
|-------|--------|
| Production bug | **Don't touch the test** — it's doing its job |
| Buggy test | Fix it — inject an obvious bug, confirm red, fix prod, confirm green |
| Requirement gone | Delete it |
| API/semantic change in prod | Update it |
| Flaky (moving parts: time, network, randomness) | Quarantine → stub the dep → convert to unit test → kill if cost > value |

**Logic in tests** (`if`, `for`, `try-catch`, string concatenation) creates lying tests — a bug in the algorithm makes the expected value wrong in exactly the same way. Always hardcode expected values.

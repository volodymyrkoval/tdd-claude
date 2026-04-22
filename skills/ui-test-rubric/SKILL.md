---
name: ui-test-rubric
description: Apply when writing a UI integration test at a component seam, when reasoning about test scope at component boundaries, when deciding what to mock in a UI test, or when an integration test is hard to write — re-check scope. Reusable by both ui-integration-tester (writer) and future ui-integration-auditor (auditor).
---

## 1. Scope — test one component seam

The test exercises the contract between two components at their boundary.
It renders the parent with real child components (no mocks of children).
It does not test internals of either side — only the observable output that crosses the seam.
One seam per test file.

## 2. What to mock — only things that leave the process

Mock: network calls, browser APIs (localStorage, fetch, navigator), timers, third-party SDKs that hit the network.
Do NOT mock: child components, sibling components, internal hooks, internal modules, shared utilities.
Explicit prohibition: do NOT add `vi.mock(...)` calls for child components anywhere in the test file. Do NOT inherit a mock of a child component from a setup/global file — if such a mock exists, override it to use the real implementation in this test.

## 3. Test anatomy — render → interact → assert user-visible output

1. Render the parent component with realistic (not minimal) props.
2. Interact via user events (fireEvent / userEvent) — not by calling component methods directly.
3. Assert on user-visible output: text, ARIA roles, DOM attributes visible to the user.
   Do not assert on implementation details (state variables, internal callbacks, prop forwarding).

## 4. Red criterion — behavioral, not structural

The test must fail because of a missing behavior, not because of a missing file or missing import.
module-not-found is acceptable red only before scaffolding files exist; once the surface exists, red must be a behavioral assertion failure.
A passing test that "asserts nothing" (no expect()) is not a valid green — add at least one behavioral assertion before calling it green.

## 5. Mutation check (self-discipline)

After writing the test, mentally delete the implementation of the behavior under test.
The test must still fail (red) when the behavior is absent.
If the test would pass with the behavior deleted, the assertion is testing structure, not behavior — rewrite it.
(This is a self-check discipline. No tooling enforced here — the auditor sibling validates later.)
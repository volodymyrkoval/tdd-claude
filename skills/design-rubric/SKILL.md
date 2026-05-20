---
name: design-rubric
description: Use this skill when the user is reasoning about the *shape* of code — not its runtime behavior, but its structure and responsibilities. Triggers on questions like "is this class too big?", "should I split this?", "what's the smell here?", "should I use pattern X or wait?", "what principle applies here?", "is this a god class?", or "how do I draw this boundary?". Covers class and module design decisions, code smell identification (god classes, message chains, feature envy, shotgun surgery, leaky abstractions, etc.) and canonical refactorings, SOLID principles, Clean Code heuristics, Fowler's refactoring catalog, and DRY/KISS/YAGNI trade-offs. Also apply proactively when planning new components or reviewing existing code for structural problems. Does NOT apply to: debugging runtime errors, test structure decisions (use tdd-rubric), security reviews, performance optimization, or deployment.
---

# Design Rubric

A forcing function. Answer the questions — don't just recite the principles.

If a conflict arises between rules, the **Tie-Breakers** section wins.

---

## 1. Tie-Breakers (resolve conflicts first)

| Tension | Default winner | Why |
|---------|----------------|-----|
| KISS vs DRY | **KISS** until 3 occurrences | Two occurrences ≠ a pattern. Premature DRY couples unrelated things. |
| YAGNI vs OCP | **YAGNI** | Don't open for extensions you can't name. Add seams when the second need arrives. |
| Composition vs inheritance | **Composition** | Inherit only when LSP genuinely holds and you need subtype polymorphism. |
| Explicit vs clever | **Explicit** | Read 10×, write 1×. Clever loses. |
| Abstraction vs duplication | Abstract only if it **removes more complexity than it adds** | A wrong abstraction is costlier than duplication. |
| Decomposition vs readability | **Readability** | Split for responsibilities, never to hit a line count. Five fragments you must chase across a file read worse than one cohesive method that flows top-to-bottom. |
| Consistency vs correctness | **Correctness** | Don't propagate a bad pattern for symmetry. Fix the pattern. |
| Correctness vs performance | **Correctness** | Measure before optimizing. A fast wrong answer is still wrong. |

---

## 2. SOLID — as questions, per component

Apply to every non-trivial component in the design.

- **SRP** — *What is the one reason this changes?* If you list two, split. "Changes for reason A **and** reason B" = two components.
- **OCP** — *What variation is actually coming?* If you can't name a concrete next requirement, **no abstraction yet**. Add the seam with the second use case, not the first.
- **LSP** — *Does every subtype honor the base contract in behavior, not just signature?* Throwing `UnsupportedOperation`, tightening preconditions, or weakening postconditions = violation.
- **ISP** — *Would any client use <50% of this interface's methods?* Split. Fat interfaces force fake implementations.
- **DIP** — *Does this module depend on something more volatile than itself?* Invert. Policy should not depend on mechanism; domain should not depend on I/O.

---

## 3. Clean Code (Uncle Bob) — concrete checks

**Size & complexity — reason from principles, not line counts**

Length is a symptom. Cohesion, single responsibility, and one-level-of-abstraction are the diseases. Ask which principle a too-big unit is breaking; don't gate on LOC.

- **Methods / functions** — Uncle Bob: "small, then smaller." A method does **one thing at one level of abstraction**. Diagnostic: can you extract a chunk and give it a meaningful name *that pulls its weight*? Then it was doing more than one thing. Fowler's working heuristic: if it doesn't fit on screen without scrolling, your working memory is already fragmented reading it. Line counts are orientation, not a gate — a long method that does one thing and reads cleanly top-to-bottom is fine; a short one interleaving three concerns is not. The opposite mistake is just as real: shredding a cohesive sequence into a scatter of single-use helpers you must chase across the file hurts readability more than length ever did. Extract for a distinct responsibility, never to hit a number.

- **Classes** — length is the wrong question. The right one: describe the class's responsibility in one sentence **without "and" or "or."** Can't? Split. Cohesion test: do most methods use most fields, or do you see method clusters using disjoint field clusters? Disjoint = two classes pretending to be one (LCOM smell). Reason-to-change test: list every reason this class would change; more than one = SRP violation. A class hitting several hundred LOC almost always means SRP is broken — but treat the SRP failure as the bug, not the line count.

- **Files** — follow class size. Default: one public class per file. Acceptable exceptions: tightly coupled types — sealed hierarchies, value object families, internal helpers used only by the file's main class. Multiple unrelated types in one file → split.

- **Nesting depth** — each level is an obscured decision the reader must hold in working memory. Past ~2 levels the mental stack overflows. Cure is structural: **Guard clauses** for input validation, **Extract Method** to give a chunk a name and a single return value, **Replace Conditional with Polymorphism** when the nesting follows a runtime type discriminator.

- **Function parameters** — each parameter is a coupling point. Uncle Bob: "ideal is zero, three is a lot." Two specific smells: **Data Clumps** (parameters that always travel together → Parameter Object) and **flag arguments** (hidden if-statements → split the function).

- **Cyclomatic complexity** — each branch multiplies the test surface and the cognitive load. High CC is the math behind why **Long Method** is a smell. Same refactorings: Extract Method, Replace Conditional with Polymorphism (only when the type varies at runtime — otherwise you're trading branches for class explosion).

The diagnostic question for all of these is the same: **what principle is the size violating?** Fix the cause; length normalizes downstream.

**Functions**
- Do one thing at one level of abstraction
- **No flag arguments** (`foo(x, true)`). Split into `fooA(x)` and `fooB(x)`
- **Command-Query Separation:** a function either does something *or* returns something, not both
- Extract until you cannot extract any more *meaningful* name
- Use guard clauses and early returns to flatten nesting
- **Inline logic inside `if` conditions** — e.g. `if (user.age > 18 && user.country === "US" && !user.banned && user.subscription.status === "active")` — extract to a named predicate (`isEligibleForDiscount(user)`). The condition is asking to become a name.
- **Nested function declarations inside methods** — a declared `function foo()` or `const foo = () =>` used only once inside its parent that carries real logic → Extract Method to the enclosing class/module scope. A method must not hide other methods in its body. Trivial inline callbacks passed to higher-order functions are fine.

**Names**
- Reveal intent; if a comment explains the name, rename instead
- Pronounceable and searchable (`elapsedTimeMs`, not `etm`)
- No type/scope encoding (no Hungarian, no `m_`, no `I` prefix on interfaces)
- Classes = nouns, methods = verbs
- Same concept → same word everywhere in the codebase
- Replace magic numbers and magic strings with named constants

**Comments**
- Default: **don't write one.** A good name makes it redundant.
- Legitimate comments: non-obvious *why*, legal/licensing, public API contracts, warnings about subtle invariants
- Illegitimate: restating the code, commented-out code, changelog-in-file, "added by X for ticket Y"
- Never leave commented-out code. Delete it — version control remembers.

**Error handling**
- Prefer exceptions / Result types over error codes (in languages that support them)
- Never return `null` for collections — return empty
- Don't let `null` cross module boundaries; validate at the edge
- Never swallow exceptions — handle, wrap with context, or rethrow
- Exception messages state what was attempted, with what inputs, why it failed
- Define exception types around the **caller's needs**, not the thrower's internals
- Never use exceptions for control flow
- Fail fast. Make illegal states unrepresentable in the type system where possible.

**Formatting**
- Related concepts vertically close; unrelated separated by blank lines
- Declare variables near first use
- Caller above callee — top-down reading order

**Boy Scout Rule:** leave the campsite cleaner. Small cleanups inside the scope you're already touching. Not a license for drive-by refactors. **Never mix refactoring with behavior change in the same commit.**

---

## 4. Fowler's Code Smells → Refactoring

Scan design and code for these. Each smell has a canonical move.

| Smell | Fix |
|-------|-----|
| **Long Method** | Extract Method with intention-revealing name |
| **Large Class** | Extract Class / Extract Subclass — usually hides SRP violation |
| **Long Parameter List** | Introduce Parameter Object / Preserve Whole Object |
| **Divergent Change** (one class, many reasons to change) | Extract Class — split by reason-to-change |
| **Shotgun Surgery** (one change touches many classes) | Move Method/Field — find the missing abstraction |
| **Feature Envy** (method uses another class's data more than its own) | Move Method |
| **Data Clumps** (same fields travel together) | Extract Class / Introduce Parameter Object |
| **Primitive Obsession** (strings/ints carrying domain meaning) | Replace Primitive with Value Object (`UserId`, `Money`, `EmailAddress`) |
| **Switch Statements** (branching on type, repeated) | Replace Conditional with Polymorphism — **only if type varies at runtime** |
| **Speculative Generality** (unused hooks, "just in case" abstractions) | Collapse Hierarchy / Inline Class |
| **Temporary Field** (field set only sometimes) | Extract Class for the when-set state |
| **Message Chains** (`a.b().c().d()`) | Hide Delegate (Law of Demeter) |
| **Middle Man** (class just delegates) | Remove Middle Man |
| **Data Class** (fields + getters/setters, no behavior) | Move behavior to where data lives (anemic domain model fix) |
| **Refused Bequest** (subclass ignores parent's API) | Replace Inheritance with Delegation |
| **Comments** (explaining *what*) | Extract Method / Rename — the comment is asking to become a name |
| **Dead Code** | Delete it. Unused = noise. |
| **Mysterious Name** | Rename. If you can't name it, you don't understand it yet. |

---

## 5. Architectural principles

- **Dependency direction:** inward. Stable abstractions at the core; volatile details (DB, HTTP, time, filesystem) at the edges. Domain never imports infrastructure.
- **Separation of concerns:** UI ≠ domain ≠ persistence. Put them in separate modules and keep them there.
- **Isolate volatility:** wrap I/O, time, randomness, and third-party SDKs behind a thin seam so tests don't need them.
- **Pure core, imperative shell:** business rules as pure functions where possible; push mutation, I/O, and time outward. Makes the core trivially testable.
- **Tell, don't ask:** send commands to objects; don't pull their state out to decide for them.
- **Law of Demeter:** talk to friends, not strangers. One dot per expression as a soft target.
- **Composition root:** wire dependencies in exactly one place (main / factory / DI container). Business code never news up its collaborators.

---

## 6. Anti-patterns to actively reject

- **God objects / utility dumps** (`Helpers`, `Utils`, `Manager`) — naming is the tell; the class has no cohesion
- **Anemic domain model** — behavior orbiting data classes instead of living with them
- **Leaky abstractions** — repository returns SQL rows; HTTP client exposes response objects
- **Circular dependencies** between modules — always a design error, never "fine for now"
- **Temporal coupling** — `init()` then `start()` then `use()`; ordering not enforced by types. Make illegal states unrepresentable.
- **Premature generalization** — generics, plugins, config knobs, strategy patterns with one strategy
- **Over-mocking** — if tests mock everything, the design leaks. Test with real collaborators where cheap; mock only process/network boundaries.
- **Stringly-typed APIs** — `doThing("create", "user", "v2")` instead of types/enums
- **Global mutable state** — singletons holding data, module-level mutables. Pass dependencies explicitly.

---

## 7. Self-critique — answer before finalizing

A Medium/Complex design is not ready until these have concrete answers:

1. **Reason to change per component** — list the one reason for each. Any with two? Split.
2. **Change-impact radius** — pick the two most likely future requirements. How many components change? >2 signals wrong boundaries.
3. **Dependency direction** — does any arrow point from stable → volatile? Invert.
4. **Abstraction justification** — for each interface/base class: name the *concrete* second implementation. If none exists or is planned, delete the abstraction.
5. **Deletability test** — which components could be deleted with minimal loss? Delete them.
6. **Name smell** — any `Manager`, `Helper`, `Utils`, `Processor`, `Handler`, `Data`, `Info`? Rename to the actual responsibility, or admit it's a god class and split.
7. **Testability** — for each piece of logic, how is it tested without booting the whole system?
8. **What would a reviewer flag?** Write 3 concerns a strict reviewer would raise. Address or accept them consciously.

---

## 8. When to escalate the design

Stop and push back on the requirement itself when:
- The feature requires breaking a core boundary (domain imports DB, etc.)
- Implementing it would require weakening LSP on a widely-used hierarchy
- The "simplest" implementation introduces a circular dependency
- No amount of refactoring yields a design where SRP holds

The right fix may be to renegotiate scope, not to engineer around a broken requirement.

---

## 9. Tests

Tests are production code — same cleanliness bar.

- **F.I.R.S.T.** — Fast, Independent, Repeatable, Self-validating, Timely
- **AAA** — Arrange, Act, Assert, visually separated
- One assertion concept per test. Names describe behavior (`shouldRejectNegativeAmount`, not `test1`)
- No `sleep`. No order dependencies. No shared mutable state between tests.
- Test behavior, not implementation. Don't assert on private internals — you lock in the shape, not the contract.
- Mock only at process / network / time boundaries. Use real collaborators elsewhere (see §6: over-mocking).
- If a unit is hard to test, the design is wrong. Fix the design, not the test.

---

## 10. Agent behavior when applying this rubric

- Make the **minimum diff** that satisfies the request. No reformatting or restructuring of unrelated code in the same change.
- Boy Scout applies **only to files you are already editing**. Flag problems elsewhere; do not silently expand scope.
- Never mix refactoring with behavior change in a single commit. Separate them.
- When this rubric conflicts with existing project style, match project style and note the deviation — do not propagate it further without explicit agreement.
- When uncertain whether a rule applies, stop and ask. Do not guess.
- Never introduce a new rubric violation to ship faster. If a shortcut is the only viable path, name it explicitly in the PR/commit message so it is visible and tracked.
- State trade-offs out loud when two rules genuinely pull opposite ways — don't silently pick one.
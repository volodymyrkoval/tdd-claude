---
name: design-patterns
description: Design pattern advisor — helps choose the right pattern, and just as importantly, helps avoid premature or wrong ones. Invoke this skill whenever: planning a new component and wondering if a pattern applies; a plan or design has variation in behavior, creation, or communication that might grow; reviewing code where a pattern was applied and you want to check if it was the right call; someone asks "should I use X pattern?", "is this a Strategy?", "do I need a Repository here?"; the design has cross-cutting concerns, multi-step workflows, read/write divergence, or decoupled event flows. Also invoke proactively during planner and lead-dev design phases — pattern blindness is a common source of unnecessary complexity and missed structure. When in doubt, invoke — the self-critique section will tell you if a pattern isn't needed.
---

# Design Patterns Advisor

A forcing function for pattern thinking. The goal is not to apply patterns — it's to consciously decide whether one fits. Answer the checklist and self-critique questions before committing to a design.

## Step 1 — "Did you consider?" checklist

Work through the relevant groups for the problem at hand. You don't need all groups — skip what clearly doesn't apply. But for every group that *might* apply, consciously decide, don't silently skip.

### Creational
- [ ] Are there complex construction sequences, optional parameters, or multi-step object assembly? → **Builder**
- [ ] Does the caller need to create objects without knowing the concrete type? → **Factory Method / Abstract Factory**
- [ ] Are objects expensive to create and mostly identical? → **Prototype**
- [ ] Should exactly one instance coordinate shared state? → **Singleton** *(see self-critique — often wrong)*
- [ ] Are multiple related families of objects created together? → **Abstract Factory**

### Structural
- [ ] Are there cross-cutting concerns (logging, caching, auth, retry) layered onto an existing interface? → **Decorator** or **Proxy**
- [ ] Do two incompatible interfaces need to work together? → **Adapter**
- [ ] Is there a complex subsystem that callers shouldn't need to understand? → **Facade**
- [ ] Do you have a tree of objects treated uniformly as a whole? → **Composite**
- [ ] Is there a large number of fine-grained objects with shared intrinsic state? → **Flyweight**
- [ ] Do you need to decouple an abstraction from its implementation so both can vary independently? → **Bridge**

### Behavioral
- [ ] Does an algorithm or behavior vary by context and might add variants later? → **Strategy**
- [ ] Does an object's behavior depend on its current state and transitions between states? → **State**
- [ ] Do you need to encapsulate a request as an object (undo, queuing, logging operations)? → **Command**
- [ ] Do multiple objects need to react to events from one source, without tight coupling? → **Observer / Event Bus**
- [ ] Is there a fixed algorithm skeleton with steps that vary? → **Template Method**
- [ ] Do you need to traverse a structure without exposing it? → **Iterator**
- [ ] Do you need to add operations to objects without changing their classes? → **Visitor**
- [ ] Do objects need to communicate without knowing about each other? → **Mediator**
- [ ] Do you need to restore an object to a previous state? → **Memento**
- [ ] Do you need lazy evaluation of an expensive computation? → **Chain of Responsibility** or **Lazy Proxy**

### Data & Persistence
- [ ] Do you need to decouple domain logic from data access details? → **Repository**
- [ ] Do multiple repositories need to share a transaction boundary? → **Unit of Work**
- [ ] Do you need expressive, composable query conditions as objects? → **Specification**
- [ ] Is domain data mapping complex and varied? → **Data Mapper**

### Architectural
- [ ] Do read and write workloads have different scaling, model, or complexity needs? → **CQRS** *(read references/architectural.md)*
- [ ] Does a multi-step workflow span services and need rollback / compensation on failure? → **Saga** *(read references/architectural.md)*
- [ ] Should domain events drive side effects instead of direct calls? → **Domain Events / Event-Driven** *(read references/architectural.md)*
- [ ] Do you need a full audit trail of state changes? → **Event Sourcing** *(read references/architectural.md)*
- [ ] Is there a reusable selection / filtering rule that needs to be combined and tested independently? → **Specification** *(read references/architectural.md)*

---

## Step 2 — Quick reference table

| Pattern | Use when | Skip when |
|---------|----------|-----------|
| **Builder** | Construction has ≥3 optional parts or a required sequence | A plain constructor or named parameters do the job |
| **Factory Method** | Caller shouldn't own the concrete type; type may vary by subclass | Type is fixed and caller can just `new` it |
| **Abstract Factory** | Multiple related objects must be created as a consistent family | Only one object type is being created |
| **Prototype** | Cloning is cheaper than fresh construction; templates exist | Objects are cheap or vary little |
| **Singleton** | Truly one instance coordinates shared, mutable, process-wide state | Two instances would work fine; use DI instead |
| **Adapter** | Two incompatible interfaces must collaborate | You control both sides — change one instead |
| **Decorator** | Stack cross-cutting concerns without subclassing | There's only one concern; a subclass or wrapper is clearer |
| **Proxy** | Control access, add lazy loading, or log before delegation | Direct access works; a function wrapper suffices |
| **Facade** | Simplify a complex subsystem behind a single entry point | The subsystem is already simple |
| **Composite** | Trees of objects treated uniformly (files/folders, UI trees) | There's no recursive structure |
| **Bridge** | Abstraction and implementation must vary independently | Only one dimension varies |
| **Flyweight** | Thousands of near-identical objects; intrinsic state dominates | Object count is small |
| **Strategy** | An algorithm varies by context and callers swap it | Only one algorithm exists now and none are planned |
| **State** | Behavior changes significantly based on discrete state transitions | Logic is simpler as a flag or enum check |
| **Command** | Encapsulate requests for undo, queuing, or logging | Fire-and-forget calls; no replay/undo needed |
| **Observer** | Multiple consumers react to events from one producer | One consumer; a direct call is clearer |
| **Template Method** | A fixed algorithm skeleton has variable steps | Steps vary so much they share no skeleton |
| **Iterator** | Traverse a collection without exposing its internals | Language provides built-in iteration |
| **Visitor** | Add operations to a stable object hierarchy without modifying it | The hierarchy changes often (prefer polymorphism) |
| **Mediator** | Many objects communicate in complex ways; reduce coupling | Two or three objects; direct references are fine |
| **Memento** | Snapshot and restore state (undo stacks, game saves) | State is cheap to recompute |
| **Chain of Responsibility** | A request passes through a pipeline of handlers, any of which may handle it | Exactly one handler; routing is fixed |
| **Repository** | Domain logic must be isolated from persistence mechanics | You're in a CRUD app; Active Record is fine |
| **Unit of Work** | Multiple repositories share a transaction that must succeed or fail together | Single repository; the ORM handles transactions |
| **Specification** | Business rules are reusable, combinable, and independently testable | Rules are simple one-off predicates |
| **CQRS** | Reads and writes diverge in model, scaling, or team ownership | Simple CRUD where one model serves both |
| **Saga** | Multi-step workflows span services; partial failure needs compensation | The workflow is in one service/transaction |
| **Domain Events** | Side effects should be decoupled from the action that caused them | Direct method calls communicate intent clearly |
| **Event Sourcing** | Full audit trail required; temporal queries on state history needed | Current state is all you need |

---

## Step 3 — Self-critique (answer before finalizing)

These questions exist because pattern application is a common source of premature abstraction. A pattern that can't pass this checklist shouldn't be in the plan.

- [ ] **YAGNI test**: Is there actual evidence of the variation or growth that justifies this pattern, or is it a guess? One concrete case does not make a pattern.
- [ ] **Simpler alternative**: Could a well-named function, a plain class, or a direct dependency injection solve this without the pattern's indirection?
- [ ] **Indirection payoff**: What specific, concrete benefit does this pattern's extra layer buy? Name it — "flexibility" alone doesn't count.
- [ ] **Team legibility**: Will the next developer recognize this pattern immediately, or will it read as unnecessary machinery?
- [ ] **Testability**: Does this pattern make the code easier to test, or does it add seams that require more mocking?
- [ ] **Singleton check**: If you're considering Singleton — can a dependency injected instance serve the same purpose? (Almost always yes.)
- [ ] **Architectural pattern check**: If considering CQRS, Saga, or Event Sourcing — is the problem genuinely distributed/multi-service, or would a simpler in-process solution work? These patterns carry significant operational cost.

---

## How planner and lead-dev use this skill

**Planner:** After drafting component responsibilities, invoke this skill. Run Step 1 for each component. Patterns that pass self-critique become explicit todos. Patterns that fail self-critique get noted as "considered and rejected — reason: X" in Technical Notes.

**Lead-dev:** Before the first Red phase on a design-heavy todo, invoke this skill to validate the chosen approach. If a better pattern emerges, raise it before writing tests — changing the structural decision mid-cycle is expensive.

**Output format:** State the pattern, the concrete signal that justified it, and the self-critique answer that cleared it. Example:
> Strategy — PaymentProcessor behavior varies by provider (Stripe, PayPal, bank transfer) and new providers are a confirmed roadmap item (Q3). Simpler alternative: a switch statement would work now but breaks OCP on every new provider. Indirection payoff: each provider isolated and independently testable.

For architectural patterns (CQRS, Saga, Event Sourcing, Domain Events, Specification), read `references/architectural.md` before recommending.

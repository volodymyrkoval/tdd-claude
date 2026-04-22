# Architectural Patterns — Deep Reference

These patterns carry significant structural and operational weight. Read the full card before recommending one.

---

## CQRS (Command Query Responsibility Segregation)

**Intent:** Separate the model for writing state (commands) from the model for reading state (queries).

**Use when:**
- Read and write workloads have fundamentally different shapes (e.g., writes are normalized, reads need denormalized projections)
- Read scalability requirements differ from write scalability
- Query complexity is high and distorting the write model
- Team or service ownership splits cleanly along read/write lines

**Skip when:**
- A single model serves both reads and writes without awkwardness
- The team is small and operational overhead of two models isn't worth it
- You're in an early-stage product where the read model is still unknown
- CRUD with simple filtering — Active Record or a thin query layer is fine

**Cost:**
- Two codepaths to maintain
- Eventual consistency between write model and read projections (if async sync)
- More infrastructure: separate read stores, projection rebuilds
- Debugging across the read/write boundary is harder

**Self-critique:** What specifically makes one model wrong for the other side? If you can't name it, you probably don't need CQRS.

---

## Saga

**Intent:** Coordinate a multi-step workflow that spans multiple services or transactions, with explicit compensation (rollback) logic for partial failures.

**Use when:**
- A business process spans multiple services, each with their own transaction boundary
- Partial completion must be undone via compensating transactions (not DB rollback)
- Long-running workflows where holding a DB transaction open is infeasible
- You need explicit visibility into workflow state and step progress

**Two variants:**
- **Choreography:** Each service listens for events and reacts. Simple to start, hard to reason about as complexity grows.
- **Orchestration:** A central saga orchestrator tells each service what to do. Easier to trace and test; single point of coupling.

**Skip when:**
- The workflow is within one service and one transaction boundary — use a DB transaction instead
- Failure is rare and manual intervention is acceptable
- The "multi-step" logic is really just two sequential API calls with no compensation need

**Cost:**
- Compensating transactions must be idempotent and explicitly designed
- Distributed tracing / observability becomes essential
- Complexity is high — choreography sagas especially become hard to follow

**Self-critique:** Can a single DB transaction handle this? If yes, use it. Sagas are for when you genuinely can't.

---

## Domain Events

**Intent:** When something meaningful happens in the domain, publish a named event. Other parts of the system react to the event rather than being called directly.

**Use when:**
- A domain action should trigger side effects in other bounded contexts or modules
- You want to decouple the action from its consequences (the action shouldn't know about email sending, audit logging, etc.)
- Multiple consumers need to react to the same fact
- You want an audit trail of what happened in the domain

**Skip when:**
- The consequence is a core part of the action's contract (not a side effect)
- There's only one consumer and it's in the same module — a direct call is clearer
- The team doesn't have the infrastructure to handle async events reliably

**Sync vs. async:**
- **Sync (in-process events):** Simple, transactional, no infrastructure needed. Subscribers run in the same transaction. Good starting point.
- **Async (message broker):** Decoupled, resilient, but eventual consistency. Use when consumers are in separate services or you need at-least-once delivery.

**Self-critique:** Is this a side effect (domain events fit) or a core postcondition (direct call fits)? Calling `sendWelcomeEmail()` directly when creating a user is fine — it doesn't need an event unless you have multiple consumers or want to decouple the dependency direction.

---

## Event Sourcing

**Intent:** Store the sequence of events that caused the current state rather than storing the current state itself. State is derived by replaying events.

**Use when:**
- Full audit trail of every state change is a business requirement
- You need to replay history or query "what was the state at time T?"
- Temporal queries and retroactive corrections are needed
- CQRS projections are being built — event sourcing pairs naturally

**Skip when:**
- Current state is all you need — standard CRUD with an `updated_at` column is far simpler
- The domain doesn't have meaningful events, just CRUD operations
- The team lacks experience with event stores and projection rebuilds
- You want audit logs — a separate audit table is much simpler

**Cost:**
- Snapshot management for long event streams
- Projection rebuild time and complexity
- Schema evolution of past events is hard
- Debugging requires understanding event replay
- Operational complexity is high

**Self-critique:** This is one of the most over-applied architectural patterns. Ask: would a `history` table or `updated_at` audit column satisfy the requirement? If yes, use that.

---

## Specification

**Intent:** Encapsulate a business rule as an object that can be combined, reused, and tested independently.

**Use when:**
- The same selection/filtering logic appears in multiple places (query, validation, domain logic)
- Business rules are combinable (`AND`, `OR`, `NOT`) and the combinations vary
- Rules need to be independently unit-tested without a database
- Domain language should be expressed in rule names (`ActiveCustomerSpec`, `EligibleForDiscountSpec`)

**Skip when:**
- Rules are used in one place only and won't be combined — a private method is simpler
- The rules are database-query-specific and don't appear in domain logic — a query builder or raw filter is fine
- The pattern adds indirection without reuse — one Specification for one query is noise

**Self-critique:** Is this rule reused or combined? If not, extract a well-named method instead.

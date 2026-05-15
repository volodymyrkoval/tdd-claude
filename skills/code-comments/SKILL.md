---
name: code-comments
description: Decides when and how to write code comments — JSDoc/docstrings on exported symbols, module/file-level headers, and inline comments. Apply when writing or modifying functions/classes/modules; when about to add a comment; when touching code with redundant restatements, commented-out code, or stale TODOs nearby (opportunistic cleanup, change-radius only). Language-agnostic principles with concrete syntax for JS/TS, Python, and Go — extends to Rust, Java, C#, Ruby. Reviewer applies it to flag comment-quality violations during code review. Does NOT cover README/feature-doc/CLAUDE.md updates (use docs-writer), commit messages, or changelog entries.
---

# Code Comments — When and How

## Principle

Comments earn their place by carrying context the code cannot. Types, names, and structure carry the *what*. Comments carry the *why*, the invariants, and the domain semantics no signature can encode. Comments that restate the next line are noise — they cost tokens, drift over time, and dilute the signal of the comments that matter.

**First move when tempted to comment:** can a better name or an extracted function carry the meaning instead? If yes, do that. Comments are the fallback when structure has done all it can.

---

## 1. JSDoc / docstrings on exported symbols

**Add when:** the symbol is exported, public on a class, or imported by name elsewhere.
**Skip when:** the function is internal and its name + types fully describe it, or the signature is trivially self-evident (`isEmpty(x): boolean`).

**Include, in priority order:**

1. **Purpose.** One sentence on what it is *for*, not what it mechanically does. "Resolves the effective billing tier from subscription, overrides, and feature flags" beats "Returns the billing tier."
2. **Invariants / preconditions.** What the caller must guarantee. "Assumes `userId` has been validated against the session."
3. **Domain semantics types can't capture.** Units, ranges, nullability rules. "`amount` is in minor units (cents)."
4. **Non-obvious side effects or failure modes.** "Logs to Sentry on retry exhaustion; does not throw."
5. **Cross-cutting constraints.** Latency budgets, ordering guarantees, callers that matter.

**Never:** redundantly document types the signature already shows. `@param {string} userId - The user ID` is pure noise.

---

## 2. Module / file-level header

**Add when:**

- The file is a non-obvious architectural boundary (e.g. transport ↔ domain seam).
- It encodes a contract that lives nowhere else (event shapes, protocol assumptions).
- Its purpose isn't obvious from the filename alone.

**Skip on:** utility leaves whose name tells the story, test files, generated code.

**Keep to a short paragraph covering:**

- What this module *is* (one sentence).
- Where it sits — what depends on it, what it depends on — only if non-obvious.
- Any file-wide invariants. "All exports are pure; no I/O."

---

## 3. Inline comments

**Add only when one of these holds:**

- The code does something that would surprise a careful reader, and the surprise has a reason. `// Re-sort here because RabbitMQ doesn't guarantee order on requeue`
- The shape of the code is load-bearing in a way someone might "simplify" away. `// Do not collapse into Promise.all — the rate limiter needs serial execution`
- A magic literal carries domain meaning. `// 86400 = one day in seconds`
- A workaround exists for an external bug or vendor limit; link the issue when possible. `// Workaround for nodejs/node#1234 — drop on Node 22+`
- The block maps to a named domain rule. `// VAT exemption applies only to B2B intra-EU; see invoice policy §3.2`

**Never add inline comments to:**

- Restate the line below.
- Justify a variable name — fix the name instead.
- Explain standard language features.
- Leave TODOs without an owner and a date.

---

## 4. Style

- Present tense, declarative. "Computes the rebate," not "Will compute the rebate."
- Name the constraint, not the feeling. "Avoids a 30s timeout in the upstream gateway" beats "for performance reasons."
- Reference external issues/RFCs by stable identifier when the comment depends on them.
- A good docblock lets a caller skip reading the body. Aim for that.

---

## 5. Anti-patterns — never produce

- Commented-out code "for later."
- Box/banner ASCII decoration.
- "Updated by X on Y" headers — version control already knows.
- Apologetic comments (`// This is ugly but…`) — either fix the code, or name the constraint that forces the shape.
- Redundant type echoes in JSDoc/docstrings (`@param {string} userId - The user ID`).
- TODOs without an owner and a date.

---

## 6. Opportunistic cleanup of existing comments

When editing a function, also fix obviously bad comments that fall **inside the change radius** — same function, or the block of lines you're already touching. Leave the rest of the file alone unless the user asked for a sweep.

**Clean up when nearby:**
- Redundant restatements (`// increment counter` above `counter++`)
- Commented-out code with no `TODO`/`FIXME` rationale
- TODOs without an owner or date
- Header comments contradicted by the new behavior (a JSDoc claiming the function returns `null` after you changed it to throw)

**Do not clean up:**
- Comments outside the function/block you're editing
- Comments in unrelated files in the same diff
- Comments you don't understand — flag in the review/PR description instead of deleting

This mirrors the Boy Scout Rule from `design-rubric` §3 — clean what you're already in, never expand the diff to chase comment debt.

---

## 7. Language syntax

The principles above are language-agnostic. The syntax differs.

### TypeScript / JavaScript — JSDoc

```ts
/**
 * Resolves the effective billing tier from subscription, overrides, and feature flags.
 *
 * Assumes `userId` has been validated against the session.
 * Logs to Sentry on retry exhaustion; does not throw.
 *
 * @returns Tier identifier; `null` only when the user is mid-migration.
 */
export function resolveBillingTier(userId: UserId): Tier | null { ... }
```

- In **TypeScript**, skip `@param`/`@returns` *types* — the signature carries them. Use `@param`/`@returns` *prose* only when adding semantics the type can't.
- In **plain JS**, type tags (`@param {string}`) are useful documentation; keep the prose anyway.
- Place JSDoc directly above the symbol, no blank line between.

### Python — docstrings

```python
def resolve_billing_tier(user_id: UserId) -> Tier | None:
    """Resolve the effective billing tier from subscription, overrides, and feature flags.

    Assumes ``user_id`` has been validated against the session.
    Logs to Sentry on retry exhaustion; does not raise.

    Returns:
        Tier identifier, or None only when the user is mid-migration.
    """
```

- Pick one style per project (Google, NumPy, or reST) and stay consistent.
- Don't list `Args:` if every entry would just echo the type and name. Include only the params that need semantics.
- A module docstring at the top of the file (before any imports) replaces the file-header comment.

### Go — godoc

```go
// ResolveBillingTier returns the effective billing tier from subscription,
// overrides, and feature flags.
//
// It assumes userID has been validated against the session, logs to Sentry on
// retry exhaustion, and does not return an error in that case.
//
// The returned tier is empty only when the user is mid-migration.
func ResolveBillingTier(userID UserID) Tier { ... }
```

- Sentence starts with the symbol name — godoc convention.
- Package-level doc: a `// Package foo …` comment on the file containing `package foo` (or a dedicated `doc.go`).
- No `@`-tag styles — Go has no JSDoc/docstring section convention.

### Other languages

Apply the same priorities (Purpose → Invariants → Semantics → Side effects → Constraints) using the language's idiomatic doc form: Rust `///` and `//!`, Java/C# Javadoc and XML doc, Ruby YARD, Swift markup. Skip type echoes when the signature carries the type.

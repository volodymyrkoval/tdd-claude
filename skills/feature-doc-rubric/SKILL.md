---
name: feature-doc-rubric
description: Apply when generating or auditing a feature live-spec — the short, human-readable doc written right after `/done`. Drives a five-section discipline: source of truth, length & tone, required sections, drift sweep across existing docs, and behavior-change verification. Reusable by both feature-documenter (writer) and any future feature-doc-auditor.
---

# Feature Doc Rubric

A forcing function. Tick every checkbox before declaring the spec complete.

The doc you produce is a **live spec** — descriptive, short, and permanently useful as project memory and AI context. It is *not* a changelog. A changelog answers "what commits landed?"; a live spec answers "what does this feature do, and why does it work this way?"

If a conflict arises between rules, the **§2 length budget** wins — every section is gated by the 100-line ceiling, so trim before you reach for an extra subsection.

---

## 1. Source of truth

- [ ] Read the **squashed commit** at the latest `dev/done-NNN` (or HEAD if `/done` just ran). This is the only diff that ships.
- [ ] Read the **archived plan** at `docs/archive/<slug>.md`. This is the only authority on goal, scope, and design rationale.
- [ ] Do NOT pull from working-tree changes, unsquashed commits, or unrelated history.
- [ ] Do NOT invent rationale. If the plan does not state *why*, omit the bullet — never reverse-engineer reasons from the diff.
- [ ] If the squashed commit and the archived plan disagree on a fact, flag the disagreement; do not pick a side silently.

## 2. Length & tone

- [ ] Total length **< 100 lines** including blanks and headers. Length is the budget — extracting only durable signal is the discipline.
- [ ] Descriptive prose, not implementation walkthrough. A reader who has never seen the code should understand *what changed and why*.
- [ ] No code blocks longer than 5 lines. A code reference belongs in the source, not the spec.
- [ ] No `file:line` citations. They drift; refer to features, agents, commands, or surfaces by name.
- [ ] Plain language. Prefer the normal word over the jargon word when both fit.
- [ ] No emojis unless the user's project style already uses them.

## 3. Required sections

The spec has exactly these top-level sections, in this order. Adding new top-level sections is a fail. Skipping an applicable section is a fail.

- [ ] `# <Feature Name>` — title only, plain words, not the slug.
- [ ] **Status line** — one block-quoted line: iteration tag (`dev/done-NNN`), date, and a one-sentence summary.
- [ ] `## What it does` — 2–3 paragraphs in plain language. What user-visible behavior is added or changed. Lead with the user, not the implementation.
- [ ] `## Design decisions` — bulleted list. Each bullet: what was chosen, what was rejected, *why*. If the plan records no rationale for a decision, omit that bullet rather than fabricate.
- [ ] `## Scope` — `**In:**` / `**Out:**` split. Every `**Out:**` bullet must state *why* deferred (premature, separate concern, awaiting second use case, etc.).
- [ ] `## Relationship to existing system` — what this builds on, replaces, mirrors, or interacts with. Name features, agents, commands, or doc surfaces by name.
- [ ] `## Behavior changes` — **only if existing behavior was modified**. Each bullet: prior behavior → new behavior → why. Omit the section entirely when the feature is purely additive.

## 4. Drift sweep across existing docs

This is the section the rubric exists to enforce. A live spec that ignores docs the change has invalidated is worse than no spec at all.

- [ ] Decide whether this feature changed existing behavior. Anything that contradicts a claim already documented somewhere counts as a behavior change.
- [ ] If purely additive: state "no drift" explicitly in the drift report and skip the rest of this section. That is a valid result.
- [ ] If behavior changed: enumerate every doc surface that could plausibly be affected:
  - `CLAUDE.md` (all of it — routing tables, agent lists, skill lists, hook descriptions, command tables)
  - `README.md`
  - Every existing file under `docs/features/**`
  - Every other top-level `*.md` in the repo (`TDD.md`, `QUALITY_TOOLING.md`, `CHANGELOG.md` if user-maintained, etc.)
- [ ] For each candidate doc, read it and grep for claims the new commit contradicts. Be exhaustive — partial sweeps create false confidence.
- [ ] Update *only* the claims that drifted. Doc churn for its own sake is noise.
- [ ] Update drifted docs **in the same commit** as the new spec — drift left unfixed defeats the purpose of the live spec.
- [ ] If a doc is silent on the affected area but *should* mention it, list it as 🆕 in the drift report and ask the orchestrator before silently inserting content.

## 5. Verification (before commit)

- [ ] Every claim in the spec traces to the squashed diff or the archived plan. No speculation.
- [ ] Every `**Out:**` bullet has a stated reason.
- [ ] If a `## Behavior changes` section exists, every bullet names the prior behavior, the new behavior, and why.
- [ ] Drift sweep ran. Result is either "no drift" or a list of updated docs — never absent.
- [ ] Spec reads cold: a reader six months from now, with no other context, can answer "what is this?" and "why does it work this way?"
- [ ] Total length still **< 100 lines** after the final pass.
- [ ] Staged files: only the new spec and any drifted docs. Never `git add -A`.

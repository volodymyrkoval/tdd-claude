---
description: Scaffold a new project (greenfield) OR retrofit an existing project with missing quality tooling (--retrofit).
argument-hint: <stack> (e.g. "python cli", "nextjs typescript") | --retrofit
model: haiku
---

# Bootstrap Project: $ARGUMENTS

Proactively use the **bootstrapper** agent.

## Mode selection

- If `$ARGUMENTS` contains `--retrofit` → **retrofit mode** (add missing quality tooling to an existing project).
- Otherwise → **greenfield mode** (scaffold a new project from the stack description in `$ARGUMENTS`).

## Context

- Current directory: !`pwd`
- Existing files: !`ls -la`
- Git status: !`git status 2>/dev/null || echo "Not a git repository"`

## Task — greenfield (no `--retrofit`)

### Step 1: Parse Stack

Interpret `$ARGUMENTS` as free-form stack description. Extract:
- **Project kind** (CLI, web app, API, library, etc.)
- **Language** (python, typescript, go, rust, …)
- **Framework** (next.js, fastapi, express, …)
- **Notable extras** (db, auth, tailwind, …)

If `$ARGUMENTS` is empty or ambiguous, ask one concise clarifying question before scaffolding.

### Step 2: Context7 Lookups (mandatory before any file is written)

For every framework, test runner, linter, and quality tool identified in Step 1, resolve and fetch current docs via Context7:

```
resolve-library-id("<framework or tool name>") → query-docs(id)
```

Use the returned docs for all install commands, config schemas, and plugin names. Do **not** rely on training-data recall — library APIs and default configs change between versions.

### Step 3: Scaffold

1. **Project structure**
    - `.claude/` with CLAUDE.md
    - `docs/plans/`, `docs/archive/`, `docs/decisions/`
    - `src/` and `tests/` (adapt to language conventions)

2. **Tooling** (pick idiomatic defaults for the parsed stack)
    - Package manager (uv/poetry/pnpm/cargo/…)
    - Test runner (pytest/vitest/jest/go test/…)
    - Linter/formatter (ruff/eslint+prettier/biome/golangci-lint/…)

3. **Configuration files**
    - Stack-appropriate config
    - `.gitignore`
    - Minimal `README.md` noting the chosen stack

### Step 4: Verify

- Tests can run (placeholder test is fine)
- Linter passes

### Step 5: Initial Commit

```
chore: initial project setup (<stack summary>)
```

## Task — retrofit (`--retrofit`)

Dispatch the **bootstrapper** agent in retrofit mode. Pass `--retrofit` verbatim. The agent:

1. Detects the existing stack (npm / pnpm / yarn / bun / pip / uv / poetry; Jest / Vitest / Mocha / pytest).
2. Inventories what's already installed per `QUALITY_TOOLING.md`.
3. Installs only **missing** mutation-testing + architecture-fitness packages.
4. Generates only **missing** config files — never overwrites `stryker.config.*`, `.dependency-cruiser.*`, or existing `[tool.mutmut]` / `[importlinter]` sections.
5. Adds missing scripts (`test:mutate`, `arch:check`) without touching existing ones.
6. Writes `.claude/test-cmd` if missing (derived from the project's existing test command).
7. Verifies each installed tool runs (`--version`).
8. **Reports changes and stops. No `git init`, no initial commit, no edits to source or tests.** The user reviews with `git diff` / `git status` and commits manually.

If neither `package.json` nor `pyproject.toml` exists, the agent stops and suggests running `/bootstrap` without `--retrofit`.

## Rules

- Use idiomatic defaults — don't invent exotic combos
- Keep setup minimal: only what's needed to start TDD
- **Greenfield:** if the current directory is non-empty or has an existing lockfile, stop and confirm — the user probably wants `--retrofit`.
- **Retrofit:** never overwrite existing configs; never modify existing package versions; never commit.

## Output

**Greenfield:**
```
✓ Bootstrapped: <stack summary>
  Package manager: <x>
  Test runner: <y>
  Linter: <z>
Next: /feature <name>
```

**Retrofit:**
```
✓ Retrofit complete: <project path>
  Stack: <detected>
  Added: <packages, configs, scripts, .claude/test-cmd>
  Skipped (already present): <items>
Next: `git diff` to review, then commit when satisfied.
```

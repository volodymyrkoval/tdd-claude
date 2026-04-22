# Quality Tooling Reference

Packages installed into every new TS/JS or Python project so mutation testing and architecture fitness work out of the box.

**Consumed by:**
- `agents/bootstrapper.md` — installs these during `/bootstrap`
- `commands/mutate.md` — runs mutation testing
- `agents/design-critic.md` (architecture mode) — runs fitness tools
- `hooks/pre-commit-green.sh` — reads test command from `.claude/test-cmd`

---

## TypeScript / JavaScript

### Mutation testing — Stryker

Dev dependencies:
- `@stryker-mutator/core`
- Runner (pick one, matching the project's test runner):
  - `@stryker-mutator/jest-runner`
  - `@stryker-mutator/vitest-runner`
  - `@stryker-mutator/mocha-runner`
- `@stryker-mutator/typescript-checker` (TS projects only)

Config file: `stryker.config.mjs` at repo root.

```js
export default {
  mutate: ["src/**/*.{ts,tsx,js,jsx}", "!src/**/*.{test,spec}.{ts,tsx,js,jsx}"],
  testRunner: "jest",            // or "vitest" / "mocha"
  checkers: ["typescript"],      // omit for pure JS
  tsconfigFile: "tsconfig.json", // omit for pure JS
  incremental: true,
  coverageAnalysis: "perTest",
  thresholds: { high: 80, low: 60, break: 50 },
  reporters: ["clear-text", "html", "json"],
};
```

npm script: `"test:mutate": "stryker run --incremental"`

### Architecture fitness — dependency-cruiser

Dev dependency: `dependency-cruiser`

Config: `.dependency-cruiser.cjs` at repo root. Start from `npx depcruise --init` and add the project's layer rules (e.g. `no-domain-to-infra`, `no-circular`, `no-orphans`).

npm script: `"arch:check": "depcruise src --config .dependency-cruiser.cjs --progress"`

---

## Python 3.x

### Mutation testing — mutmut

Dev dependency: `mutmut`

Config in `pyproject.toml`:

```toml
[tool.mutmut]
paths_to_mutate = "src/"
runner = "pytest -x -q"
tests_dir = "tests/"
```

Commands: `mutmut run` then `mutmut results`

Alternative for larger codebases: `cosmic-ray` (slower, more thorough).

### Architecture fitness — import-linter

Dev dependency: `import-linter`

Config in `pyproject.toml` (or `.importlinter`):

```ini
[importlinter]
root_package = my_package

[importlinter:contract:layered]
name = Layered architecture
type = layers
layers =
    my_package.api
    my_package.service
    my_package.domain
    my_package.infra
```

Command: `lint-imports`

Makefile or `uv run` target: `arch: lint-imports`

---

## Bootstrapper checklist

When scaffolding a new project, the bootstrapper MUST:

1. Detect the stack (`package.json` vs `pyproject.toml`).
2. Install mutation-testing dev deps from the matching section above.
3. Install architecture-fitness dev deps from the matching section above.
4. Generate a minimal config for each tool (commit the config files).
5. Add scripts:
   - TS/JS: `test:mutate`, `arch:check` in `package.json`
   - Python: `mutate`, `arch` as Makefile targets or `uv run` tasks
6. Write the primary test command to `.claude/test-cmd` (single line) — this enables the `pre-commit-green.sh` hook.
7. Mention both commands in the README under a "Quality gates" section.

---

## Why these tools

- **Stryker / mutmut** — measure *whether tests catch bugs*. Coverage tells you a line executed; mutation testing tells you it was *tested*.
- **dependency-cruiser / import-linter** — enforce layered architecture deterministically. Catches circular deps and forbidden imports before they become load-bearing.

Both are consumed by `/mutate` and `/design-audit architecture`.

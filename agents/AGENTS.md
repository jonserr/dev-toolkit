# AGENTS.md

<!-- Repository instructions for coding agents (Codex, Claude Code, Copilot, Cursor, Gemini CLI) -->
<!-- Replace every [placeholder] and delete sections that do not apply -->

## Project overview

[project-name] is a [one-sentence description]. The primary language is [Python 3.11 | Bash | TypeScript].

## Repository layout

| Path | Contents |
| --- | --- |
| `src/[package]/` | Application source code |
| `tests/` | Unit and integration tests |
| `scripts/` | Operational and utility scripts |
| `docs/` | Architecture, runbooks, and ADRs |
| `specs/` | SDD specifications, plans, and task lists |

## Commands

Run these commands from the repository root.

| Task | Command |
| --- | --- |
| Set up environment | `make setup` |
| Lint and format check | `make lint` |
| Apply formatting | `make format` |
| Run tests | `make test` |
| Run all checks | `make check` |

Run `make check` before you report a task as complete.

## Conventions

- Use type hints for all public Python functions.
- Use `logging` instead of `print` for diagnostic output.
- Use the log format `TIMESTAMP | LEVEL | COMPONENT | MESSAGE`.
- Start Bash scripts with `set -Eeuo pipefail`.
- Keep functions small. Prefer pure functions for business logic.
- Write tests for new behavior and for every bug fix.
- Keep commits small and focused on one change.

## Spec-Driven Development

1. Read `specs/[NNN-feature]/spec.md` before you change code for a feature.
2. Follow `plan.md` for design decisions.
3. Complete tasks in `tasks.md` in order. Mark each task when it is done.
4. Stop and ask when the spec and the code disagree.

## Boundaries

Always:

- Run the linters and tests that apply to the changed files.
- Keep changes inside the scope of the task.

Ask first:

- Add, remove, or upgrade a dependency.
- Change the database schema, the public API, or the CI configuration.
- Delete files or change files outside the task scope.

Never:

- Commit secrets, tokens, or `.env` files.
- Run `git push`, `git reset --hard`, or force operations without approval.
- Disable tests or linters to make a check pass.
- Make live calls to paid or production services in tests.

## Verification

A task is complete only when:

1. `make check` passes.
2. New behavior has tests.
3. The change satisfies the acceptance criteria in the spec.

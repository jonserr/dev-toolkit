# Tasks: [feature name]

Plan: `specs/[NNN-feature]/plan.md`

## Rules

- Complete the tasks in order unless a task is marked `[P]` (parallel).
- Each task changes a small set of files and takes less than one hour.
- Mark a task done only when its verification command passes.

## Setup

- [ ] **T001** [Create module skeleton]
  - Files: `src/[package]/[module].py`
  - Verify: `uv run python -c "import [package].[module]"`

## Tests first

- [ ] **T002** [P] [Write failing tests for FR-1]
  - Files: `tests/test_[module].py`
  - Verify: `uv run pytest tests/test_[module].py` fails with the expected assertion

## Implementation

- [ ] **T003** [Implement FR-1]
  - Files: `src/[package]/[module].py`
  - Verify: `uv run pytest tests/test_[module].py`

## Integration

- [ ] **T004** [Connect the module to the CLI or API]
  - Verify: `[command that exercises the feature end to end]`

## Finish

- [ ] **T005** Update documentation and `CHANGELOG.md`
- [ ] **T006** Run `make check`
- [ ] **T007** Check each acceptance criterion in `spec.md`

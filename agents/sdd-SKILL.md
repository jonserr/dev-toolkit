---
name: sdd-feature
description: Use when starting a new feature or significant change. Creates a spec, a plan, and a task list in specs/NNN-feature-name/ before any code changes.
---

# SDD feature workflow

Use this skill to move a feature from an idea to verified code in four phases. Do not skip a phase.

## Phase 1: Specify

1. Find the next free number in `specs/`. Create `specs/[NNN]-[short-name]/`.
2. Copy `specs/_templates/spec.md` into the new folder.
3. Fill in the problem, the users, the requirements, and the acceptance criteria.
4. Mark each unknown as `[NEEDS CLARIFICATION: question]`.
5. Ask the user to resolve every clarification. Stop until they answer.

## Phase 2: Plan

1. Copy `specs/_templates/plan.md` into the feature folder.
2. Read the code that the feature touches.
3. Write the design, the affected components, and the risks.
4. Record each significant decision as an ADR. Copy `docs/adr/0000-template.md` to `docs/adr/[NNNN]-[title].md`.
5. Ask the user to approve the plan.

## Phase 3: Tasks

1. Copy `specs/_templates/tasks.md` into the feature folder.
2. Split the plan into tasks that each take less than one hour.
3. Give each task a verification command.

## Phase 4: Implement and verify

1. Complete one task at a time.
2. Write the test first when the behavior is testable.
3. Run the verification command. Mark the task done only when it passes.
4. Run `make check` after the last task.
5. Compare the result with each acceptance criterion in `spec.md`.

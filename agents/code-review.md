# Code review instructions

Use this procedure to review a diff, a branch, or a pull request. Report findings only. Do not change files unless the requester asks for fixes.

## Procedure

1. Read the linked spec, issue, or PR description. Identify the intended behavior.
2. Read the full diff. Read the surrounding code for every changed function.
3. Check each category below.
4. Verify each finding against the code before you report it.
5. Report findings in order of severity.

## Categories

### Correctness

- The change implements the intended behavior.
- Edge cases are handled: empty input, `None`, zero, large values, Unicode, time zones.
- Error paths return or raise the correct result.
- Concurrency and retries do not cause duplicate side effects.

### Security

- Input from users, files, and networks is validated.
- No SQL, shell, or path injection.
- No secrets in code, logs, or test fixtures.
- Permissions and authentication checks are present where required.

### Reliability

- Errors are not silently swallowed.
- External calls have timeouts.
- Resources (files, connections, locks) are released.
- Logs contain enough context to diagnose failures.

### Maintainability

- Names describe intent.
- No duplicated logic that an existing helper already provides.
- Comments explain why, not what.
- The change follows the conventions in `AGENTS.md`.

### Tests

- New behavior has tests.
- Tests check behavior, not implementation details.
- Tests do not depend on network, wall-clock time, or execution order.

## Output format

For each finding, report:

| Field | Content |
| --- | --- |
| Severity | `critical`, `major`, `minor`, or `nit` |
| Location | `path/to/file.py:42` |
| Problem | One sentence that states the defect |
| Scenario | Concrete input or state that causes the failure |
| Fix | Short suggested change |

End with a one-line verdict: `approve`, `approve with nits`, or `request changes`.

# dev-toolkit

Personal, copyable templates for new projects in Python, Java, Node, Bash, Docker Compose, and SLURM. Each file is self-contained.

## Layout

```text
dev-toolkit/
├── toolkit.mk     bootstrap: make -f toolkit.mk backend, init-private, init-public
├── agents/        AI agents and Spec-Driven Development
│   ├── AGENTS.md                  instructions for all coding agents
│   ├── CLAUDE.md                  Claude Code entry point, imports AGENTS.md
│   ├── claude-settings.json       Claude Code permissions (.claude/settings.json)
│   ├── .mcp.json                  MCP servers: Context7 docs, GitHub
│   ├── code-review.md             agent review procedure and output format
│   ├── sdd-SKILL.md               skill that runs spec → plan → tasks → implement
│   ├── spec-template.md           requirements and acceptance criteria
│   ├── plan-template.md           design, risks, test strategy
│   ├── tasks-template.md          ordered tasks with verification commands
│   └── adr-template.md            architecture decision record
│
├── .gitignore     Python, Java, Node, secrets, editors, containers, HPC (also copied to projects)
│
├── tooling/       configuration, logging, and scripts
│   ├── Makefile                   setup, lint, test, build, run for uv/Maven/Gradle/npm
│   ├── pyproject.toml             Python metadata, Ruff, pytest, mypy
│   ├── requirements.txt           general pinned Python packages
│   ├── .pre-commit-config.yaml    Ruff, ShellCheck, shfmt, gitleaks hooks
│   ├── .editorconfig              indentation and line endings
│   ├── .env.example               documented environment variables
│   ├── .shellcheckrc              ShellCheck settings
│   ├── .prettierrc.json           Prettier settings for JS/TS
│   ├── logging.sh                 Bash logging, error traps, cleanup, helpers
│   ├── logging.py                 Python text/JSON logging and step timing
│   ├── logback.xml                Java logging (SLF4J + Logback)
│   ├── setup-uv.sh                installs uv and Python, syncs dependencies
│   ├── setup-gh.sh                git init, add templates, optional GitHub repo
│   ├── benchmark.sh               wall time and peak memory of a command
│   └── new-project.sh             copies template profiles into a project
│
├── pipelines/     GitHub Actions CI/CD
│   ├── python-ci.yml              Ruff and pytest on Python 3.11 to 3.13
│   ├── java-ci.yml                Maven or Gradle build on Java 17 and 21
│   ├── node-ci.yml                npm lint, Prettier, test, build on Node 20 and 22
│   ├── shellcheck.yml             ShellCheck and shfmt
│   ├── security.yml               gitleaks, dependency review, pip-audit
│   ├── actions-lint.yml           actionlint for workflow files
│   ├── docker-build.yml           image build, smoke test, Trivy scan
│   └── dependabot.yml             weekly updates for actions, uv, npm, Docker
│
├── containers/    containers and HPC jobs
│   ├── Dockerfile                 multi-stage uv image, non-root user
│   ├── .dockerignore
│   ├── compose.yaml               app, PostgreSQL, Redis with health checks
│   ├── devcontainer.json          VS Code dev container with extensions
│   ├── apptainer.def              Apptainer/Singularity image for HPC
│   ├── slurm-job.sbatch           single job with optional modules and container
│   ├── slurm-array.sbatch         job array, one task per input line
│   └── slurm-report.sh            state, memory, CPU efficiency, failure hints
│
└── docs/          project documentation templates
    ├── README-template.md
    ├── RUNBOOK-template.md        access, deploy, rollback, troubleshooting
    └── CHANGELOG-template.md
```

## Start a project

`tooling/new-project.sh` copies template profiles into a project folder. It never overwrites existing files. Add `-n` to preview the copies.

| Command | Action |
| --- | --- |
| `~/dev-toolkit/tooling/new-project.sh ~/code/my-app base agents python docs` | Copy Python project templates |
| `~/dev-toolkit/tooling/new-project.sh -n ~/code/my-java-app base agents java containers` | Preview Java project copies |

| Profile | Files copied |
| --- | --- |
| `base` | `.editorconfig`, `.gitignore`, `.env.example`, `Makefile`, security CI, Actions lint, Dependabot |
| `agents` | `AGENTS.md`, `CLAUDE.md`, `.claude/`, `.mcp.json`, `specs/_templates/`, `docs/adr/` |
| `python` | `pyproject.toml`, `requirements.txt`, pre-commit, `scripts/setup-uv.sh`, `src/log_config.py`, Python CI |
| `java` | `src/main/resources/logback.xml`, Java CI |
| `node` | `.prettierrc.json`, Node CI |
| `bash` | `.shellcheckrc`, `scripts/logging.sh`, `scripts/benchmark.sh`, ShellCheck CI |
| `containers` | `Dockerfile`, `.dockerignore`, `compose.yaml`, `.devcontainer/`, Docker build CI |
| `slurm` | `slurm/job.sbatch`, `slurm/array.sbatch`, `slurm/report.sh`, `apptainer.def` |
| `docs` | `README.md`, `CHANGELOG.md`, `docs/RUNBOOK.md` |
| `all` | All profiles |

## Quick start

Copy templates into any project folder with two commands. Existing files are never overwritten.

1. Download the bootstrap file:

```bash
curl -fsSLO https://raw.githubusercontent.com/jonserr/dev-toolkit/main/toolkit.mk
```

2. Copy the templates for your project type:

```bash
make -f toolkit.mk backend
```

| Stack | Copies |
| --- | --- |
| `backend` | Python API tooling, Docker, docs |
| `frontend` | Node/TypeScript tooling, Docker, docs |
| `fullstack` | backend + frontend |
| `hpc` | Python, Bash, SLURM, docs |

| Single tool | Copies |
| --- | --- |
| `base` | `.editorconfig`, `.gitignore`, `.env.example`, `Makefile`, CI security, agents, SDD templates |
| `python` | `pyproject.toml`, `requirements.txt`, uv setup, logging, Ruff, Python CI |
| `java` | `logback.xml`, Java CI |
| `node` | `.prettierrc.json`, Node CI |
| `bash` | `logging.sh`, `benchmark.sh`, ShellCheck CI |
| `docker` | `Dockerfile`, `compose.yaml`, devcontainer, Docker CI |
| `slurm` | SLURM job templates, Apptainer |
| `docs` | `README.md`, `CHANGELOG.md`, `docs/RUNBOOK.md` |
| `all` | everything |

Every target includes `base`. Combine targets in one command, for example `make -f toolkit.mk java docker`. Run `make -f toolkit.mk` to list the targets. Delete `toolkit.mk` when you are done.

3. Optional: also create the GitHub repository. These targets run `git init`, copy the templates, commit, create the repository with `gh`, and push:

```bash
make -f toolkit.mk init-private my-repo
```

| Target | Action |
| --- | --- |
| `init-private [name]` | Create a private repository, named after the current folder when you omit the name |
| `init-public [name]` | Create a public repository, named after the current folder when you omit the name |

Add a stack to include its files, for example `make -f toolkit.mk backend init-public my-api`. These targets need the [GitHub CLI](https://cli.github.com/), `gh auth login`, and a git `user.email`. `toolkit.mk` itself is never committed.

## New GitHub repository

`setup-gh.sh` also runs `git init`, and it can create the GitHub repository. By default, it only changes local files. The `--commit`, `--create`, and `--push` options opt in to a commit, a new GitHub repository, and a push. `--create` and `--push` need the [GitHub CLI](https://cli.github.com/) and `gh auth login`. Add `--public` for a public repository.

1. Clone the toolkit once:

```bash
git clone https://github.com/jonserr/dev-toolkit.git ~/dev-toolkit
```

2. In the new project folder, run git init and add templates:

```bash
~/dev-toolkit/tooling/setup-gh.sh python docs
```

3. Or also commit, create a private GitHub repository, and push:

```bash
~/dev-toolkit/tooling/setup-gh.sh --commit --create --push python docs
```

## Python setup with uv

`setup-uv.sh` installs uv (with Homebrew or the official installer) when it is missing. Then it installs Python and the dependencies. It uses `pyproject.toml` when the file exists, and `requirements.txt` otherwise.

| Command | Action |
| --- | --- |
| `scripts/setup-uv.sh` | Set up with Python 3.12 |
| `scripts/setup-uv.sh -p 3.11` | Set up with a specific Python version |
| `scripts/setup-uv.sh --to-pyproject` | Move `requirements.txt` packages into `pyproject.toml` |

`requirements.txt` has pinned, general-purpose packages: dotenv, Pydantic, PyYAML, httpx, tenacity, Typer, Rich, and the development tools. Delete the lines that a project does not need.

## Makefile

The Makefile detects the toolchain from the project files: `pyproject.toml` (uv), `pom.xml` (Maven), `build.gradle` (Gradle), or `package.json` (npm). The same commands work in every project.

| Group | Targets |
| --- | --- |
| General | `help`, `info`, `doctor`, `version` |
| Development | `setup`, `run`, `shell` |
| Quality | `lint`, `format`, `typecheck`, `test`, `coverage`, `check`, `hooks`, `todo` |
| Dependencies | `update`, `outdated`, `audit` |
| Build | `build`, `clean`, `distclean` |
| Containers | `docker-build`, `docker-run`, `docker-shell`, `up`, `down`, `restart`, `rebuild`, `logs`, `ps` |

| Command | Action |
| --- | --- |
| `make` | List targets by group |
| `make doctor` | Check required tools |
| `make setup` | Install dependencies, create `.env` |
| `make check` | Lint and test |
| `make distclean` | Remove caches, `.venv`, and `node_modules` |

Override a command for one run: `make test TEST_CMD="uv run pytest -x"`. A target with no command for the detected stack fails with a hint and does not pass silently.

## Spec-Driven Development

1. Copy `specs/_templates/spec.md` to `specs/<NNN-feature>/spec.md`. Describe the problem and the acceptance criteria.
2. Resolve every `[NEEDS CLARIFICATION]` marker.
3. Write `plan.md`. Record significant decisions as ADRs in `docs/adr/`.
4. Write `tasks.md`. Give each task a verification command.
5. Implement the tasks in order. Check each acceptance criterion at the end.

The `sdd-feature` skill makes Claude Code follow these steps.

## Logging

Bash, Python, and Java use the same format: `TIMESTAMP | LEVEL | COMPONENT | MESSAGE` in UTC on stderr. `LOG_LEVEL` sets the level in all three.

```text
2026-10-27T15:04:05Z | INFO  | ingest | step start: download
2026-10-27T15:04:06Z | INFO  | ingest | step done: download elapsed=1s
2026-10-27T15:04:06Z | INFO  | ingest | finished status=ok exit=0 elapsed=1s
```

**Bash** (`logging.sh`):

```bash
#!/usr/bin/env bash
source "$(dirname "$0")/logging.sh"        # strict mode, traps, exit summary
LOG_COMPONENT="ingest"

tmp="$(make_temp_dir)"                      # removed on exit
require_cmd curl
run_step "download" curl -fsSo "$tmp/data.csv" https://example.com/data.csv
retry 3 2 test -s "$tmp/data.csv"           # 3 attempts, backoff 2s then 4s
log_info "rows=$(wc -l < "$tmp/data.csv")"
```

**Python** (`logging.py`, copied as `log_config.py`):

```python
from log_config import log_execution, setup_logging

log = setup_logging("ingest")          # LOG_LEVEL, LOG_FORMAT=json, LOG_FILE
with log_execution(log, "load"):
    log.info("rows loaded", extra={"rows": 1024})
```

A project module named `logging.py` replaces the standard library `logging` module for every import. For this reason, `new-project.sh` copies the file as `log_config.py`.

**Java** (`logback.xml`): place the file in `src/main/resources/`. Use SLF4J in code:

```java
private static final Logger log = LoggerFactory.getLogger(Ingest.class);
log.info("rows loaded: {}", rows);
```

## SLURM

The job templates have no external dependencies. They run locally with `bash` for testing, and they use only environment variables that SLURM always sets, with safe defaults.

Paths below are the project paths after `new-project.sh ... slurm`.

| Command | Action |
| --- | --- |
| `sbatch slurm/job.sbatch` | Submit single job |
| `CONTAINER_IMAGE=app.sif sbatch slurm/job.sbatch` | Submit job inside Apptainer image |
| `sbatch --array=1-$(wc -l < inputs.txt)%10 slurm/array.sbatch` | One task per line of `inputs.txt`, 10 at a time |
| `slurm/report.sh [JOB_ID]` | Show state, memory, and CPU efficiency |

## Conventions

- **Bash:** `set -euo pipefail`, compatible with Bash 3.2 (macOS) and later.
- **Python:** 3.11 or later. `logging.py` uses the standard library only.
- **CI:** read-only permissions by default. Checks report problems and do not change code.
- **Dependencies:** all tool versions are pinned. Dependabot and `uvx pre-commit autoupdate` keep them current.
- **Actions pinning:** the workflows use version tags such as `@v4`. For supply-chain safety, replace each tag with its commit SHA. The [`pinact`](https://github.com/suzuki-shunsuke/pinact) CLI does this in one command.

## License

MIT. See [LICENSE](LICENSE).

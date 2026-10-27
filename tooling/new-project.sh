#!/usr/bin/env bash
# Copies toolkit templates into a target project without overwriting files
# Usage: new-project.sh [-n] <target-dir> <profile> [<profile> ...]
# Profiles: base agents python java node bash containers slurm docs all
# -n prints planned copies without writing
set -euo pipefail

TOOLKIT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
PROFILES="base agents python java node bash containers slurm docs"
DRY_RUN=0

usage() {
	echo "Usage: $(basename -- "$0") [-n] <target-dir> <profile> [<profile> ...]" >&2
	echo "Profiles: $PROFILES all" >&2
	exit 2
}

if [[ "${1:-}" == "-n" ]]; then
	DRY_RUN=1
	shift
fi
(($# >= 2)) || usage
target="$1"
shift

for p in "$@"; do
	[[ "$p" == "all" || " $PROFILES " == *" $p "* ]] || {
		echo "unknown profile: $p" >&2
		usage
	}
done

((DRY_RUN)) || mkdir -p "$target"
[[ -d "$target" ]] && target="$(cd -- "$target" && pwd)"

copied=0
skipped=0

# Copies one file, skips existing destination
put() {
	local src="$TOOLKIT/$1" dst="$target/$2"
	if [[ -e "$dst" ]]; then
		echo "  skip   $2 (exists)"
		skipped=$((skipped + 1))
		return 0
	fi
	echo "  create $2"
	copied=$((copied + 1))
	((DRY_RUN)) && return 0
	mkdir -p "$(dirname -- "$dst")"
	cp -p "$src" "$dst"
}

profile_base() {
	put tooling/.editorconfig .editorconfig
	put .gitignore .gitignore
	put tooling/.env.example .env.example
	put tooling/Makefile Makefile
	put pipelines/security.yml .github/workflows/security.yml
	put pipelines/actions-lint.yml .github/workflows/actions-lint.yml
	put pipelines/dependabot.yml .github/dependabot.yml
}

profile_agents() {
	put agents/AGENTS.md AGENTS.md
	put agents/CLAUDE.md CLAUDE.md
	put agents/code-review.md .claude/code-review.md
	put agents/claude-settings.json .claude/settings.json
	put agents/.mcp.json .mcp.json
	put agents/sdd-SKILL.md .claude/skills/sdd-feature/SKILL.md
	put agents/spec-template.md specs/_templates/spec.md
	put agents/plan-template.md specs/_templates/plan.md
	put agents/tasks-template.md specs/_templates/tasks.md
	put agents/adr-template.md docs/adr/0000-template.md
}

profile_python() {
	put tooling/pyproject.toml pyproject.toml
	put tooling/.pre-commit-config.yaml .pre-commit-config.yaml
	put tooling/requirements.txt requirements.txt
	put tooling/setup-uv.sh scripts/setup-uv.sh
	put tooling/logging.py src/log_config.py
	put pipelines/python-ci.yml .github/workflows/python-ci.yml
}

profile_java() {
	put tooling/logback.xml src/main/resources/logback.xml
	put pipelines/java-ci.yml .github/workflows/java-ci.yml
}

profile_node() {
	put tooling/.prettierrc.json .prettierrc.json
	put pipelines/node-ci.yml .github/workflows/node-ci.yml
}

profile_bash() {
	put tooling/.shellcheckrc .shellcheckrc
	put tooling/logging.sh scripts/logging.sh
	put tooling/benchmark.sh scripts/benchmark.sh
	put pipelines/shellcheck.yml .github/workflows/shellcheck.yml
}

profile_containers() {
	put containers/Dockerfile Dockerfile
	put containers/.dockerignore .dockerignore
	put containers/compose.yaml compose.yaml
	put containers/devcontainer.json .devcontainer/devcontainer.json
	put pipelines/docker-build.yml .github/workflows/docker-build.yml
}

profile_slurm() {
	put containers/slurm-job.sbatch slurm/job.sbatch
	put containers/slurm-array.sbatch slurm/array.sbatch
	put containers/slurm-report.sh slurm/report.sh
	put containers/apptainer.def apptainer.def
}

profile_docs() {
	put docs/README-template.md README.md
	put docs/CHANGELOG-template.md CHANGELOG.md
	put docs/RUNBOOK-template.md docs/RUNBOOK.md
}

selected=()
for p in "$@"; do
	if [[ "$p" == "all" ]]; then
		read -r -a selected <<<"$PROFILES"
		break
	fi
	selected+=("$p")
done

for p in "${selected[@]}"; do
	echo "[$p]"
	"profile_$p"
done

((DRY_RUN)) && echo "dry run: $copied would be created, $skipped skipped in $target" ||
	echo "done: $copied created, $skipped skipped in $target"

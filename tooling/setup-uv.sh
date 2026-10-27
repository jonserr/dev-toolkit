#!/usr/bin/env bash
# Sets up Python project environment with uv
# Installs uv if missing, installs Python, syncs dependencies, installs git hooks, creates .env
# Uses pyproject.toml when present, else requirements.txt, else creates empty venv
# Usage: setup-uv.sh [-p python-version] [--to-pyproject] [--no-install]
# Safe to run repeatedly
set -euo pipefail

PYTHON_VERSION="${PYTHON_VERSION:-3.12}"
INSTALL_UV=1
TO_PYPROJECT=0

usage() {
	cat >&2 <<EOF
Usage: $(basename -- "$0") [options]
  -p, --python VERSION   Python version (default: $PYTHON_VERSION)
  --to-pyproject         Convert requirements.txt into pyproject.toml with uv add
  --no-install           Fail instead of installing uv when missing
  -h, --help             Show this help
Env: UV_VERSION pins uv installer version, PYTHON_VERSION sets default Python
EOF
	exit 2
}

while (($# > 0)); do
	case "$1" in
		-p | --python)
			PYTHON_VERSION="${2:?missing version}"
			shift 2
			;;
		--to-pyproject)
			TO_PYPROJECT=1
			shift
			;;
		--no-install)
			INSTALL_UV=0
			shift
			;;
		*) usage ;;
	esac
done

log() { printf '%s | %-5s | setup-uv | %s\n' "$(date -u '+%Y-%m-%dT%H:%M:%SZ')" "$1" "$2" >&2; }

# Runs from git root when inside repository, else current directory
cd "$(git rev-parse --show-toplevel 2>/dev/null || pwd)"

# ---------------------------------------------------------------------------
# Install uv
# ---------------------------------------------------------------------------

if ! command -v uv >/dev/null 2>&1; then
	((INSTALL_UV)) || {
		log ERROR "uv not found, see https://docs.astral.sh/uv/getting-started/installation/"
		exit 1
	}
	if command -v brew >/dev/null 2>&1; then
		log INFO "installing uv with Homebrew"
		brew install uv
	else
		installer="https://astral.sh/uv/install.sh"
		[[ -n "${UV_VERSION:-}" ]] && installer="https://astral.sh/uv/${UV_VERSION}/install.sh"
		log INFO "installing uv from $installer"
		curl -LsSf "$installer" | sh
		# Installer puts uv in ~/.local/bin
		export PATH="$HOME/.local/bin:$PATH"
	fi
fi
log INFO "$(uv --version)"

# ---------------------------------------------------------------------------
# Python and dependencies
# ---------------------------------------------------------------------------

log INFO "ensuring Python $PYTHON_VERSION"
uv python install "$PYTHON_VERSION"

if ((TO_PYPROJECT)) && [[ -f requirements.txt ]]; then
	[[ -f pyproject.toml ]] || uv init --bare --python "$PYTHON_VERSION"
	log INFO "adding requirements.txt to pyproject.toml"
	uv add -r requirements.txt
fi

if [[ -f pyproject.toml ]]; then
	log INFO "syncing from pyproject.toml"
	uv sync --all-groups --python "$PYTHON_VERSION"
elif [[ -f requirements.txt ]]; then
	log INFO "installing from requirements.txt"
	[[ -d .venv ]] || uv venv --python "$PYTHON_VERSION"
	uv pip install -r requirements.txt
else
	log WARN "no pyproject.toml or requirements.txt, creating empty .venv"
	[[ -d .venv ]] || uv venv --python "$PYTHON_VERSION"
fi

# ---------------------------------------------------------------------------
# Project extras
# ---------------------------------------------------------------------------

if [[ -f .pre-commit-config.yaml ]] && git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
	log INFO "installing pre-commit hooks"
	uvx pre-commit install
fi

if [[ -f .env.example && ! -f .env ]]; then
	cp .env.example .env
	log WARN "created .env from .env.example, update values before use"
fi

log INFO "done, activate with: source .venv/bin/activate (or prefix commands with uv run)"

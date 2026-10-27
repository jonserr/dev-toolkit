#!/usr/bin/env bash
# Initializes directory as git repo, adds toolkit templates, optionally creates GitHub repo
# Local by default, --commit, --create, and --push opt in to history and remote changes
#
# Usage: setup-gh.sh [options] [profile ...]
#   Always includes base and agents profiles
#   Profiles: base agents python java node bash containers slurm docs all
#
# Examples:
#   ~/code/dev-toolkit/tooling/setup-gh.sh python docs
#   ~/code/dev-toolkit/tooling/setup-gh.sh --commit --create --push python
#   To copy templates only, use toolkit.mk from repo root
set -euo pipefail

TARGET="$PWD"
REPO_NAME=""
VISIBILITY="--private"
TOOLKIT="${DEV_TOOLKIT:-}"
DO_COMMIT=0
DO_CREATE=0
DO_PUSH=0
PROFILES=()

usage() {
	cat >&2 <<'EOF'
Usage: setup-gh.sh [options] [profile ...]
  -d, --dir DIR        target directory (default: current directory)
  -n, --name NAME      GitHub repo name (default: directory name)
  -t, --toolkit SRC    local toolkit path or GitHub owner/repo (env: DEV_TOOLKIT)
  --commit             create initial commit
  --create             create GitHub repo with gh and add origin remote
  --public             make GitHub repo public (default: private)
  --push               push to origin, implies --commit
  -h, --help           show this help
Profiles: python java node bash containers slurm docs all (base and agents always included)
EOF
	exit 2
}

while (($# > 0)); do
	case "$1" in
		-d | --dir)
			TARGET="${2:?missing directory}"
			shift 2
			;;
		-n | --name)
			REPO_NAME="${2:?missing name}"
			shift 2
			;;
		-t | --toolkit)
			TOOLKIT="${2:?missing toolkit}"
			shift 2
			;;
		--commit)
			DO_COMMIT=1
			shift
			;;
		--create)
			DO_CREATE=1
			shift
			;;
		--public)
			VISIBILITY="--public"
			shift
			;;
		--push)
			DO_PUSH=1
			DO_COMMIT=1
			shift
			;;
		-h | --help) usage ;;
		-*)
			echo "unknown option: $1" >&2
			usage
			;;
		*)
			PROFILES+=("$1")
			shift
			;;
	esac
done
# base and agents always included, new-project.sh skips files already copied
PROFILES=(base agents ${PROFILES[@]+"${PROFILES[@]}"})

log() { printf '%s | %-5s | setup-gh | %s\n' "$(date -u '+%Y-%m-%dT%H:%M:%SZ')" "$1" "$2" >&2; }
die() {
	log ERROR "$1"
	exit 1
}

command -v git >/dev/null 2>&1 || die "git not found"
mkdir -p "$TARGET"
cd "$TARGET"
REPO_NAME="${REPO_NAME:-$(basename -- "$PWD")}"

# ---------------------------------------------------------------------------
# Locate toolkit: --toolkit path, --toolkit owner/repo, or this script's repo
# ---------------------------------------------------------------------------

tmp_dir=""
cleanup() { [[ -z "$tmp_dir" ]] || rm -rf "$tmp_dir"; }
trap cleanup EXIT

script_dir=""
if [[ -n "${BASH_SOURCE[0]:-}" && -f "${BASH_SOURCE[0]}" ]]; then
	script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
fi

if [[ -n "$TOOLKIT" && -d "$TOOLKIT" ]]; then
	toolkit_dir="$(cd -- "$TOOLKIT" && pwd)"
elif [[ -n "$TOOLKIT" ]]; then
	[[ "$TOOLKIT" =~ ^[A-Za-z0-9._-]+/[A-Za-z0-9._-]+$ ]] || die "toolkit must be a path or owner/repo: $TOOLKIT"
	tmp_dir="$(mktemp -d "${TMPDIR:-/tmp}/dev-toolkit.XXXXXX")"
	log INFO "cloning toolkit $TOOLKIT"
	# gh handles private repos with existing login, git handles public repos
	if command -v gh >/dev/null 2>&1 && gh auth status >/dev/null 2>&1; then
		gh repo clone "$TOOLKIT" "$tmp_dir/toolkit" -- --depth 1 --quiet
	else
		git clone --depth 1 --quiet "https://github.com/$TOOLKIT.git" "$tmp_dir/toolkit"
	fi
	toolkit_dir="$tmp_dir/toolkit"
elif [[ -n "$script_dir" && -f "$script_dir/new-project.sh" ]]; then
	toolkit_dir="$(cd -- "$script_dir/.." && pwd)"
else
	die "toolkit not found, pass --toolkit <path|owner/repo> or set DEV_TOOLKIT"
fi
[[ -f "$toolkit_dir/tooling/new-project.sh" ]] || die "not a dev-toolkit: $toolkit_dir"

# ---------------------------------------------------------------------------
# Initialize git repo
# ---------------------------------------------------------------------------

if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
	log INFO "git repo exists at $(git rev-parse --show-toplevel)"
else
	git init --quiet --initial-branch=main 2>/dev/null || {
		git init --quiet
		git symbolic-ref HEAD refs/heads/main
	}
	log INFO "initialized git repo on branch main"
fi

# Keeps bootstrap Makefile out of commits without editing .gitignore
exclude_file="$(git rev-parse --git-path info/exclude)"
if [[ -f toolkit.mk ]] && ! grep -qx 'toolkit.mk' "$exclude_file" 2>/dev/null; then
	mkdir -p "$(dirname -- "$exclude_file")"
	echo "toolkit.mk" >>"$exclude_file"
fi

# ---------------------------------------------------------------------------
# Copy templates, existing files are never overwritten
# ---------------------------------------------------------------------------

log INFO "adding templates: ${PROFILES[*]}"
bash "$toolkit_dir/tooling/new-project.sh" "$PWD" "${PROFILES[@]}"

# ---------------------------------------------------------------------------
# Optional: initial commit
# ---------------------------------------------------------------------------

if ((DO_COMMIT)); then
	git config user.email >/dev/null || die "set git user.email before --commit"
	git add -A
	if git diff --cached --quiet; then
		log INFO "nothing to commit"
	else
		git commit --quiet -m "chore: initial project setup from dev-toolkit"
		log INFO "created initial commit $(git rev-parse --short HEAD)"
	fi
fi

# ---------------------------------------------------------------------------
# Optional: create GitHub repo and push
# ---------------------------------------------------------------------------

if ((DO_CREATE)); then
	command -v gh >/dev/null 2>&1 || die "gh not found, install with: brew install gh"
	gh auth status >/dev/null 2>&1 || die "gh not logged in, run: gh auth login"
	if git remote get-url origin >/dev/null 2>&1; then
		log WARN "origin already set to $(git remote get-url origin), skipping create"
	else
		gh repo create "$REPO_NAME" "$VISIBILITY" --source=. --remote=origin
		log INFO "created GitHub repo $REPO_NAME (${VISIBILITY#--})"
	fi
fi

if ((DO_PUSH)); then
	git remote get-url origin >/dev/null 2>&1 || die "no origin remote, add one or use --create"
	git push --set-upstream origin "$(git branch --show-current)"
	log INFO "pushed to $(git remote get-url origin)"
fi

log INFO "done, next: make setup && make check"

#!/usr/bin/env bash
# Bash logging, strict mode, error traps, cleanup, and helpers in one self-contained file
# Works on Bash 3.2+ (macOS) and Linux with POSIX date
# Usage: source "$(dirname "$0")/logging.sh"
# Env: LOG_LEVEL (DEBUG|INFO|WARN|ERROR), LOG_COMPONENT, LOG_FILE, LOG_COLOR (auto|always|never), NO_COLOR
# Log format: TIMESTAMP | LEVEL | COMPONENT | MESSAGE

# Prevents double sourcing
[[ -n "${_LOGGING_SH_LOADED:-}" ]] && return 0
_LOGGING_SH_LOADED=1

set -Eeuo pipefail

: "${LOG_LEVEL:=INFO}"
: "${LOG_COMPONENT:=$(basename -- "${0:-shell}")}"
: "${LOG_FILE:=}"
: "${LOG_COLOR:=auto}"

# ---------------------------------------------------------------------------
# Logging
# ---------------------------------------------------------------------------

_log_level_num() {
	case "$1" in
		DEBUG) echo 10 ;;
		INFO) echo 20 ;;
		WARN) echo 30 ;;
		ERROR) echo 40 ;;
		FATAL) echo 50 ;;
		*) echo 20 ;;
	esac
}

_log_use_color() {
	[[ -n "${NO_COLOR:-}" ]] && return 1
	case "$LOG_COLOR" in
		always) return 0 ;;
		never) return 1 ;;
		*) [[ -t 2 ]] ;;
	esac
}

_log() {
	local level="$1"
	shift
	if (($(_log_level_num "$level") < $(_log_level_num "$LOG_LEVEL"))); then
		return 0
	fi

	local line color reset=$'\033[0m'
	line="$(printf '%s | %-5s | %s | %s' "$(timestamp)" "$level" "$LOG_COMPONENT" "$*")"

	if _log_use_color; then
		case "$level" in
			DEBUG) color=$'\033[2m' ;;
			INFO) color=$'\033[32m' ;;
			WARN) color=$'\033[33m' ;;
			*) color=$'\033[31m' ;;
		esac
		printf '%s%s%s\n' "$color" "$line" "$reset" >&2
	else
		printf '%s\n' "$line" >&2
	fi

	# File output stays uncolored for grep and log shippers
	if [[ -n "$LOG_FILE" ]]; then
		printf '%s\n' "$line" >>"$LOG_FILE"
	fi
}

# UTC ISO 8601 timestamp, POSIX date format specifiers only
timestamp() { date -u '+%Y-%m-%dT%H:%M:%SZ'; }

log_debug() { _log DEBUG "$@"; }
log_info() { _log INFO "$@"; }
log_warn() { _log WARN "$@"; }
log_error() { _log ERROR "$@"; }
log_section() { _log INFO "==== $* ===="; }

# Logs at FATAL level and exits, optional first argument sets exit code
log_fatal() {
	local code=1
	if [[ "${1:-}" =~ ^[0-9]+$ ]] && (($# > 1)); then
		code="$1"
		shift
	fi
	_log FATAL "$@"
	exit "$code"
}

die() { log_fatal "$@"; }

# ---------------------------------------------------------------------------
# Traps, cleanup, and execution summary
# ---------------------------------------------------------------------------

_SCRIPT_START="$(date +%s)"
_CLEANUP_CMDS=()

# Registers command to run on exit in LIFO order
add_cleanup() {
	_CLEANUP_CMDS+=("$*")
}

# Logs failing command, line, and call stack
_on_error() {
	local code="$1" line="$2" cmd="$3" i
	log_error "command failed: exit=$code line=$line cmd=$cmd"
	for ((i = 1; i < ${#FUNCNAME[@]}; i++)); do
		log_error "  at ${FUNCNAME[$i]}() ${BASH_SOURCE[$i]:-?}:${BASH_LINENO[$((i - 1))]}"
	done
}

_on_exit() {
	local code=$? i
	set +e
	for ((i = ${#_CLEANUP_CMDS[@]} - 1; i >= 0; i--)); do
		eval "${_CLEANUP_CMDS[$i]}" || log_warn "cleanup failed: ${_CLEANUP_CMDS[$i]}"
	done

	local elapsed=$(($(date +%s) - _SCRIPT_START))
	if ((code == 0)); then
		log_info "finished status=ok exit=0 elapsed=$(format_duration "$elapsed")"
	else
		log_error "finished status=failed exit=$code elapsed=$(format_duration "$elapsed")"
	fi
	exit "$code"
}

trap '_on_error $? $LINENO "$BASH_COMMAND"' ERR
trap _on_exit EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

# ---------------------------------------------------------------------------
# Checks
# ---------------------------------------------------------------------------

# Returns 0 when command exists
has_cmd() { command -v "$1" >/dev/null 2>&1; }

# Exits when any listed command is missing
require_cmd() {
	local cmd missing=0
	for cmd in "$@"; do
		has_cmd "$cmd" || {
			log_error "missing required command: $cmd"
			missing=1
		}
	done
	((missing == 0)) || die "install missing commands and retry"
}

# Exits when any listed environment variable is empty
require_env() {
	local var missing=0
	for var in "$@"; do
		[[ -n "${!var:-}" ]] || {
			log_error "missing required environment variable: $var"
			missing=1
		}
	done
	((missing == 0)) || die "set missing variables and retry"
}

# Exits when file is missing or unreadable
require_file() {
	local f
	for f in "$@"; do
		[[ -r "$f" ]] || die "file not found or unreadable: $f"
	done
}

# ---------------------------------------------------------------------------
# Execution helpers
# ---------------------------------------------------------------------------

# Runs named step with timing and status logs
# Usage: run_step "build" make build
run_step() {
	local name="$1" start code=0
	shift
	start="$(date +%s)"
	log_info "step start: $name"
	"$@" || code=$?
	local elapsed=$(($(date +%s) - start))
	if ((code == 0)); then
		log_info "step done: $name elapsed=$(format_duration "$elapsed")"
	else
		log_error "step failed: $name exit=$code elapsed=$(format_duration "$elapsed")"
	fi
	return "$code"
}

# Retries command with exponential backoff
# Usage: retry <attempts> <initial-delay-seconds> command [args...]
retry() {
	local attempts="$1" delay="$2" n=1
	shift 2
	until "$@"; do
		if ((n >= attempts)); then
			log_error "retry exhausted after $n attempts: $*"
			return 1
		fi
		log_warn "attempt $n/$attempts failed, retrying in ${delay}s: $*"
		sleep "$delay"
		delay=$((delay * 2))
		n=$((n + 1))
	done
}

# Logs command, then runs it, or only logs it when DRY_RUN=1
run() {
	log_debug "run: $*"
	if [[ "${DRY_RUN:-0}" == "1" ]]; then
		log_info "dry-run: $*"
		return 0
	fi
	"$@"
}

# Prompts for yes or no, returns 0 on yes, default no, non-interactive returns 1
confirm() {
	local reply
	[[ -t 0 ]] || return 1
	read -r -p "${1:-Continue?} [y/N] " reply
	[[ "$reply" =~ ^[Yy]([Ee][Ss])?$ ]]
}

# Creates temp directory removed on exit, prints path
make_temp_dir() {
	local dir
	dir="$(mktemp -d "${TMPDIR:-/tmp}/${LOG_COMPONENT}.XXXXXX")"
	add_cleanup "rm -rf '$dir'"
	printf '%s\n' "$dir"
}

# ---------------------------------------------------------------------------
# Utilities
# ---------------------------------------------------------------------------

# Formats seconds as 1h02m03s, 2m03s, or 3s
format_duration() {
	local s="$1"
	if ((s >= 3600)); then
		printf '%dh%02dm%02ds' $((s / 3600)) $((s % 3600 / 60)) $((s % 60))
	elif ((s >= 60)); then
		printf '%dm%02ds' $((s / 60)) $((s % 60))
	else
		printf '%ds' "$s"
	fi
}

# Prints absolute path without realpath dependency
abs_path() {
	if [[ -d "$1" ]]; then
		(cd -- "$1" && pwd)
	else
		printf '%s/%s\n' "$(cd -- "$(dirname -- "$1")" && pwd)" "$(basename -- "$1")"
	fi
}

# Prints linux, macos, or unknown
os_name() {
	case "$(uname -s)" in
		Linux) echo linux ;;
		Darwin) echo macos ;;
		*) echo unknown ;;
	esac
}

# Loads KEY=VALUE pairs from file into environment, skips comments and blanks
load_env_file() {
	local file="${1:-.env}" line
	[[ -f "$file" ]] || return 0
	while IFS= read -r line || [[ -n "$line" ]]; do
		[[ "$line" =~ ^[[:space:]]*(#|$) ]] && continue
		[[ "$line" =~ ^[A-Za-z_][A-Za-z0-9_]*= ]] || continue
		export "${line?}"
	done <"$file"
	log_debug "loaded environment from $file"
}

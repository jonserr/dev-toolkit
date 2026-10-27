#!/usr/bin/env bash
# Measures wall time and peak memory of a command over several runs
# Usage: benchmark.sh [-n runs] [-w warmup] -- command [args...]
# Use hyperfine for statistical comparison of several commands
set -Eeuo pipefail

runs=5
warmup=1

usage() {
	echo "Usage: $(basename -- "$0") [-n runs] [-w warmup] -- command [args...]" >&2
	exit 2
}

while getopts ":n:w:h" opt; do
	case "$opt" in
		n) runs="$OPTARG" ;;
		w) warmup="$OPTARG" ;;
		*) usage ;;
	esac
done
shift $((OPTIND - 1))
[[ "${1:-}" == "--" ]] && shift
(($# > 0)) || usage

# BSD time reports bytes, GNU time reports kilobytes
time_cmd=()
rss_kb() { echo "n/a"; }
if [[ -x /usr/bin/time ]]; then
	if /usr/bin/time -l true >/dev/null 2>&1; then
		time_cmd=(/usr/bin/time -l)
		rss_kb() { awk '/maximum resident set size/ {printf "%d", $1 / 1024}' "$1"; }
	elif /usr/bin/time -v true >/dev/null 2>&1; then
		time_cmd=(/usr/bin/time -v)
		rss_kb() { awk -F': ' '/Maximum resident set size/ {print $2}' "$1"; }
	fi
fi

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

for ((i = 0; i < warmup; i++)); do "$@" >/dev/null 2>&1 || true; done

TIMEFORMAT=%R
echo "run,seconds,max_rss_kb"
for ((i = 1; i <= runs; i++)); do
	# Empty-array expansion guard for Bash 3.2 with set -u
	if ! { time ${time_cmd[@]+"${time_cmd[@]}"} "$@" >/dev/null 2>"$tmp/mem"; } 2>"$tmp/time"; then
		echo "command failed on run $i" >&2
		cat "$tmp/mem" >&2
		exit 1
	fi
	echo "$i,$(tail -n1 "$tmp/time"),$(rss_kb "$tmp/mem")" | tee -a "$tmp/results"
done

awk -F, '
	{ s += $2; if (NR == 1 || $2 < min) min = $2; if ($2 > max) max = $2
	  if ($3 ~ /^[0-9]+$/ && $3 > rss) rss = $3 }
	END { printf "\nruns=%d min=%.3fs mean=%.3fs max=%.3fs peak_rss=%s\n", NR, min, s / NR, max, (rss ? rss " KB" : "n/a") }
' "$tmp/results"

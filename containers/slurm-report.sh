#!/usr/bin/env bash
# Reports SLURM job state, exit code, runtime, memory, and CPU efficiency
# Uses sacct fields available in all supported SLURM versions, seff when present
# Usage: slurm-report.sh <jobid> [<jobid> ...]
#        slurm-report.sh --recent [hours]
set -euo pipefail

FIELDS="JobID,JobName%30,State,ExitCode,Elapsed,Timelimit,AllocCPUS,TotalCPU,ReqMem,MaxRSS,NodeList"

usage() {
	echo "Usage: $(basename -- "$0") <jobid> [<jobid> ...] | --recent [hours]" >&2
	exit 2
}

command -v sacct >/dev/null 2>&1 || {
	echo "sacct not found, run on a SLURM login node" >&2
	exit 1
}
(($# > 0)) || usage

# Lists own jobs from last N hours
if [[ "$1" == "--recent" ]]; then
	hours="${2:-24}"
	start="$(date -d "-${hours} hours" '+%Y-%m-%dT%H:%M:%S' 2>/dev/null || date -v "-${hours}H" '+%Y-%m-%dT%H:%M:%S')"
	sacct -u "${USER:-$(id -un)}" -X -S "$start" --format=JobID,JobName%30,State,ExitCode,Elapsed,Start
	exit 0
fi

# Converts [D-]HH:MM:SS or MM:SS.mmm to seconds
secs_awk='
function secs(t,   d, a, n) {
	d = 0
	if (index(t, "-")) { split(t, a, "-"); d = a[1]; t = a[2] }
	n = split(t, a, ":")
	if (n == 3) return d * 86400 + a[1] * 3600 + a[2] * 60 + a[3]
	if (n == 2) return a[1] * 60 + a[2]
	return a[1] + 0
}'

for job in "$@"; do
	echo "=== Job $job ==="
	sacct -j "$job" --format="$FIELDS"

	if command -v seff >/dev/null 2>&1; then
		echo
		seff "$job" || true
	else
		# CPU efficiency = TotalCPU / (Elapsed * AllocCPUS)
		sacct -j "$job" -X -n -P --format=Elapsed,TotalCPU,AllocCPUS | awk -F'|' "$secs_awk"'
			{ wall = secs($1) * $3; if (wall > 0) printf "\nCPU efficiency: %.1f%%\n", 100 * secs($2) / wall }'
	fi

	# Common failure hints by state
	state="$(sacct -j "$job" -X -n -P --format=State | head -n1 | awk '{print $1}')"
	case "$state" in
		OUT_OF_MEMORY*) echo "Hint: increase --mem to about 1.5x MaxRSS" ;;
		TIMEOUT*) echo "Hint: increase --time or add checkpointing" ;;
		NODE_FAIL*) echo "Hint: resubmit, optionally --exclude=<node>" ;;
		FAILED*) echo "Hint: check the .err file, exit code 127 means command not found" ;;
		PENDING*) squeue -j "$job" -o "%.18i %.9T %r" 2>/dev/null || true ;;
	esac
	echo
done

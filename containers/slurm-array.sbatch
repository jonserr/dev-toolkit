#!/bin/bash
# Self-contained SLURM job array template, one task per line of INPUT_LIST
# Submit:     sbatch --array=1-$(wc -l < inputs.txt)%10 slurm-array.sbatch
# Test local: SLURM_ARRAY_TASK_ID=1 bash slurm-array.sbatch
#
# %A = array job ID, %a = task index, %10 limits concurrent tasks
#SBATCH --job-name=my-array
#SBATCH --output=%x-%A_%a.out
#SBATCH --error=%x-%A_%a.err
#SBATCH --array=1-10%10
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=2
#SBATCH --mem=4G
#SBATCH --time=00:30:00
##SBATCH --partition=compute
##SBATCH --account=my-account

set -euo pipefail

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------

INPUT_LIST="${INPUT_LIST:-inputs.txt}"
OUTPUT_DIR="${OUTPUT_DIR:-results}"

# Command per task, called as: process_task <input> <output>
process_task() {
	python -m my_project.process --input "$1" --output "$2"
}

# ---------------------------------------------------------------------------
# Task setup
# ---------------------------------------------------------------------------

TASK_ID="${SLURM_ARRAY_TASK_ID:?set SLURM_ARRAY_TASK_ID or submit with sbatch --array}"
JOB_NAME="${SLURM_JOB_NAME:-$(basename -- "$0" .sbatch)}"
START_TS=$(date +%s)

log() {
	printf '%s | %-5s | %s[%s] | %s\n' "$(date -u '+%Y-%m-%dT%H:%M:%SZ')" "$1" "$JOB_NAME" "$TASK_ID" "$2" >&2
}

on_exit() {
	local code=$?
	log "$( ((code == 0)) && echo INFO || echo ERROR)" "task end: exit=$code elapsed=$(($(date +%s) - START_TS))s"
}
trap on_exit EXIT

cd "${SLURM_SUBMIT_DIR:-$PWD}"
[[ -r "$INPUT_LIST" ]] || {
	log ERROR "input list not found: $INPUT_LIST"
	exit 1
}

# awk handles missing trailing newline and Windows line endings
input="$(awk -v n="$TASK_ID" 'NR == n { sub(/\r$/, ""); print; exit }' "$INPUT_LIST")"
[[ -n "$input" ]] || {
	log ERROR "no input at line $TASK_ID of $INPUT_LIST"
	exit 1
}

mkdir -p "$OUTPUT_DIR"
output="$OUTPUT_DIR/$(basename -- "$input").out"

# Skips completed tasks so failed arrays can be resubmitted safely
if [[ -s "$output" ]]; then
	log INFO "skip: output exists $output"
	exit 0
fi

log INFO "task start: array=${SLURM_ARRAY_JOB_ID:-local} host=$(hostname) cpus=${SLURM_CPUS_PER_TASK:-1}"
log INFO "input=$input output=$output"

export OMP_NUM_THREADS="${SLURM_CPUS_PER_TASK:-1}"

# ---------------------------------------------------------------------------
# Run
# ---------------------------------------------------------------------------

# Writes to temp file then renames so partial output never looks complete
process_task "$input" "$output.tmp"
mv -f "$output.tmp" "$output"

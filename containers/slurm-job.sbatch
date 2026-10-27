#!/bin/bash
# Self-contained SLURM batch job template
# Submit:     sbatch slurm-job.sbatch
# Test local: bash slurm-job.sbatch
# Override:   sbatch --time=04:00:00 --mem=32G slurm-job.sbatch
#
# Directives below use options common to all SLURM versions
# %x = job name, %j = job ID, output lands in submit directory
#SBATCH --job-name=my-job
#SBATCH --output=%x-%j.out
#SBATCH --error=%x-%j.err
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=4
#SBATCH --mem=16G
#SBATCH --time=02:00:00
# Site-specific options, remove one leading # to enable
##SBATCH --partition=compute
##SBATCH --account=my-account
##SBATCH --qos=normal
##SBATCH --gres=gpu:1
##SBATCH --mail-type=END,FAIL
##SBATCH --mail-user=email@example.com

set -euo pipefail

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------

# Command to run, one array element per argument
APP_CMD=(python -m my_project.main --input data/input.csv)

# Environment modules to load, empty when cluster has no module system
MODULES=()

# Optional Apptainer/Singularity image, empty runs on host
CONTAINER_IMAGE="${CONTAINER_IMAGE:-}"

# Optional virtual environment to activate
VENV_DIR="${VENV_DIR:-}"

# ---------------------------------------------------------------------------
# Logging and lifecycle
# ---------------------------------------------------------------------------

JOB_ID="${SLURM_JOB_ID:-local-$$}"
JOB_NAME="${SLURM_JOB_NAME:-$(basename -- "$0" .sbatch)}"
START_TS=$(date +%s)

log() {
	printf '%s | %-5s | %s | %s\n' "$(date -u '+%Y-%m-%dT%H:%M:%SZ')" "$1" "$JOB_NAME" "$2" >&2
}

on_exit() {
	local code=$?
	local elapsed=$(($(date +%s) - START_TS))
	if ((code == 0)); then
		log INFO "job end: id=$JOB_ID status=ok elapsed=${elapsed}s"
	else
		log ERROR "job end: id=$JOB_ID status=failed exit=$code elapsed=${elapsed}s"
		log ERROR "details: sacct -j $JOB_ID --format=JobID,State,ExitCode,Elapsed,MaxRSS"
	fi
}
trap on_exit EXIT

log INFO "job start: id=$JOB_ID host=$(hostname) user=${USER:-unknown}"
# Memory is per node or per CPU depending on submit options
if [[ -n "${SLURM_MEM_PER_NODE:-}" ]]; then
	mem="${SLURM_MEM_PER_NODE}MB/node"
elif [[ -n "${SLURM_MEM_PER_CPU:-}" ]]; then
	mem="${SLURM_MEM_PER_CPU}MB/cpu"
else
	mem="unset"
fi
log INFO "resources: nodes=${SLURM_JOB_NUM_NODES:-1} tasks=${SLURM_NTASKS:-1} cpus_per_task=${SLURM_CPUS_PER_TASK:-1} mem=$mem gpus=${SLURM_GPUS_ON_NODE:-0}"
log INFO "placement: partition=${SLURM_JOB_PARTITION:-n/a} nodelist=${SLURM_JOB_NODELIST:-$(hostname)}"
log INFO "workdir: ${SLURM_SUBMIT_DIR:-$PWD}"

# ---------------------------------------------------------------------------
# Environment setup
# ---------------------------------------------------------------------------

cd "${SLURM_SUBMIT_DIR:-$PWD}"

if ((${#MODULES[@]} > 0)); then
	if command -v module >/dev/null 2>&1; then
		module purge
		module load "${MODULES[@]}"
	else
		log WARN "module command not found, skipping: ${MODULES[*]}"
	fi
fi

if [[ -n "$VENV_DIR" ]]; then
	# shellcheck source=/dev/null
	source "$VENV_DIR/bin/activate"
fi

# Match thread pools to allocated CPUs
export OMP_NUM_THREADS="${SLURM_CPUS_PER_TASK:-1}"
export MKL_NUM_THREADS="$OMP_NUM_THREADS"

# ---------------------------------------------------------------------------
# Run
# ---------------------------------------------------------------------------

# srun only inside allocation, so local test runs work
launcher=()
if [[ -n "${SLURM_JOB_ID:-}" ]] && command -v srun >/dev/null 2>&1; then
	launcher+=(srun)
fi

if [[ -n "$CONTAINER_IMAGE" ]]; then
	runtime="$(command -v apptainer || command -v singularity || true)"
	[[ -n "$runtime" ]] || {
		log ERROR "CONTAINER_IMAGE set but apptainer/singularity not found"
		exit 1
	}
	launcher+=("$runtime" exec --cleanenv --bind "$PWD")
	[[ -n "${SLURM_GPUS_ON_NODE:-}" ]] && launcher+=(--nv)
	launcher+=("$CONTAINER_IMAGE")
fi

log INFO "command: ${launcher[*]+${launcher[*]} }${APP_CMD[*]}"
${launcher[@]+"${launcher[@]}"} "${APP_CMD[@]}"

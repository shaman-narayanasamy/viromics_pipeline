#!/bin/bash -l

set -euo pipefail

PROJECT_REPO="${PROJECT_REPO:-/mnt/aiongpfs/users/snarayanasamy/repositories/phage_uv_ecology_analysis}"
PIPELINE_REPO="${PIPELINE_REPO:-/mnt/aiongpfs/users/snarayanasamy/repositories/viromics_pipeline}"
PROJECT_DIR="${PROJECT_DIR:-/scratch/users/snarayanasamy/phage_uv_treatment}"
LAUNCHER="${PIPELINE_REPO}/launchers/sbatch_viromics_identification_PRJEB79569.sh"
LOG_DIR="${PROJECT_REPO}/logs"
SLEEP_SECONDS="${SLEEP_SECONDS:-600}"

mkdir -p "${LOG_DIR}"

find_identification_pids() {
    ps -u "${USER}" -o pid=,cmd= \
        | awk '/snakemake/ && /workflows\/identification[.]smk/ && !/awk / {print $1}'
}

if [[ $# -gt 0 ]]; then
    CURRENT_PIDS=("$@")
else
    mapfile -t CURRENT_PIDS < <(find_identification_pids)
fi

if [[ ${#CURRENT_PIDS[@]} -gt 0 ]]; then
    echo "Watching current viromics identification controller PID(s): ${CURRENT_PIDS[*]}"
else
    echo "No active viromics identification controller found; checking targets now."
fi

while [[ ${#CURRENT_PIDS[@]} -gt 0 ]]; do
    still_running=()
    for pid in "${CURRENT_PIDS[@]}"; do
        if kill -0 "${pid}" 2>/dev/null; then
            still_running+=("${pid}")
        fi
    done

    if [[ ${#still_running[@]} -eq 0 ]]; then
        break
    fi

    echo "$(date): still waiting for controller PID(s): ${still_running[*]}"
    CURRENT_PIDS=("${still_running[@]}")
    sleep "${SLEEP_SECONDS}"
done

echo "$(date): current controller is no longer running; checking workflow state."

export CONDA_CHANNEL_PRIORITY=flexible

set +e
"${LAUNCHER}" --dry-run
dry_run_status=$?
set -e

if [[ ${dry_run_status} -eq 0 ]]; then
    echo "$(date): dry-run succeeded. If Snakemake reported pending jobs above, launching now."
    exec "${LAUNCHER}"
fi

echo "$(date): dry-run failed with status ${dry_run_status}; unlocking and retrying once."
"${LAUNCHER}" --unlock
"${LAUNCHER}" --dry-run
exec "${LAUNCHER}"

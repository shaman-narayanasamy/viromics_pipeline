#!/bin/bash -l
#SBATCH --job-name=install_viromics_databases
#SBATCH --account=michael.heneka
#SBATCH --partition=batch
#SBATCH --qos=iris-batch-long
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=16
#SBATCH --mem=64G
#SBATCH --time=3-00:00:00
#SBATCH --output=/mnt/isilon/projects/bioinformatics_platform/projects/shared_references/viromics_pipeline/logs/%x-%j.out
#SBATCH --error=/mnt/isilon/projects/bioinformatics_platform/projects/shared_references/viromics_pipeline/logs/%x-%j.err

set -euo pipefail

REPO_DIR="${VIROMICS_PIPELINE_REPO:-/mnt/aiongpfs/users/snarayanasamy/repositories/viromics_pipeline}"
BASE_DIR="${VIROMICS_REF_DIR:-/mnt/isilon/projects/bioinformatics_platform/projects/shared_references/viromics_pipeline}"
ENV_ROOT="${VIROMICS_DB_ENV_ROOT:-/work/projects/bioinformatics_platform/cache/viromics_db_envs}"
THREADS="${SLURM_CPUS_PER_TASK:-8}"

GENOMAD_DB="${BASE_DIR}/genomad"
VIRSORTER2_DB="${BASE_DIR}/virsorter2"
VIRALM_DIR="${BASE_DIR}/viralm"
LOG_DIR="${BASE_DIR}/logs"
TMP_DIR="${BASE_DIR}/tmp"

mkdir -p "${BASE_DIR}" "${LOG_DIR}" "${TMP_DIR}" "${ENV_ROOT}"

source "$(conda info --base)/etc/profile.d/conda.sh"

ensure_env() {
    local env_path="$1"
    local env_file="$2"

    if [[ -x "${env_path}/bin/python" ]]; then
        echo "Using existing conda environment: ${env_path}"
        return
    fi

    echo "Creating conda environment: ${env_path}"
    conda env create -p "${env_path}" -f "${env_file}"
}

dir_has_contents() {
    [[ -d "$1" ]] && find "$1" -mindepth 1 -print -quit | grep -q .
}

install_genomad() {
    local env_path="${ENV_ROOT}/genomad"
    local staging="${TMP_DIR}/genomad_download"

    if dir_has_contents "${GENOMAD_DB}"; then
        echo "geNomad database already exists at ${GENOMAD_DB}; skipping."
        return
    fi

    ensure_env "${env_path}" "${REPO_DIR}/envs/genomad_env.yml"
    rm -rf "${staging}" "${GENOMAD_DB}.tmp"
    mkdir -p "${staging}"

    echo "Downloading geNomad database..."
    conda run -p "${env_path}" genomad download-database "${staging}"

    if [[ ! -d "${staging}/genomad_db" ]]; then
        echo "Error: geNomad download did not create ${staging}/genomad_db" >&2
        exit 2
    fi

    mv "${staging}/genomad_db" "${GENOMAD_DB}.tmp"
    rm -rf "${GENOMAD_DB}"
    mv "${GENOMAD_DB}.tmp" "${GENOMAD_DB}"
    rm -rf "${staging}"
    echo "geNomad database installed at ${GENOMAD_DB}"
}

install_virsorter2() {
    local env_path="${ENV_ROOT}/virsorter2"
    local staging="${VIRSORTER2_DB}.tmp"

    if dir_has_contents "${VIRSORTER2_DB}"; then
        echo "VirSorter2 database already exists at ${VIRSORTER2_DB}; skipping."
        return
    fi

    ensure_env "${env_path}" "${REPO_DIR}/envs/virsorter2_env.yml"
    rm -rf "${staging}"

    echo "Downloading and setting up VirSorter2 database..."
    conda run -p "${env_path}" virsorter setup -d "${staging}" -j "${THREADS}"

    rm -rf "${VIRSORTER2_DB}"
    mv "${staging}" "${VIRSORTER2_DB}"
    echo "VirSorter2 database installed at ${VIRSORTER2_DB}"
}

install_viralm() {
    local tools_env="${ENV_ROOT}/download_tools"
    local staging="${VIRALM_DIR}.tmp"

    if [[ -f "${VIRALM_DIR}/predict.py" ]] && dir_has_contents "${VIRALM_DIR}"; then
        echo "ViraLM code/model already exists at ${VIRALM_DIR}; skipping."
        return
    fi

    if [[ ! -x "${tools_env}/bin/python" ]]; then
        echo "Creating lightweight download tools environment: ${tools_env}"
        conda create -y -p "${tools_env}" -c conda-forge python=3.10 gdown
    else
        echo "Using existing download tools environment: ${tools_env}"
    fi

    rm -rf "${staging}"
    echo "Cloning ViraLM..."
    git clone https://github.com/ChengPENG-wolf/ViraLM.git "${staging}"

    echo "Downloading ViraLM model..."
    conda run -p "${tools_env}" gdown 1EQVPmFbpLGrBLU0xCtZBpwvXrtrRxic1 -O "${staging}/model.tar.gz"
    tar -xzvf "${staging}/model.tar.gz" -C "${staging}"
    rm -f "${staging}/model.tar.gz"

    if [[ ! -f "${staging}/viralm.py" ]]; then
        echo "Error: ViraLM clone did not include viralm.py" >&2
        exit 2
    fi

    cat > "${staging}/predict.py" <<'PY'
#!/usr/bin/env python3
"""Compatibility wrapper for workflows expecting ViraLM predict.py."""
from __future__ import annotations

import os
import sys
from pathlib import Path


def translate_args(args: list[str]) -> list[str]:
    translated: list[str] = []
    for arg in args:
        if arg == "-f":
            translated.append("--force")
        elif arg == "-n":
            translated.append("--filename")
        else:
            translated.append(arg)
    return translated


script = Path(__file__).with_name("viralm.py")
os.execv(sys.executable, [sys.executable, str(script), *translate_args(sys.argv[1:])])
PY
    chmod +x "${staging}/predict.py"

    rm -rf "${VIRALM_DIR}"
    mv "${staging}" "${VIRALM_DIR}"
    echo "ViraLM code/model installed at ${VIRALM_DIR}"
}

install_genomad
install_virsorter2
install_viralm

echo "Validating expected viromics database paths..."
test -d "${GENOMAD_DB}"
test -d "${VIRSORTER2_DB}"
test -d "${VIRALM_DIR}"
test -f "${VIRALM_DIR}/predict.py"

echo "Viromics database setup complete."

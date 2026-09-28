#!/bin/bash -l

set -euo pipefail

PROJECT_REPO="${PROJECT_REPO:-/mnt/aiongpfs/users/snarayanasamy/repositories/phage_uv_ecology_analysis}"

exec "${PROJECT_REPO}/launchers/sbatch_viromics_identification.sh" "$@"

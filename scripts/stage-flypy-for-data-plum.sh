#!/usr/bin/env bash
set -euo pipefail

# Stages flypy Rime files from flypy-rime-config/rime into build/flypy-staged,
# applies trimmed-bundle patches, then merges them into data/plum for Xcode packaging.
# The reference tree flypy-rime-config/ is never modified.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
SRC_DIR="${REPO_ROOT}/flypy-rime-config/rime"
STAGE_DIR="${REPO_ROOT}/build/flypy-staged"
OUT_DIR="${REPO_ROOT}/data/plum"

# Prints an error message to stderr and exits non-zero.
die() {
    echo "stage-flypy-for-data-plum: $*" >&2
    exit 1
}

# Ensures the reference configuration directory exists before staging.
require_reference_dir() {
    test -d "${SRC_DIR}" || die "missing ${SRC_DIR}; place upstream flypy files under flypy-rime-config/rime/"
}

# Recreates an empty staging directory under build/.
reset_staging_dir() {
    rm -rf "${STAGE_DIR}"
    mkdir -p "${STAGE_DIR}"
}

# Copies the reference Rime tree into the staging directory (excluding junk files).
copy_reference_into_staging() {
    rsync -a --exclude ".DS_Store" "${SRC_DIR}/" "${STAGE_DIR}/"
}

# Removes flypydz artifacts from the staging tree only (reference copy stays intact).
remove_staged_flypydz_bundle() {
    rm -f "${STAGE_DIR}/flypydz.schema.yaml" "${STAGE_DIR}/flypydz.dict.yaml"
}

# Patches flypy.schema.yaml inside staging to match the reduced M2 bundle.
patch_staged_flypy_schema() {
    python3 "${REPO_ROOT}/scripts/patch_flypy_schema_trimmed.py" "${STAGE_DIR}/flypy.schema.yaml"
}

# Merges staged files into data/plum without deleting unrelated preset files.
sync_into_data_plum() {
    mkdir -p "${OUT_DIR}"
    rsync -a "${STAGE_DIR}/" "${OUT_DIR}/"
}

require_reference_dir
reset_staging_dir
copy_reference_into_staging
remove_staged_flypydz_bundle
patch_staged_flypy_schema
sync_into_data_plum

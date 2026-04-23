#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

APP_ROOT="/Library/Input Methods/SquirrelFlypy.app"
APP_BIN="${APP_ROOT}/Contents/MacOS/SquirrelFlypy"
APP_SHARED_SUPPORT="${APP_ROOT}/Contents/SharedSupport"

RUN_BUILD=0
RUN_RELOAD=0

for arg in "$@"; do
  case "${arg}" in
    --build)
      RUN_BUILD=1
      ;;
    --reload)
      RUN_RELOAD=1
      ;;
    --help|-h)
      cat <<'EOF'
Usage:
  bash scripts/dev-rebuild.sh [--build] [--reload]

What this script does:
  1) Rebuild and reinstall debug app via `make install-debug`.
  2) Optionally run schema deployment with `--build`.
  3) Optionally trigger app reload with `--reload`.
EOF
      exit 0
      ;;
    *)
      echo "Unknown argument: ${arg}" >&2
      echo "Run with --help to see available options." >&2
      exit 1
      ;;
  esac
done

echo "[dev-rebuild] Running make install-debug..."
make -C "${PROJECT_ROOT}" install-debug

if [[ ! -x "${APP_BIN}" ]]; then
  APP_ROOT="/Library/Input Methods/Squirrel.app"
  APP_BIN="${APP_ROOT}/Contents/MacOS/Squirrel"
  APP_SHARED_SUPPORT="${APP_ROOT}/Contents/SharedSupport"
fi

if [[ ! -x "${APP_BIN}" ]]; then
  echo "[dev-rebuild] App executable not found after install-debug." >&2
  echo "[dev-rebuild] Checked: /Library/Input Methods/SquirrelFlypy.app and /Library/Input Methods/Squirrel.app" >&2
  exit 1
fi

if [[ ${RUN_BUILD} -eq 1 ]]; then
  echo "[dev-rebuild] Running schema build..."
  (
    cd "${APP_SHARED_SUPPORT}"
    "${APP_BIN}" --build
  )
fi

if [[ ${RUN_RELOAD} -eq 1 ]]; then
  echo "[dev-rebuild] Triggering reload..."
  "${APP_BIN}" --reload
fi

echo "[dev-rebuild] Done."

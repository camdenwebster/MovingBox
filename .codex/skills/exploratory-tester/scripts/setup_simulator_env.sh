#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage:
  setup_simulator_env.sh [options]

Options:
  --udid <id>          Simulator UDID (default: 4DA6503A-88E2-4019-B404-EBBB222F3038)
  --repo-root <path>   Repo root used to resolve default image paths (default: git root)
  --run-root <path>    Optional run root for setup artifact logs
  --image <path>       Add custom image path (repeatable). If omitted, default set is used.
  --no-erase           Do not run `xcrun simctl erase all`
  --no-open            Do not open Simulator app window
  --help               Show this help
USAGE
}

UDID="4DA6503A-88E2-4019-B404-EBBB222F3038"
REPO_ROOT=""
RUN_ROOT=""
DO_ERASE=1
DO_OPEN=1
CUSTOM_IMAGES=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    --udid)
      UDID="${2:-}"
      shift 2
      ;;
    --repo-root)
      REPO_ROOT="${2:-}"
      shift 2
      ;;
    --run-root)
      RUN_ROOT="${2:-}"
      shift 2
      ;;
    --image)
      CUSTOM_IMAGES+=("${2:-}")
      shift 2
      ;;
    --no-erase)
      DO_ERASE=0
      shift
      ;;
    --no-open)
      DO_OPEN=0
      shift
      ;;
    --help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      usage
      exit 2
      ;;
  esac
done

if [[ -z "$REPO_ROOT" ]]; then
  if REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null)"; then
    :
  else
    REPO_ROOT="$(cd "$(dirname "$0")/../../../.." && pwd)"
  fi
fi

DEFAULT_IMAGES=(
  "$REPO_ROOT/MovingBox/TestAssets.xcassets/lamp-bedside.imageset/lamp-bedside.jpg"
  "$REPO_ROOT/MovingBox/TestAssets.xcassets/floor-lamp.imageset/floor-lamp.jpg"
  "$REPO_ROOT/MovingBox/TestAssets.xcassets/router-wifi.imageset/router-wifi.jpg"
  "$REPO_ROOT/MovingBox/TestAssets.xcassets/wireless-router.imageset/wireless-router.jpg"
  "$REPO_ROOT/MovingBox/TestAssets.xcassets/toolbox.imageset/toolbox.jpg"
)

if [[ ${#CUSTOM_IMAGES[@]} -gt 0 ]]; then
  IMAGES=("${CUSTOM_IMAGES[@]}")
else
  IMAGES=("${DEFAULT_IMAGES[@]}")
fi

VALID_IMAGES=()
for img in "${IMAGES[@]}"; do
  if [[ -f "$img" ]]; then
    VALID_IMAGES+=("$img")
  else
    echo "[warn] Missing image, skipping: $img" >&2
  fi
done

if [[ ${#VALID_IMAGES[@]} -eq 0 ]]; then
  echo "No valid images found to import." >&2
  exit 1
fi

if [[ $DO_ERASE -eq 1 ]]; then
  echo "[info] Erasing all simulators"
  xcrun simctl erase all
fi

echo "[info] Booting simulator: $UDID"
xcrun simctl boot "$UDID" || true

if [[ $DO_OPEN -eq 1 ]]; then
  echo "[info] Opening Simulator.app"
  open -a Simulator || true
fi

echo "[info] Importing ${#VALID_IMAGES[@]} photos"
xcrun simctl addmedia "$UDID" "${VALID_IMAGES[@]}"

if [[ -n "$RUN_ROOT" ]]; then
  mkdir -p "$RUN_ROOT/reports"
  {
    echo "timestamp=$(date -Iseconds)"
    echo "udid=$UDID"
    echo "erase_all=$DO_ERASE"
    echo "open_simulator=$DO_OPEN"
    echo "repo_root=$REPO_ROOT"
    echo "imported_images=${#VALID_IMAGES[@]}"
    printf 'image=%s\n' "${VALID_IMAGES[@]}"
  } > "$RUN_ROOT/reports/environment-setup.txt"
  echo "[info] Wrote setup report: $RUN_ROOT/reports/environment-setup.txt"
fi

echo "[ok] Simulator environment configured"

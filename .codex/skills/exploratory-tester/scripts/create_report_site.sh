#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage:
  create_report_site.sh --run-root <path> [options]

Required:
  --run-root <path>        Exploratory run root folder

Optional:
  --json <path>            JSON log (default: <run-root>/reports/test-results.json)
  --verdict-md <path>      Verdict markdown (default: <run-root>/reports/final-verdict.md)
  --defects-md <path>      Defects markdown (default: <run-root>/reports/defects.md)
  --findings-md <path>     Findings markdown (default: <run-root>/reports/findings.md)
  --screenshots <path>     Screenshots folder (default: <run-root>/screenshots)
  --output <path>          Site output folder (default: <run-root>/reports/site)
  --force                  Overwrite output folder if it exists
  --help                   Show this help
USAGE
}

RUN_ROOT=""
JSON_PATH=""
VERDICT_MD=""
DEFECTS_MD=""
FINDINGS_MD=""
SCREENSHOTS_DIR=""
OUTPUT_DIR=""
FORCE=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --run-root)
      RUN_ROOT="${2:-}"
      shift 2
      ;;
    --json)
      JSON_PATH="${2:-}"
      shift 2
      ;;
    --verdict-md)
      VERDICT_MD="${2:-}"
      shift 2
      ;;
    --defects-md)
      DEFECTS_MD="${2:-}"
      shift 2
      ;;
    --findings-md)
      FINDINGS_MD="${2:-}"
      shift 2
      ;;
    --screenshots)
      SCREENSHOTS_DIR="${2:-}"
      shift 2
      ;;
    --output)
      OUTPUT_DIR="${2:-}"
      shift 2
      ;;
    --force)
      FORCE=1
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

if [[ -z "$RUN_ROOT" ]]; then
  echo "--run-root is required" >&2
  usage
  exit 2
fi

if [[ ! -d "$RUN_ROOT" ]]; then
  echo "Run root does not exist: $RUN_ROOT" >&2
  exit 1
fi

if [[ -z "$JSON_PATH" ]]; then
  JSON_PATH="$RUN_ROOT/reports/test-results.json"
fi
if [[ -z "$VERDICT_MD" ]]; then
  VERDICT_MD="$RUN_ROOT/reports/final-verdict.md"
fi
if [[ -z "$DEFECTS_MD" ]]; then
  DEFECTS_MD="$RUN_ROOT/reports/defects.md"
fi
if [[ -z "$FINDINGS_MD" ]]; then
  FINDINGS_MD="$RUN_ROOT/reports/findings.md"
fi
if [[ -z "$SCREENSHOTS_DIR" ]]; then
  SCREENSHOTS_DIR="$RUN_ROOT/screenshots"
fi
if [[ -z "$OUTPUT_DIR" ]]; then
  OUTPUT_DIR="$RUN_ROOT/reports/site"
fi

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SKILL_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
TEMPLATE_DIR="$SKILL_DIR/templates/report-site"

if [[ ! -d "$TEMPLATE_DIR" ]]; then
  echo "Template directory missing: $TEMPLATE_DIR" >&2
  exit 1
fi

if [[ -d "$OUTPUT_DIR" && $FORCE -ne 1 ]]; then
  echo "Output already exists. Use --force to overwrite: $OUTPUT_DIR" >&2
  exit 1
fi

rm -rf "$OUTPUT_DIR"
mkdir -p "$OUTPUT_DIR/data"

cp "$TEMPLATE_DIR/index.html" "$OUTPUT_DIR/index.html"
cp "$TEMPLATE_DIR/styles.css" "$OUTPUT_DIR/styles.css"
cp "$TEMPLATE_DIR/report.js" "$OUTPUT_DIR/report.js"

copy_optional_file() {
  local src="$1"
  local dest="$2"
  if [[ -f "$src" ]]; then
    cp "$src" "$dest"
    echo "[info] Copied: $src -> $dest"
  else
    echo "[warn] Missing optional file: $src"
  fi
}

copy_optional_file "$JSON_PATH" "$OUTPUT_DIR/data/test-results.json"
copy_optional_file "$VERDICT_MD" "$OUTPUT_DIR/data/final-verdict.md"
copy_optional_file "$DEFECTS_MD" "$OUTPUT_DIR/data/defects.md"
copy_optional_file "$FINDINGS_MD" "$OUTPUT_DIR/data/findings.md"

if [[ -d "$SCREENSHOTS_DIR" ]]; then
  cp -R "$SCREENSHOTS_DIR" "$OUTPUT_DIR/screenshots"
  echo "[info] Copied screenshots: $SCREENSHOTS_DIR -> $OUTPUT_DIR/screenshots"
else
  echo "[warn] Missing screenshots directory: $SCREENSHOTS_DIR"
fi

{
  echo "generated_at=$(date -Iseconds)"
  echo "run_root=$RUN_ROOT"
  echo "json_path=$JSON_PATH"
  echo "verdict_md=$VERDICT_MD"
  echo "defects_md=$DEFECTS_MD"
  echo "findings_md=$FINDINGS_MD"
  echo "screenshots_dir=$SCREENSHOTS_DIR"
} > "$OUTPUT_DIR/data/manifest.txt"

echo "[ok] Exploratory report site generated: $OUTPUT_DIR/index.html"
echo "[tip] Serve locally: cd \"$OUTPUT_DIR\" && python3 -m http.server 4173"

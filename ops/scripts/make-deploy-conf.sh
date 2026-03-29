#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
OUTPUT_PATH="${REPO_ROOT}/deploy.conf"

usage() {
  cat <<'USAGE'
Usage:
  bash ops/scripts/make-deploy-conf.sh [--output <path>] [--force]

Options:
  --output <path>   Output file path (default: ./deploy.conf)
  --force           Overwrite without confirmation
USAGE
}

FORCE=false
while [ $# -gt 0 ]; do
  case "$1" in
    --output)
      OUTPUT_PATH="$2"
      shift 2
      ;;
    --force)
      FORCE=true
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      usage
      exit 1
      ;;
  esac
done

if [ -f "$OUTPUT_PATH" ] && [ "$FORCE" != "true" ]; then
  read -r -p "${OUTPUT_PATH} already exists. Overwrite? (y/N): " ans
  case "$ans" in
    y|Y|yes|YES) ;;
    *)
      echo "Aborted."
      exit 1
      ;;
  esac
fi

read -r -p "ADO_ORG: " ADO_ORG
read -r -p "ADO_PROJECT: " ADO_PROJECT
read -r -p "ADO_PIPELINE_ID: " ADO_PIPELINE_ID
read -r -s -p "ADO_PAT (input hidden): " ADO_PAT
echo
read -r -p "ADO_BRANCH [refs/heads/main]: " ADO_BRANCH

if [ -z "$ADO_ORG" ] || [ -z "$ADO_PROJECT" ] || [ -z "$ADO_PIPELINE_ID" ] || [ -z "$ADO_PAT" ]; then
  echo "ERROR: ADO_ORG, ADO_PROJECT, ADO_PIPELINE_ID, ADO_PAT are required." >&2
  exit 1
fi

ADO_BRANCH="${ADO_BRANCH:-refs/heads/main}"

cat > "$OUTPUT_PATH" <<EOF
ADO_ORG="${ADO_ORG}"
ADO_PROJECT="${ADO_PROJECT}"
ADO_PIPELINE_ID="${ADO_PIPELINE_ID}"
ADO_PAT="${ADO_PAT}"
ADO_BRANCH="${ADO_BRANCH}"
EOF

chmod 600 "$OUTPUT_PATH"

echo "Created: $OUTPUT_PATH"
echo "Permission: 600"
echo "Next: bash deploy.sh"

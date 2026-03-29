#!/usr/bin/env bash
set -euo pipefail

# Usage:
#   cp ops/scripts/deploy.conf.example ./deploy.conf
#   # edit ./deploy.conf
#   bash ops/scripts/deploy.sh

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

# Auto-load deploy.conf from repo root first, then script folder fallback.
if [ -f "${REPO_ROOT}/deploy.conf" ]; then
  # shellcheck disable=SC1091
  source "${REPO_ROOT}/deploy.conf"
elif [ -f "${SCRIPT_DIR}/deploy.conf" ]; then
  # shellcheck disable=SC1091
  source "${SCRIPT_DIR}/deploy.conf"
fi

if [ -z "${ADO_ORG:-}" ] || [ -z "${ADO_PROJECT:-}" ] || [ -z "${ADO_PIPELINE_ID:-}" ] || [ -z "${ADO_PAT:-}" ]; then
  echo "ERROR: required config values are missing."
  echo "Required: ADO_ORG, ADO_PROJECT, ADO_PIPELINE_ID, ADO_PAT"
  echo "Create deploy.conf from ops/scripts/deploy.conf.example"
  exit 1
fi

ADO_BRANCH="${ADO_BRANCH:-refs/heads/main}"
API_URL="https://dev.azure.com/${ADO_ORG}/${ADO_PROJECT}/_apis/pipelines/${ADO_PIPELINE_ID}/runs?api-version=7.0"
TMP_BODY="$(mktemp)"
trap 'rm -f "$TMP_BODY"' EXIT

echo "[INFO] Requesting deployment run..."

HTTP_STATUS="$(curl -sS -o "$TMP_BODY" -w "%{http_code}" -u ":${ADO_PAT}" -X POST \
  -H "Content-Type: application/json" \
  -d "{\"resources\":{\"repositories\":{\"self\":{\"refName\":\"${ADO_BRANCH}\"}}}}" \
  "${API_URL}")"

RESPONSE="$(cat "$TMP_BODY")"

if [ "$HTTP_STATUS" -lt 200 ] || [ "$HTTP_STATUS" -ge 300 ]; then
  echo "[ERROR] API request failed. HTTP status: ${HTTP_STATUS}" >&2
  echo "$RESPONSE" >&2
  exit 1
fi

RUN_ID="$(printf '%s' "$RESPONSE" | sed -n 's/.*"id"[[:space:]]*:[[:space:]]*\([0-9][0-9]*\).*/\1/p' | head -n1)"
RUN_WEB_URL="https://dev.azure.com/${ADO_ORG}/${ADO_PROJECT}/_build/results?buildId=${RUN_ID}&view=results"

if [ -z "$RUN_ID" ]; then
  echo "[ERROR] failed to parse run id from successful response. raw response:" >&2
  echo "$RESPONSE" >&2
  exit 1
fi

echo "[DONE] Deployment requested."
echo "Run ID: ${RUN_ID}"
echo "Run URL: ${RUN_WEB_URL}"

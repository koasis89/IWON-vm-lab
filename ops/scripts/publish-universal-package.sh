#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

usage() {
  cat <<'USAGE'
Usage:
  bash ops/scripts/publish-universal-package.sh [options]

Options:
  --version <semver>          Explicit package version. If omitted, auto-generated.
  --base-version <X.Y.Z>      Base version used for auto version tag (default: YYYY.M.D).
  --feed <name>               Feed name override
  --name <package-name>       Universal package name override
  --config <path>             Config file path (default: ops/scripts/artifacts.conf)
  --notes-count <N>           Commit count fallback for release notes (default: 20)
  --notes-range <git-range>   Explicit git log range (e.g. v1.2.3..HEAD)
  --no-source-deploy-conf     Do not source deploy.conf for ADO_ORG/ADO_PROJECT/ADO_PAT fallback
  -h, --help                  Show help

Required env/config values:
  ADO_ORG, ADO_PROJECT, ADO_PAT
USAGE
}

DEFAULTS_PATH="${SCRIPT_DIR}/ops-defaults.env"
CONFIG_PATH="${SCRIPT_DIR}/artifacts.conf"
SOURCE_DEPLOY_CONF=true
INPUT_VERSION=""
BASE_VERSION=""
NOTES_COUNT="20"
NOTES_RANGE=""

while [ $# -gt 0 ]; do
  case "$1" in
    --version)
      INPUT_VERSION="$2"
      shift 2
      ;;
    --base-version)
      BASE_VERSION="$2"
      shift 2
      ;;
    --feed)
      INPUT_FEED_NAME="$2"
      shift 2
      ;;
    --name)
      INPUT_PACKAGE_NAME="$2"
      shift 2
      ;;
    --config)
      CONFIG_PATH="$2"
      shift 2
      ;;
    --notes-count)
      NOTES_COUNT="$2"
      shift 2
      ;;
    --notes-range)
      NOTES_RANGE="$2"
      shift 2
      ;;
    --no-source-deploy-conf)
      SOURCE_DEPLOY_CONF=false
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

if [ -f "$DEFAULTS_PATH" ]; then
  # shellcheck disable=SC1090
  source "$DEFAULTS_PATH"
fi

if [ -f "$CONFIG_PATH" ]; then
  # shellcheck disable=SC1090
  source "$CONFIG_PATH"
fi

if [ "$SOURCE_DEPLOY_CONF" = true ] && [ -f "${REPO_ROOT}/deploy.conf" ]; then
  # shellcheck disable=SC1091
  source "${REPO_ROOT}/deploy.conf"
fi

ADO_ORG="${ADO_ORG:-}"
ADO_PROJECT="${ADO_PROJECT:-}"
ADO_PAT="${ADO_PAT:-}"
ARTIFACT_FEED_NAME="${INPUT_FEED_NAME:-${ARTIFACT_FEED_NAME:-${OPS_DEFAULT_ARTIFACT_FEED_NAME:-ITEYES-Packages}}}"
UNIVERSAL_PACKAGE_NAME="${INPUT_PACKAGE_NAME:-${UNIVERSAL_PACKAGE_NAME:-${OPS_DEFAULT_UNIVERSAL_PACKAGE_NAME:-iwon-ops-bundle}}}"

if [ -z "$ADO_ORG" ] || [ -z "$ADO_PROJECT" ] || [ -z "$ADO_PAT" ]; then
  echo "ERROR: ADO_ORG, ADO_PROJECT, ADO_PAT are required." >&2
  echo "Tip: set ops/scripts/artifacts.conf or deploy.conf" >&2
  exit 1
fi

if ! command -v az >/dev/null 2>&1; then
  echo "ERROR: az CLI is required." >&2
  exit 1
fi

if ! az extension show --name azure-devops >/dev/null 2>&1; then
  az extension add --name azure-devops --yes >/dev/null
fi

if ! command -v git >/dev/null 2>&1; then
  GIT_SHA="manual"
else
  GIT_SHA="$(git -C "$REPO_ROOT" rev-parse --short HEAD 2>/dev/null || echo manual)"
fi

DATE_BASE="$(date +%Y.%-m.%-d)"
BASE_VERSION="${BASE_VERSION:-$DATE_BASE}"
DEFAULT_VERSION="${OPS_DEFAULT_UNIVERSAL_PACKAGE_VERSION:-${BASE_VERSION}-${GIT_SHA}}"
VERSION_TAG="${INPUT_VERSION:-$DEFAULT_VERSION}"

SEMVER_REGEX='^(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)(-[0-9A-Za-z.-]+)?(\+[0-9A-Za-z.-]+)?$'
if ! printf '%s' "$VERSION_TAG" | grep -Eq "$SEMVER_REGEX"; then
  echo "ERROR: invalid semver version '$VERSION_TAG'" >&2
  exit 1
fi

WEB_SRC="${REPO_ROOT}/release/web/html.zip"
WAS_SRC="${REPO_ROOT}/release/was/app.jar"
APP_SRC="${REPO_ROOT}/release/app/app.jar"
INTEGRATION_SRC="${REPO_ROOT}/release/integration/app.jar"

for f in "$WEB_SRC" "$WAS_SRC" "$APP_SRC" "$INTEGRATION_SRC"; do
  if [ ! -f "$f" ]; then
    echo "ERROR: artifact source not found: $f" >&2
    exit 1
  fi
done

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

mkdir -p "$TMP_DIR/web" "$TMP_DIR/was" "$TMP_DIR/app" "$TMP_DIR/integration"
cp "$WEB_SRC" "$TMP_DIR/web/html.zip"
cp "$WAS_SRC" "$TMP_DIR/was/app.jar"
cp "$APP_SRC" "$TMP_DIR/app/app.jar"
cp "$INTEGRATION_SRC" "$TMP_DIR/integration/app.jar"

RELEASE_NOTES_DIR="${REPO_ROOT}/release/notes"
mkdir -p "$RELEASE_NOTES_DIR"
SAFE_VERSION="$(printf '%s' "$VERSION_TAG" | tr '/ ' '__')"
RELEASE_NOTES_FILE="${RELEASE_NOTES_DIR}/universal-${SAFE_VERSION}.md"

write_release_notes() {
  local range="$1"
  {
    echo "# Release Notes - ${UNIVERSAL_PACKAGE_NAME} ${VERSION_TAG}"
    echo
    echo "- generatedAt: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
    echo "- commit: ${GIT_SHA}"
    echo
    echo "## Commits"
  } > "$RELEASE_NOTES_FILE"

  if [ -n "$range" ]; then
    git -C "$REPO_ROOT" log "$range" --pretty=format:'- %h %ad %an %s' --date=short >> "$RELEASE_NOTES_FILE" || true
  else
    git -C "$REPO_ROOT" log -n "$NOTES_COUNT" --pretty=format:'- %h %ad %an %s' --date=short >> "$RELEASE_NOTES_FILE" || true
  fi

  if [ ! -s "$RELEASE_NOTES_FILE" ] || ! grep -q '^- ' "$RELEASE_NOTES_FILE"; then
    {
      echo
      echo "- (no commit log available)"
    } >> "$RELEASE_NOTES_FILE"
  fi
}

if command -v git >/dev/null 2>&1 && git -C "$REPO_ROOT" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  if [ -n "$NOTES_RANGE" ]; then
    write_release_notes "$NOTES_RANGE"
  else
    LAST_TAG="$(git -C "$REPO_ROOT" describe --tags --abbrev=0 2>/dev/null || true)"
    if [ -n "$LAST_TAG" ]; then
      write_release_notes "${LAST_TAG}..HEAD"
    else
      write_release_notes ""
    fi
  fi
else
  {
    echo "# Release Notes - ${UNIVERSAL_PACKAGE_NAME} ${VERSION_TAG}"
    echo
    echo "- generatedAt: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
    echo
    echo "## Commits"
    echo "- (git metadata not available)"
  } > "$RELEASE_NOTES_FILE"
fi

cp "$RELEASE_NOTES_FILE" "$TMP_DIR/release-notes.md"

export AZURE_DEVOPS_EXT_PAT="$ADO_PAT"
ORG_URL="https://dev.azure.com/${ADO_ORG}"

echo "[INFO] Publishing Universal Package"
echo "[INFO] org=${ADO_ORG} project=${ADO_PROJECT} feed=${ARTIFACT_FEED_NAME} name=${UNIVERSAL_PACKAGE_NAME} version=${VERSION_TAG}"
echo "[INFO] release notes: ${RELEASE_NOTES_FILE}"

az artifacts universal publish \
  --organization "$ORG_URL" \
  --project "$ADO_PROJECT" \
  --scope project \
  --feed "$ARTIFACT_FEED_NAME" \
  --name "$UNIVERSAL_PACKAGE_NAME" \
  --version "$VERSION_TAG" \
  --path "$TMP_DIR" \
  --description "iwon feed-only bundle ${VERSION_TAG}"

echo "[DONE] Universal package published."
echo "Package: ${UNIVERSAL_PACKAGE_NAME}"
echo "Version: ${VERSION_TAG}"
echo "Release Notes: ${RELEASE_NOTES_FILE}"

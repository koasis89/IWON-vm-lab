#!/usr/bin/env bash
set -euo pipefail

SQL_FILE="${1:-/opt/vm-lab/backup/db/all.sql}"
DB_NAME="${2:-appdb}"
TARGET_UTF8MB3_COLLATION="${3:-utf8mb3_general_ci}"
TARGET_UTF8MB4_COLLATION="${4:-utf8mb4_general_ci}"

if [[ ! -f "$SQL_FILE" ]]; then
  echo "SQL file not found: $SQL_FILE" >&2
  exit 1
fi

case "$TARGET_UTF8MB3_COLLATION" in
  utf8mb3_*|utf8_*) ;;
  *)
    echo "Unsupported utf8mb3 target collation: $TARGET_UTF8MB3_COLLATION" >&2
    echo "Use a utf8mb3_* or utf8_* collation." >&2
    exit 1
    ;;
esac

case "$TARGET_UTF8MB4_COLLATION" in
  utf8mb4_*|uca1400_*)
    ;;
  *)
    echo "Unsupported utf8mb4 target collation: $TARGET_UTF8MB4_COLLATION" >&2
    echo "Use a utf8mb4_* or uca1400_* collation." >&2
    exit 1
    ;;
esac

BACKUP_FILE="${SQL_FILE}.bak"
TMP_UTF8MB3_FILE="$(mktemp)"
TMP_UTF8MB4_FILE="$(mktemp)"
trap 'rm -f "$TMP_UTF8MB3_FILE" "$TMP_UTF8MB4_FILE"' EXIT

echo "[1/6] Current MariaDB version"
mariadb --version || true
sudo mariadb -e "SELECT VERSION();" || true

echo
echo "[2/6] Collation scan"
grep -n "uca1400" "$SQL_FILE" | head || true
grep -oE "utf8(mb3|mb4)?_[A-Za-z0-9_]+_ci|utf8(mb3|mb4)?_[A-Za-z0-9_]+_bin|utf8(mb3|mb4)?" "$SQL_FILE" | sort -u || true

grep -oE "utf8mb3_uca1400_[A-Za-z0-9_]+" "$SQL_FILE" | sort -u > "$TMP_UTF8MB3_FILE" || true
grep -oE "utf8mb4_uca1400_[A-Za-z0-9_]+" "$SQL_FILE" | sort -u > "$TMP_UTF8MB4_FILE" || true

if [[ ! -s "$TMP_UTF8MB3_FILE" && ! -s "$TMP_UTF8MB4_FILE" ]]; then
  echo
  echo "No utf8mb3/utf8mb4 uca1400-based collations found. Nothing to replace."
  exit 0
fi

echo
echo "[3/6] Unsupported collations detected"
cat "$TMP_UTF8MB3_FILE" 2>/dev/null || true
cat "$TMP_UTF8MB4_FILE" 2>/dev/null || true

if [[ ! -f "$BACKUP_FILE" ]]; then
  cp "$SQL_FILE" "$BACKUP_FILE"
  echo
  echo "Backup created: $BACKUP_FILE"
else
  echo
  echo "Backup already exists, keeping: $BACKUP_FILE"
fi

echo
echo "[4/6] Replacing detected collations"
echo "  utf8mb3_* -> $TARGET_UTF8MB3_COLLATION"
echo "  utf8mb4_* -> $TARGET_UTF8MB4_COLLATION"

while IFS= read -r collation; do
  [[ -z "$collation" ]] && continue
  sed -i "s/${collation}/${TARGET_UTF8MB3_COLLATION}/g" "$SQL_FILE"
done < "$TMP_UTF8MB3_FILE"

while IFS= read -r collation; do
  [[ -z "$collation" ]] && continue
  sed -i "s/${collation}/${TARGET_UTF8MB4_COLLATION}/g" "$SQL_FILE"
done < "$TMP_UTF8MB4_FILE"

echo
echo "[5/6] Recreating database: $DB_NAME"
sudo mariadb -e "DROP DATABASE IF EXISTS \`${DB_NAME}\`;"
sudo mariadb -e "CREATE DATABASE \`${DB_NAME}\` CHARACTER SET utf8mb4 COLLATE ${TARGET_UTF8MB4_COLLATION};"

echo
echo "[6/6] Importing SQL"
sudo mariadb "$DB_NAME" < "$SQL_FILE"

echo
echo "Import completed."
echo "Database: $DB_NAME"
echo "SQL file: $SQL_FILE"
echo "utf8mb3 target collation: $TARGET_UTF8MB3_COLLATION"
echo "utf8mb4 target collation: $TARGET_UTF8MB4_COLLATION"

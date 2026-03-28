#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="/mnt/c/Workspace/k8s-lab-dabin"
SQL_FILE="${ROOT_DIR}/backup/db/all.sql"
ANSIBLE_DIR="${ROOT_DIR}/vm-ansible"

echo "== Dump file lookup =="
for table in GPCL_USR_LOGIN GPCL_USR GPCL_USR_GRP GPCL_MSG_CD GPCL_CM_CD_VAL; do
  echo "-- ${table}"
  grep -nE "CREATE TABLE.*${table}|INSERT INTO.*${table}" "$SQL_FILE" | head -n 5 || true
done
echo

echo "== Current DB schema on db01 =="
cd "$ANSIBLE_DIR"
ANSIBLE_CONFIG=ansible.cfg ansible db -i inventory.ini -m shell -a "mariadb -u appuser -p'<APP_DB_PASSWORD>' appdb -Nse \"SELECT COUNT(*) AS table_count FROM information_schema.tables WHERE table_schema='appdb'; SHOW TABLES LIKE 'GPCL%'; SHOW TABLES LIKE 'TB_%';\"" -b
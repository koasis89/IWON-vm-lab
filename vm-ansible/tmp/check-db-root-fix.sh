#!/usr/bin/env bash
set -euo pipefail

cd /mnt/c/Workspace/k8s-lab-dabin/vm-ansible

echo "[check] lower_case_table_names"
ansible db -i inventory.ini -m shell -a "mariadb -h 127.0.0.1 -u root -p'<ROOT_DB_PASSWORD>' -Nse \"SHOW VARIABLES LIKE 'lower_case_table_names'\"" --become

echo "[check] uppercase table count in appdb"
ansible db -i inventory.ini -m shell -a "mariadb -h 127.0.0.1 -u root -p'<ROOT_DB_PASSWORD>' -Nse \"SELECT COUNT(*) FROM information_schema.TABLES WHERE TABLE_SCHEMA='appdb' AND BINARY TABLE_NAME REGEXP '[A-Z]'\"" --become

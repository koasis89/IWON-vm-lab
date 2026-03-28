#!/usr/bin/env bash
set -euo pipefail

cd /mnt/c/Workspace/k8s-lab-dabin/vm-ansible
ANSIBLE_CONFIG=ansible.cfg ansible db -i inventory.ini -m shell -a "mariadb -u appuser -p'<APP_DB_PASSWORD>' appdb -Nse \"SHOW VARIABLES LIKE 'lower_case_table_names'; SHOW TABLES LIKE 'gpcl_%'; SHOW TABLES LIKE 'GPCL_%';\"" -b
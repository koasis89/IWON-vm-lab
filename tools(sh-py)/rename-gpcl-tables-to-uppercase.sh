#!/usr/bin/env bash
set -euo pipefail

cd /mnt/c/Workspace/k8s-lab-dabin/vm-ansible

ANSIBLE_CONFIG=ansible.cfg ansible db -i inventory.ini -m shell -a '
python3 - <<"PY"
import subprocess

db = "appdb"
user = "appuser"
password = "<APP_DB_PASSWORD>"

def query(sql: str):
    cmd = [
        "mariadb",
        f"-u{user}",
        f"-p{password}",
        db,
        "-Nse",
        sql,
    ]
    result = subprocess.run(cmd, capture_output=True, text=True, check=True)
    return [line.strip() for line in result.stdout.splitlines() if line.strip()]

tables = query("SHOW TABLES LIKE 'gpcl_%'")
print(f"FOUND={len(tables)}")

for table in tables:
    upper_name = table.upper()
    if table == upper_name:
        print(f"SKIP={table}")
        continue
    sql = f"RENAME TABLE `{table}` TO `{upper_name}`;"
    subprocess.run([
        "mariadb",
        f"-u{user}",
        f"-p{password}",
        db,
        "-e",
        sql,
    ], check=True)
    print(f"RENAMED={table}->{upper_name}")

print("DONE")
PY' -b
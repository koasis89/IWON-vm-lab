#!/usr/bin/env bash
set -euo pipefail

cd /mnt/c/Workspace/k8s-lab-dabin/vm-ansible
ANSIBLE_CONFIG=ansible.cfg ansible was -i inventory.ini -m shell -a 'python3 - <<"PY"
from pathlib import Path
log = Path("/var/log/iwon/was.log")
lines = log.read_text(errors="ignore").splitlines()
keys = [
    "/api/iwon/iwoncoin00m/supply",
    "/api/iwon/iwoncoin00m/onoffchain-diffs",
    "IWONCOIN00M",
    "Exception",
    "ERROR",
]
for idx, line in enumerate(lines):
    if any(key in line for key in keys):
        print("=====")
        for row in lines[max(0, idx - 5): min(len(lines), idx + 15)]:
            print(row)
PY' -b
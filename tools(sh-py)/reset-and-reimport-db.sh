#!/usr/bin/env bash
set -euo pipefail

cd /mnt/c/Workspace/k8s-lab-dabin/vm-ansible

echo "[step] drop/recreate appdb and clear import marker"
ansible db -i inventory.ini -m shell -a "mariadb -h 127.0.0.1 -u root -p'<ROOT_DB_PASSWORD>' -e \"DROP DATABASE IF EXISTS appdb; CREATE DATABASE appdb;\" && rm -f /opt/vm-lab/.appdb_imported" --become

echo "[step] run db play to import normalized all.sql"
ansible-playbook -i inventory.ini site.yml --limit db

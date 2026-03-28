#!/usr/bin/env bash
# NFS mount setup for Azure Files Premium FileStorage
set -euo pipefail

cd /mnt/c/Workspace/k8s-lab-dabin/vm-ansible

echo "[$(date '+%Y-%m-%d %H:%M:%S')] === NFS Mount Setup Start ==="

# 1. Syntax Check
echo "[1] Ansible syntax check..."
ansible-playbook -i inventory.ini nfs-only.yml --syntax-check 2>&1 | tail -5

# 2. Deploy NFS mounts to was, app, integration
echo ""
echo "[2] Deploy NFS mount configs to was, app, smartcontract01..."
ansible-playbook -i inventory.ini nfs-only.yml 2>&1 | tail -20

# 3. Verify mounts
echo ""
echo "[3] Verify NFS mounts..."
echo "--- was01 ---"
ansible was -i inventory.ini -m shell -a "mount | grep /mnt/shared || echo MOUNT_NOT_FOUND" 2>&1 | grep -E "(was01|/mnt|MOUNT)"

echo "--- app01 ---"
ansible app -i inventory.ini -m shell -a "mount | grep /mnt/shared || echo MOUNT_NOT_FOUND" 2>&1 | grep -E "(app01|/mnt|MOUNT)"

echo "--- smartcontract01 (integration) ---"
ansible integration -i inventory.ini -m shell -a "mount | grep /mnt/shared || echo MOUNT_NOT_FOUND" 2>&1 | grep -E "(smart|/mnt|MOUNT)"

# 4. Check disk space
echo ""
echo "[4] Check mounted filesystem usage..."
ansible app_vms -i inventory.ini -m shell -a "df -h /mnt/shared 2>/dev/null || echo FS_NOT_MOUNTED" 2>&1 | grep -E "(Filesystem|Mounted|app01|was01|smart)"

# 5. Check fstab entries
echo ""
echo "[5] Check /etc/fstab for NFS entries..."
ansible app_vms -i inventory.ini -m shell -a "grep '/mnt/shared' /etc/fstab || echo FSTAB_ENTRY_NOT_FOUND" 2>&1 | grep -E "(was01|app01|smart|file.core.windows.net|aznfs|FSTAB)"

echo ""
echo "[$(date '+%Y-%m-%d %H:%M:%S')] === NFS Mount Setup Complete ==="

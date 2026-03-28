#!/usr/bin/env bash
# NFS mount diagnostics
set -euo pipefail

echo "=== NFS Mount Diagnostics ==="
echo ""

# Check nfs-utils installation
echo "[1] Check nfs utilities..."
ansible app_vms -i /mnt/c/Workspace/k8s-lab-dabin/vm-ansible/inventory.ini -m shell -a "which mount.nfs4; dpkg -l | grep -E 'aznfs|nfs-common' || true" 2>&1 | grep -E "(was01|app01|smart|mount.nfs|aznfs|nfs-common)" || true

echo ""
echo "[2] Check fstab entries..."
ansible app_vms -i /mnt/c/Workspace/k8s-lab-dabin/vm-ansible/inventory.ini -m shell -a "cat /etc/fstab | grep -E '(shared|nfs)' || echo NO_NFS_FSTAB" 2>&1 | grep -E "(was01|app01|smart|shared|nfs)" || true

echo ""
echo "[3] Check DNS resolution for NFS host..."
ansible app_vms -i /mnt/c/Workspace/k8s-lab-dabin/vm-ansible/inventory.ini -m shell -a "nslookup iwonsfskrciwonsvcrg01.file.core.windows.net || host iwonsfskrciwonsvcrg01.file.core.windows.net || echo DNS_RESOLUTION_FAILED" 2>&1 | grep -E "(was01|app01|smart|Address|Name)" || true

echo ""
echo "[4] Test connectivity to NFS host (raw socket)..."
ansible app_vms -i /mnt/c/Workspace/k8s-lab-dabin/vm-ansible/inventory.ini -m shell -a "nc -zv iwonsfskrciwonsvcrg01.file.core.windows.net 2049 || echo PORT_2049_NOT_OPEN" 2>&1 | grep -E "(was01|app01|smart|succeeded|not_open)" || true

echo ""
echo "[5] Try manual NFS mount..."
ansible was -i /mnt/c/Workspace/k8s-lab-dabin/vm-ansible/inventory.ini -b -m shell -a "mkdir -p /mnt/test_mount && umount /mnt/test_mount >/dev/null 2>&1 || true; mount -t aznfs -o vers=4,minorversion=1,sec=sys,nconnect=4 iwonsfskrciwonsvcrg01.file.core.windows.net:/iwonsfskrciwonsvcrg01/shared /mnt/test_mount 2>&1 || echo MOUNT_FAILED" 2>&1 | grep -E "(was01|succeeded|FAILED|MOUNT_FAILED)" || true

echo ""
echo "=== Diagnostics Complete ==="

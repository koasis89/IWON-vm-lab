#!/usr/bin/env bash
# NFS 연결성 실서버 진단 스크립트
# 대상: was01, app01, smartcontract01
# 실행 위치: Bastion을 통한 원격 실행

set -euo pipefail

BASTION_HOST="${BASTION_HOST:-20.214.224.224}"
BASTION_USER="${BASTION_USER:-iwon}"
WAS_HOST="${WAS_HOST:-10.0.2.20}"
APP_HOST="${APP_HOST:-10.0.2.30}"
SMART_HOST="${SMART_HOST:-10.0.2.40}"

NFS_STORAGE_ACCOUNT="iwonsfskrciwonsvcrg01"
NFS_FQDN="${NFS_STORAGE_ACCOUNT}.file.core.windows.net"
NFS_PORT="2049"
NFS_SHARE="/shared"

echo "========================================"
echo "NFS 연결성 진단 - 실서버 테스트"
echo "========================================"
echo ""

# 원격 실행 함수
ssh_via_bastion() {
  local target_host="$1"
  shift
  ssh -o StrictHostKeyChecking=no "${BASTION_USER}@${BASTION_HOST}" \
    "ssh -o StrictHostKeyChecking=no ${BASTION_USER}@${target_host} '$*'"
}

# "Step 1: was01 진단"
echo "[1] was01 (10.0.2.20) 진단"
echo "===================================="

echo "[1-1] DNS 해석"
ssh_via_bastion "$WAS_HOST" "nslookup ${NFS_FQDN} 2>&1 | head -10" || echo "NSLOOKUP_FAILED"

echo ""
echo "[1-2] NFS 포트 연결 (포트 2049)"
ssh_via_bastion "$WAS_HOST" "nc -zv ${NFS_FQDN} ${NFS_PORT} 2>&1 || echo PORT_CONNECT_FAILED" || echo "NC_COMMAND_FAILED"

echo ""
echo "[1-3] NFS 서버 공유 목록"
ssh_via_bastion "$WAS_HOST" "showmount -e ${NFS_FQDN} 2>&1 || echo SHOWMOUNT_FAILED" || echo "SHOWMOUNT_COMMAND_FAILED"

echo ""
echo "[1-4] /etc/fstab 확인"
ssh_via_bastion "$WAS_HOST" "grep -E '(shared|nfs)' /etc/fstab || echo NO_NFS_ENTRY" || echo "GREP_FAILED"

echo ""
echo "[1-5] 현재 마운트 상태"
ssh_via_bastion "$WAS_HOST" "mount | grep /mnt/shared || echo NOT_MOUNTED" || echo "MOUNT_CHECK_FAILED"

echo ""
echo "[1-6] nfs-utils 설치 상태"
ssh_via_bastion "$WAS_HOST" "dpkg -l | grep -E 'aznfs|nfs-common' || echo NFS_UTILS_NOT_INSTALLED" || echo "DPKG_CHECK_FAILED"

echo ""
echo "[1-7] 네트워크 인터페이스"
ssh_via_bastion "$WAS_HOST" "ip addr show | grep -E '(inet|eth0|ens)' | head -5" || echo "IP_ADDR_FAILED"

# Step 2: app01 진단
echo ""
echo ""
echo "[2] app01 (10.0.2.30) 진단"
echo "===================================="

echo "[2-1] DNS 해석"
ssh_via_bastion "$APP_HOST" "nslookup ${NFS_FQDN} 2>&1 | head -10" || echo "NSLOOKUP_FAILED"

echo ""
echo "[2-2] NFS 포트 연결"
ssh_via_bastion "$APP_HOST" "nc -zv ${NFS_FQDN} ${NFS_PORT} 2>&1 || echo PORT_CONNECT_FAILED" || echo "NC_COMMAND_FAILED"

echo ""
echo "[2-3] 현재 마운트 상태"
ssh_via_bastion "$APP_HOST" "mount | grep /mnt/shared || echo NOT_MOUNTED" || echo "MOUNT_CHECK_FAILED"

# Step 3: smartcontract01 진단
echo ""
echo ""
echo "[3] smartcontract01 (10.0.2.40) 진단"
echo "===================================="

echo "[3-1] DNS 해석"
ssh_via_bastion "$SMART_HOST" "nslookup ${NFS_FQDN} 2>&1 | head -10" || echo "NSLOOKUP_FAILED"

echo ""
echo "[3-2] NFS 포트 연결"
ssh_via_bastion "$SMART_HOST" "nc -zv ${NFS_FQDN} ${NFS_PORT} 2>&1 || echo PORT_CONNECT_FAILED" || echo "NC_COMMAND_FAILED"

echo ""
echo "[3-3] 현재 마운트 상태"
ssh_via_bastion "$SMART_HOST" "mount | grep /mnt/shared || echo NOT_MOUNTED" || echo "MOUNT_CHECK_FAILED"

# Step 4: 종합 진단
echo ""
echo ""
echo "[4] 종합 진단 결과"
echo "===================================="

echo "NFS 스토리지 계정: ${NFS_STORAGE_ACCOUNT}"
echo "FQDN: ${NFS_FQDN}"
echo "NFS 포트: ${NFS_PORT}"
echo "NFS 공유: ${NFS_SHARE}"
echo ""
echo "예상 마운트 경로: ${NFS_FQDN}:${NFS_SHARE}"
echo "로컬 마운트 포인트: /mnt/shared"

echo ""
echo "========================================"
echo "진단 완료"
echo "========================================"

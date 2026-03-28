#!/usr/bin/env bash
# Step 5 검증 스크립트 - DB 정책 및 스키마 규칙, Smoke test
set -euo pipefail

cd /mnt/c/Workspace/k8s-lab-dabin/vm-ansible

ANSIBLE="ansible db -i inventory.ini"
DB_CMD="mariadb -h 127.0.0.1 -u root -p'<ROOT_DB_PASSWORD>' "

echo "=============================="
echo "[1] SHOW VARIABLES LIKE 'lower_case_table_names'"
echo "=============================="
${ANSIBLE} -m shell -a "${DB_CMD} -Nse \"SHOW VARIABLES LIKE 'lower_case_table_names'\"" --become 2>&1 | grep -Ev "^(\[WARNING\]|^$)" || true

echo ""
echo "=============================="
echo "[2] appdb 내 대문자 포함 테이블 수 (기대: 0)"
echo "=============================="
${ANSIBLE} -m shell -a "${DB_CMD} appdb -Nse \"SELECT COUNT(*) FROM information_schema.TABLES WHERE TABLE_SCHEMA='appdb' AND BINARY TABLE_NAME REGEXP '[A-Z]'\"" --become 2>&1 | grep -Ev "^(\[WARNING\]|^$)" || true

echo ""
echo "=============================="
echo "[3] appdb SHOW TABLES (소문자 규칙 확인 - 샘플 10개)"
echo "=============================="
${ANSIBLE} -m shell -a "${DB_CMD} appdb -Nse \"SELECT TABLE_NAME FROM information_schema.TABLES WHERE TABLE_SCHEMA='appdb' ORDER BY TABLE_NAME LIMIT 10\"" --become 2>&1 | grep -Ev "^(\[WARNING\]|^$)" || true

echo ""
echo "=============================="
echo "[4] appdb 전체 테이블 수"
echo "=============================="
${ANSIBLE} -m shell -a "${DB_CMD} appdb -Nse \"SELECT COUNT(*) FROM information_schema.TABLES WHERE TABLE_SCHEMA='appdb'\"" --become 2>&1 | grep -Ev "^(\[WARNING\]|^$)" || true

echo ""
echo "=============================="
echo "[5] Smoke test - External HTTPS endpoint"
echo "=============================="
echo "--- GET https://www.iwon-smart.site ---"
curl -sk -o /dev/null -w "HTTP %{http_code} | %{url_effective}\n" https://www.iwon-smart.site || echo "SKIP: curl failed (no external network)"

echo ""
echo "=============================="
echo "[6] Smoke test - WAS health via Ansible"
echo "=============================="
ansible was -i inventory.ini -m shell -a "curl -sS -o /dev/null -w 'WAS HTTP %{http_code}' http://127.0.0.1:8080/api/auth/session -X POST -H 'Content-Type: application/json' --data '{}' 2>/dev/null || echo WAS_NOT_REACHABLE" 2>&1 | grep -Ev "^(\[WARNING\]|^$)" || true

echo ""
echo "=============================="
echo "[7] Smoke test - db01 appuser connectivity"
echo "=============================="
${ANSIBLE} -m shell -a "mariadb -h 127.0.0.1 -u appuser -p'<APP_DB_PASSWORD>' appdb -Nse \"SELECT NOW(), DATABASE();\"" --become 2>&1 | grep -Ev "^(\[WARNING\]|^$)" || true

echo ""
echo "[DONE] Step 5 검증 완료"

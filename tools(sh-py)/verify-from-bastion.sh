#!/bin/bash
set -euo pipefail

ssh -o StrictHostKeyChecking=no iwon@20.214.224.224 << 'EOF'
set -euo pipefail
if command -v mariadb >/dev/null 2>&1; then
  mariadb -h 10.0.2.50 -u appuser -p'<APP_DB_PASSWORD>' appdb -Nse "SELECT 1;"
else
  echo "mariadb client not installed on bastion; fallback to TCP only"
  command -v nc >/dev/null 2>&1 && nc -zv 10.0.2.50 3306
fi
EOF

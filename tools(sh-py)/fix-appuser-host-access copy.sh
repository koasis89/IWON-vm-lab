#!/bin/bash
set -euo pipefail

ssh -o StrictHostKeyChecking=no -J iwon@20.214.224.224 iwon@10.0.2.50 << 'EOF'
set -euo pipefail

ROOT_PW='<ROOT_DB_PASSWORD>'
APP_PW='<APP_DB_PASSWORD>'

# 1) root 계정 접속 확인 (TCP)
mariadb -h 127.0.0.1 -u root -p"${ROOT_PW}" -Nse "SELECT VERSION();"

# 2) appuser host별 계정/비밀번호 정합성 맞춤
mariadb -h 127.0.0.1 -u root -p"${ROOT_PW}" <<SQL
CREATE USER IF NOT EXISTS 'appuser'@'%' IDENTIFIED BY '${APP_PW}';
ALTER USER 'appuser'@'%' IDENTIFIED BY '${APP_PW}';
GRANT ALL PRIVILEGES ON appdb.* TO 'appuser'@'%';

CREATE USER IF NOT EXISTS 'appuser'@'bastion01.internal.cloudapp.net' IDENTIFIED BY '${APP_PW}';
ALTER USER 'appuser'@'bastion01.internal.cloudapp.net' IDENTIFIED BY '${APP_PW}';
GRANT ALL PRIVILEGES ON appdb.* TO 'appuser'@'bastion01.internal.cloudapp.net';

CREATE USER IF NOT EXISTS 'appuser'@'10.0.3.%' IDENTIFIED BY '${APP_PW}';
ALTER USER 'appuser'@'10.0.3.%' IDENTIFIED BY '${APP_PW}';
GRANT ALL PRIVILEGES ON appdb.* TO 'appuser'@'10.0.3.%';

FLUSH PRIVILEGES;
SQL

# 3) 확인
mariadb -h 127.0.0.1 -u root -p"${ROOT_PW}" -Nse "SELECT User,Host FROM mysql.user WHERE User='appuser' ORDER BY Host;"
mariadb -h 127.0.0.1 -u appuser -p"${APP_PW}" appdb -Nse "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='appdb';"
EOF

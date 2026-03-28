#!/usr/bin/env bash
set -euo pipefail

BASTION_HOST="${BASTION_HOST:-20.214.224.224}"
BASTION_USER="${BASTION_USER:-iwon}"
WEB_HOST="${WEB_HOST:-10.0.2.10}"
WAS_HOST="${WAS_HOST:-10.0.2.20}"
DB_HOST="${DB_HOST:-10.0.2.50}"
APP_DB_USER="${APP_DB_USER:-appuser}"
APP_DB_PASSWORD="${APP_DB_PASSWORD:-<APP_DB_PASSWORD>}"

ssh_bastion() {
  ssh -o StrictHostKeyChecking=no "${BASTION_USER}@${BASTION_HOST}" "$@"
}

ssh_internal() {
  local host="$1"
  shift
  ssh_bastion "ssh -o StrictHostKeyChecking=no ${BASTION_USER}@${host} '$*'"
}

echo "== External request check =="
curl -sk -D - -o /tmp/iwon-session-body.txt -X POST 'https://www.iwon-smart.site/api/auth/session' \
  -H 'Origin: https://www.iwon-smart.site' \
  -H 'Content-Type: application/json' \
  --data '{}'
echo
echo "--- body ---"
sed -n '1,40p' /tmp/iwon-session-body.txt
echo

echo "== web01: nginx config and recent logs =="
ssh_internal "${WEB_HOST}" "hostname; whoami; test -f /etc/nginx/sites-available/default && sed -n '1,220p' /etc/nginx/sites-available/default; echo ---; test -f /var/log/nginx/access.log && tail -n 40 /var/log/nginx/access.log || true; echo ---; test -f /var/log/nginx/error.log && tail -n 40 /var/log/nginx/error.log || true"
echo

echo "== was01: service log and local endpoint check =="
ssh_internal "${WAS_HOST}" "hostname; whoami; test -f /var/log/iwon/was.log && tail -n 120 /var/log/iwon/was.log || true; echo ---; curl -sS -D - -o /tmp/was-session-body.txt -X POST 'http://127.0.0.1:8080/api/auth/session' -H 'Origin: https://www.iwon-smart.site' -H 'Content-Type: application/json' --data '{}'; echo ---; sed -n '1,40p' /tmp/was-session-body.txt"
echo

echo "== was01: header combination matrix =="
ssh_internal "${WAS_HOST}" "echo CASE1_origin_only; curl -sS -D - -o /tmp/was-case1.txt -X POST 'http://127.0.0.1:8080/api/auth/session' -H 'Origin: https://www.iwon-smart.site' -H 'Content-Type: application/json' --data '{}'; sed -n '1,18p' /tmp/was-case1.txt; echo ---; echo CASE2_host_and_origin; curl -sS -D - -o /tmp/was-case2.txt -X POST 'http://127.0.0.1:8080/api/auth/session' -H 'Host: www.iwon-smart.site' -H 'Origin: https://www.iwon-smart.site' -H 'Content-Type: application/json' --data '{}'; sed -n '1,18p' /tmp/was-case2.txt; echo ---; echo CASE3_host_origin_xfp; curl -sS -D - -o /tmp/was-case3.txt -X POST 'http://127.0.0.1:8080/api/auth/session' -H 'Host: www.iwon-smart.site' -H 'Origin: https://www.iwon-smart.site' -H 'X-Forwarded-Proto: https' -H 'X-Forwarded-For: 10.0.1.4' -H 'Content-Type: application/json' --data '{}'; sed -n '1,18p' /tmp/was-case3.txt"
echo

echo "== db01: MariaDB appdb connectivity =="
ssh_internal "${DB_HOST}" "hostname; whoami; mariadb -u ${APP_DB_USER} -p\"${APP_DB_PASSWORD}\" appdb -Nse \"SELECT NOW(), DATABASE();\""
echo

echo "== web01 -> was01 direct curl =="
ssh_internal "${WEB_HOST}" "curl -sS -D - -o /tmp/web-to-was-session-body.txt -X POST 'http://${WAS_HOST}:8080/api/auth/session' -H 'Origin: https://www.iwon-smart.site' -H 'Content-Type: application/json' --data '{}'; echo ---; sed -n '1,40p' /tmp/web-to-was-session-body.txt"
## 장애 대응 체크리스트

1. 장애 범위 확인
- 영향 서비스(web/was/app/integration/db/kafka)와 사용자 영향도 즉시 파악

명령 예시:

```bash
# 현재 Azure 구독/계정 확인
az account show -o table

# App Gateway 백엔드 헬스 확인
az network application-gateway show-backend-health \
  -g iwon-svc-rg \
  -n iwon-svc-appgw \
  -o jsonc
```

2. 최근 변경 식별
- 마지막 성공/실패 파이프라인 실행 번호 확인
- 직전 배포 대상(`deployTarget`)과 적용된 마이그레이션 키 확인

명령 예시:

```bash
# 최근 실행 이력 확인 (Azure DevOps CLI)
az pipelines runs list --pipeline-ids <pipeline-id> --top 10 -o table

# 특정 실행 상세
az pipelines runs show --id <run-id> -o jsonc
```

3. 인프라 상태 확인
- Terraform 단계 실패 여부 확인
- VM 네트워크/보안(NSG, App Gateway 백엔드 헬스) 상태 점검

명령 예시:

```bash
# VM 전원 상태
az vm list -d -g iwon-svc-rg --query "[].{name:name,power:powerState,privateIps:privateIps}" -o table

# NSG 규칙 확인
az network nsg list -g iwon-svc-rg -o table
```

4. 애플리케이션 상태 확인
- 대상 서비스 `systemd` 상태(active/failed) 점검
- 애플리케이션 로그(에러 스택, 포트 바인딩, 의존 서비스 연결) 확인

명령 예시:

```bash
# Ansible ad-hoc으로 서비스 상태 확인
ansible was,app,integration,web,kafka,db -i vm-ansible/inventory.ini -m shell -a "systemctl is-active was app integration nginx kafka mariadb || true"

# 주요 로그 확인
ansible was -i vm-ansible/inventory.ini -m shell -a "journalctl -u was -n 120 --no-pager"
ansible app -i vm-ansible/inventory.ini -m shell -a "journalctl -u app -n 120 --no-pager"
ansible integration -i vm-ansible/inventory.ini -m shell -a "journalctl -u integration -n 120 --no-pager"
```

5. 데이터베이스 상태 확인
- `schema_migrations` 최신 적용 항목 확인
- DB 접속/락/스키마 충돌 여부 점검

명령 예시:

```bash
# 최근 마이그레이션 적용 이력
ansible db -i vm-ansible/inventory.ini -m shell -a "mariadb -h 127.0.0.1 -u root -p'${DB_ROOT_PASSWORD}' -e \"SELECT id,migration_key,applied_at FROM appdb.schema_migrations ORDER BY id DESC LIMIT 20;\""

# 락/실행중 트랜잭션 점검
ansible db -i vm-ansible/inventory.ini -m shell -a "mariadb -h 127.0.0.1 -u root -p'${DB_ROOT_PASSWORD}' -e \"SHOW PROCESSLIST;\""
```

6. 알림/공유
- 장애 등급 및 임시 우회 여부를 운영 채널(Teams/Slack)에 즉시 공유
- 복구 담당자, 승인자, 종료 목표 시각(ETA) 지정

명령 예시:

```bash
# (선택) 웹훅 테스트
curl -X POST "$DB_ROLLBACK_NOTIFY_WEBHOOK_URL" \
  -H "Content-Type: application/json" \
  -d '{"text":"[incident] 장애 대응 시작: 담당자 지정 및 ETA 공유"}'
```

## 6. 배포 실패 시 즉시 복구 순서

1. 배포 중지
- 동일 파이프라인 재실행을 잠시 중단
- 운영 승인 게이트를 닫아 추가 배포 유입 방지

명령 예시:

```bash
# 현재 실행 중인 파이프라인 확인
az pipelines runs list --status inProgress --top 20 -o table

# 필요 시 실행 취소
az pipelines runs cancel --id <run-id>
```

2. 서비스 단위 우선 복구
- 최근 정상 버전 아티팩트(JAR/정적 파일)로 재배포
- `deployTarget`을 최소 단위로 제한하여 복구(web -> was/app -> integration 순)

명령 예시:

```bash
# 서비스 재시작 및 상태 확인 (최소 단위 복구)
ansible web -i vm-ansible/inventory.ini -m shell -a "systemctl restart nginx; systemctl status nginx --no-pager"
ansible was -i vm-ansible/inventory.ini -m shell -a "systemctl restart was; systemctl status was --no-pager"
ansible app -i vm-ansible/inventory.ini -m shell -a "systemctl restart app; systemctl status app --no-pager"
ansible integration -i vm-ansible/inventory.ini -m shell -a "systemctl restart integration; systemctl status integration --no-pager"
```

3. DB 마이그레이션 실패 시
- 실패한 migration 키 확인
- 동일 경로의 `*.rollback.sql` 존재 시 즉시 실행
- 롤백 후 애플리케이션 호환성 재확인

명령 예시:

```bash
# 마지막 실패/적용 지점 확인
ansible db -i vm-ansible/inventory.ini -m shell -a "mariadb -h 127.0.0.1 -u root -p'${DB_ROOT_PASSWORD}' -e \"SELECT id,migration_key,applied_at FROM appdb.schema_migrations ORDER BY id DESC LIMIT 5;\""

# 수동 롤백 SQL 실행 예시
ansible db -i vm-ansible/inventory.ini -m shell -a "mariadb -h 127.0.0.1 -u root -p'${DB_ROOT_PASSWORD}' appdb < /opt/vm-lab/migrations/20260328__v1__001_example.rollback.sql"
```

4. 트래픽 안정화
- App Gateway 헬스 프로브 정상 여부 확인
- 필요 시 일시적으로 정상 백엔드만 남겨 트래픽 우회

명령 예시:

```bash
# 백엔드 헬스 재확인
az network application-gateway show-backend-health -g iwon-svc-rg -n iwon-svc-appgw -o jsonc
```

5. 검증
- 핵심 API/화면 smoke test 수행
- 로그인/주요 트랜잭션/DB 읽기·쓰기 동작 확인

명령 예시:

```bash
# HTTP 상태 확인
curl -k -I https://www.iwon-smart.site
curl -k -I https://www.iwon-smart.site/app

# 내부 서비스 포트 상태
ansible was,app,integration -i vm-ansible/inventory.ini -m shell -a "ss -lntp | egrep ':8080|:80|:443' || true"
```

6. 사후 조치
- 장애 원인(RCA) 기록
- 재발 방지 항목을 체크리스트/파이프라인 정책에 반영
- 롤백/복구 절차를 문서와 자동화 스크립트에 동기화

명령 예시:

```bash
# 최근 실패 런 로그 추출(요약)
az pipelines runs show --id <failed-run-id> --query "{id:id,result:result,state:state,finishTime:finishTime}" -o jsonc
```

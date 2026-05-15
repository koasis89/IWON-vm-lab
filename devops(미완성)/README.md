# DevOps Automation Overview

이 문서는 `devops` 폴더의 전체 구성, 각 파일 역할, 그리고 실제 실행 순서를 한 번에 정리한 가이드입니다.

## 1. 폴더 구조

```text
devops/
  azure-pipelines-vm.yml
  azure-pipelines-vm-dev.yml
  azure-pipelines-vm-prod.yml
  ansible/
    deploy-db-migrations.yml
    deploy-db-sql.yml
    tasks/
      apply-single-migration.yml
  scripts/
    create-variable-groups.py
    generate_inventory_from_tf.py
    README-variable-groups.md
  variable-groups/
    dev.variable-group.template.yml
    prod.variable-group.template.yml
```

## 2. 각 파일 역할

### 2.1 파이프라인 파일

- `devops/azure-pipelines-vm.yml`
  - 기본(공통) 파이프라인
  - Terraform 배포 + Ansible 배포 + 단일 SQL 적용(`deploy-db-sql.yml`) 흐름 제공

- `devops/azure-pipelines-vm-dev.yml`
  - DEV 전용 파이프라인
  - 자동 트리거(main/develop + 관련 경로)
  - Terraform 결과를 바탕으로 Ansible 적용
  - DB 마이그레이션은 날짜/버전 폴더 기반 순차 실행

- `devops/azure-pipelines-vm-prod.yml`
  - PROD 전용 파이프라인
  - 수동 트리거
  - 수동 승인 게이트 + 야간 배포 윈도우(KST) + 소스 태그 정책 체크
  - 허용 태그 예시: `main-vX.Y.Z`, `release-main-X.Y.Z`

### 2.2 Ansible 연동 파일

- `devops/ansible/deploy-db-migrations.yml`
  - 마이그레이션 루트(`backup/db/migrations/...`)의 SQL 파일을 정렬 순서로 실행
  - `schema_migrations` 이력 테이블로 중복 적용 방지

- `devops/ansible/tasks/apply-single-migration.yml`
  - 단일 SQL 적용 단위 작업
  - 실패 시 `.rollback.sql` 훅 실행(옵션)
  - 실패 알림을 Teams/Slack/Webhook 포맷으로 전송(옵션)

- `devops/ansible/deploy-db-sql.yml`
  - 단일 SQL 파일 직접 적용 용도(레거시/긴급 대응)

### 2.3 스크립트

- `devops/scripts/generate_inventory_from_tf.py`
  - Terraform output JSON에서 bastion/public/private IP를 읽어 동적 Ansible 인벤토리 생성

- `devops/scripts/create-variable-groups.py`
  - Azure DevOps Library Variable Group 자동 생성/업데이트
  - 템플릿 키 기준으로 DEV/PROD 변수 그룹 구성
  - secret 값은 `VG_SECRET_<KEY>` 환경변수로 주입

- `devops/scripts/README-variable-groups.md`
  - 변수 그룹 자동화 스크립트 실행 가이드

### 2.4 변수 그룹 템플릿

- `devops/variable-groups/dev.variable-group.template.yml`
  - DEV 표준 키 이름 템플릿

- `devops/variable-groups/prod.variable-group.template.yml`
  - PROD 표준 키 이름 템플릿
  - PROD 태그 정규식(`PROD_ALLOWED_TAG_REGEX`) 포함

## 3. 실행 순서

### 3.1 초기 1회 설정

1. Azure DevOps Service Connection 생성
- 변수명: `AZURE_SERVICE_CONNECTION`

2. SSH 키 Secure File 등록
- 변수명: `ANSIBLE_SSH_PRIVATE_KEY_SECURE_FILE`

3. Variable Group 생성
- 수동 등록 또는 아래 자동화 스크립트 사용:

```bash
python devops/scripts/create-variable-groups.py \
  --org https://dev.azure.com/<org> \
  --project <project> \
  --dev-group-name iwon-vm-dev-vg \
  --prod-group-name iwon-vm-prod-vg \
  --authorize
```

4. Environment 승인 정책 설정
- DEV/PROD 환경별 Approval & Checks 구성

### 3.2 DEV 배포 순서

1. `devops/azure-pipelines-vm-dev.yml` 실행
2. 필요 시 `runTerraform=true`로 인프라 반영
3. `deployTarget`으로 배포 대상 선택
4. 필요 시 `runDbMigrations=true`로 순차 마이그레이션 수행
5. 실패 시 웹훅 알림 확인(옵션)

### 3.3 PROD 배포 순서

1. 릴리스 태그 생성
- `main-vX.Y.Z` 또는 `release-main-X.Y.Z`

2. `devops/azure-pipelines-vm-prod.yml` 수동 실행
3. 수동 승인 게이트 통과
- Terraform 승인
- Ansible 승인
- DB Migration 승인

4. 정책 체크 통과 확인
- 소스 태그 정책
- 야간 배포 윈도우(KST)

5. 배포 완료 후 점검
- 서비스 상태(systemd)
- App Gateway/애플리케이션 응답
- DB 마이그레이션 반영 상태

## 4. 운영 팁

- PROD는 `deployTarget=all` 대신 단계별(web -> was/app -> integration -> db) 점진 배포 권장
- 마이그레이션은 반드시 새 파일 추가 방식으로 관리(기존 파일 수정 금지)
- 롤백 SQL은 같은 경로에 `*.rollback.sql` 형태로 함께 배치
- 웹훅 URL/비밀번호 등 민감값은 Variable Group secret으로만 관리

## 5. 장애 대응 체크리스트

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

# Azure DevOps + Terraform + Ansible 통합 가이드

이 문서는 개발자가 코드 변경 후 Azure VM 환경(WEB, WAS, Integration, App, DB SQL)에 자동 반영되도록 구성한 전체 프로세스를 한 문서로 통합한 가이드입니다.

요구사항 반영 범위:
- Managed Agent(무료) 사용
- Terraform 출력값(IP 주소 등)을 Azure DevOps Pipeline에서 받아 Ansible 실행
- Ansible로 Java, Nginx, Kafka, DB 구성 및 배포

관련 구현 파일:
- [devops/azure-pipelines-vm-dev.yml](../../devops/azure-pipelines-vm-dev.yml)
- [devops/azure-pipelines-vm-prod.yml](../../devops/azure-pipelines-vm-prod.yml)
- [devops/scripts/generate_inventory_from_tf.py](../../devops/scripts/generate_inventory_from_tf.py)
- [vm-ansible/site.yml](../../vm-ansible/site.yml)
- [devops/ansible/deploy-db-migrations.yml](../../devops/ansible/deploy-db-migrations.yml)
- [devops/variable-groups/dev.variable-group.template.yml](../../devops/variable-groups/dev.variable-group.template.yml)
- [devops/variable-groups/prod.variable-group.template.yml](../../devops/variable-groups/prod.variable-group.template.yml)
- [devops/scripts/create-variable-groups.py](../../devops/scripts/create-variable-groups.py)
- [devops/scripts/README-variable-groups.md](../../devops/scripts/README-variable-groups.md)

## 0. 사전 준비

1. Azure DevOps Service Connection 준비
- 변수: AZURE_SERVICE_CONNECTION

2. SSH 키 등록
- Secure Files에 private key 업로드
- 변수: ANSIBLE_SSH_PRIVATE_KEY_SECURE_FILE

3. 비밀 변수 등록
- DB_APP_PASSWORD (secret)
- DB_ROOT_PASSWORD (secret)

4. Terraform remote state(권장)
- TFSTATE_RG
- TFSTATE_STORAGE
- TFSTATE_CONTAINER
- TFSTATE_KEY

## 파이프라인 분기 전략

DEV:
- 파이프라인: [devops/azure-pipelines-vm-dev.yml](../../devops/azure-pipelines-vm-dev.yml)
- 용도: 개발자 변경 자동 반영 및 검증
- 트리거: main/develop + 관련 경로 변경

PROD:
- 파이프라인: [devops/azure-pipelines-vm-prod.yml](../../devops/azure-pipelines-vm-prod.yml)
- 용도: 운영 반영
- 트리거: 수동 실행(trigger: none)
- 소스 정책: main 태그 릴리스만 허용
	- `main-vX.Y.Z`
	- `release-main-X.Y.Z`

환경별 tfvars:
- [vm-azure/environments/dev.tfvars](../environments/dev.tfvars)
- [vm-azure/environments/prod.tfvars](../environments/prod.tfvars)

## 승인 게이트 구성

1. 수동 승인 게이트(ManualValidation)
- Terraform 전
- Ansible 배포 전
- DB 마이그레이션 전

2. 환경 승인(Environment approval)
- deployment job에 environment 연결
- DEV 예시: iwon-vm-dev-infra, iwon-vm-dev-app, iwon-vm-dev-db
- PROD 예시: iwon-vm-prod-infra, iwon-vm-prod-app, iwon-vm-prod-db

참고:
- Environment approval의 승인자/체크 규칙은 Azure DevOps Environment UI에서 설정합니다.

Environment 승인 설정 절차:
1. Azure DevOps에서 Pipelines -> Environments 이동
2. 환경 생성(예: iwon-vm-prod-app)
3. 해당 환경 메뉴에서 Approvals and checks 선택
4. Approvals 체크 추가 후 승인자(운영자 그룹) 지정
5. 필요 시 Branch control, Business hours 체크 추가
6. 파이프라인 deployment job의 environment 이름과 정확히 일치하는지 확인

## 1단계. Terraform 인프라 배포

목적:
- VM 인프라를 생성/갱신하고 다음 단계에서 사용할 출력값을 확보합니다.

실행 절차:
1. 파이프라인 실행 시 runTerraform=true 선택
2. Stage 1에서 아래 순서 수행
- terraform init
- terraform validate
- terraform plan
- terraform apply -auto-approve
- terraform output -json

구성:
- Stage 이름: Stage 1 - Terraform Apply and Output
- 아티팩트: terraform-output
- 출력 파일: tf-output.json

결과물:
- Azure 리소스(VM/네트워크/스토리지/App Gateway/Key Vault) 배포 또는 갱신
- 다음 단계 입력값(bastion_public_ip, vm_private_ips 등) 확보

점검 포인트:
- validate/plan/apply 성공
- terraform-output 아티팩트 생성

## 2단계. Terraform 출력 기반 Ansible 구성

목적:
- Terraform 출력값으로 동적 인벤토리를 만들고 Managed Agent에서 bastion 경유 구성 자동화를 수행합니다.

실행 절차:
1. Terraform 출력 수신
- runTerraform=true: Stage 1 아티팩트 다운로드
- runTerraform=false: 기존 state에서 terraform output -json 실행

2. 동적 인벤토리 생성
- 스크립트: [devops/scripts/generate_inventory_from_tf.py](../../devops/scripts/generate_inventory_from_tf.py)
- 생성 파일: inventory.generated.ini

3. Ansible 실행
- 플레이북: [vm-ansible/site.yml](../../vm-ansible/site.yml)
- 파라미터 deployTarget 선택
	- all
	- web
	- was
	- app
	- integration
	- db
	- kafka

구성:
- bastion_public_ip -> bastion01
- vm_private_ips -> web01/was01/app01/smartcontract01/db01/kafka01
- ProxyJump 자동 구성

결과물:
- ansible-inventory 아티팩트 생성
- 선택 대상 VM에 공통 패키지/서비스 구성 반영

점검 포인트:
- Managed Agent에서 bastion SSH 연결 성공
- internal_vms 대상 작업 정상 수행
- 대상 서비스 상태 active 유지

## 3단계. 애플리케이션 코드 및 DB 배포 반영

목적:
- 개발자가 수정한 JAR/정적 파일/SQL을 운영 VM에 반영합니다.

실행 절차:
1. 산출물 경로 설정
- WEB_HTML_ZIP_PATH
- WAS_JAR_PATH
- APP_JAR_PATH
- INTEGRATION_JAR_PATH

2. 배포 대상 선택
- deployTarget=all 또는 서버군 단위 부분 배포

3. DB 마이그레이션 반영(옵션)
- runDbMigrations=true
- dbMigrationsRoot 설정
- 플레이북: [devops/ansible/deploy-db-migrations.yml](../../devops/ansible/deploy-db-migrations.yml)

구성:
- web01: html.zip 반영, nginx 재기동
- was01/app01/smartcontract01: JAR 반영, systemd 재기동
- db01: 날짜/버전 폴더 내 SQL을 정렬 순서대로 적용

결과물:
- 변경 코드가 대상 서비스에 반영
- 선택 시 DB 마이그레이션도 동일 파이프라인에서 순차 적용

점검 포인트:
- 서비스 상태(systemd)
- 애플리케이션 endpoint 응답
- DB 변경 반영 여부

## DB 마이그레이션 폴더 규칙

기준 문서:
- [backup/db/migrations/README.md](../../backup/db/migrations/README.md)

루트 구조:
- DEV: backup/db/migrations/dev
- PROD: backup/db/migrations/prod

예시:
- backup/db/migrations/dev/20260328/v1/001_init_table.sql
- backup/db/migrations/dev/20260328/v1/002_add_index.sql
- backup/db/migrations/prod/20260328/v1/001_release.sql

적용 방식:
- 모든 .sql 파일 경로를 사전순 정렬해 순차 실행
- 적용 이력은 appdb.schema_migrations 테이블에 기록
- 재실행 시 이미 반영된 migration_key는 자동 스킵
- 마이그레이션 실패 시 같은 경로의 `.rollback.sql` 파일을 선택적으로 실행 가능
- 실패 시 Teams/Slack/Webhook 알림을 선택적으로 전송 가능

## 4. 파이프라인 파라미터 요약

- runTerraform
	- true: 인프라 배포 후 출력 사용
	- false: 기존 인프라 출력만 조회
- deployTarget
	- all/web/was/app/integration/db/kafka
- runDbMigrations
	- true: 순차 DB 마이그레이션 단계 수행
- dbMigrationsRoot
	- repo 기준 마이그레이션 루트 경로
- enableRollbackHook
	- true: 실패한 migration과 짝인 `.rollback.sql` 자동 실행 시도
- DB_ROLLBACK_NOTIFY_ENABLED
	- true: 롤백 훅/실패 알림 웹훅 전송
- DB_ROLLBACK_NOTIFY_WEBHOOK_URL
	- Teams/Slack/일반 webhook URL
- DB_ROLLBACK_NOTIFY_CHANNEL
	- `teams`, `slack`, `webhook` 중 운영 규칙에 맞게 지정
	- `teams`: MessageCard
	- `slack`: Block Kit
	- `webhook`: 기본 JSON text payload

PROD 전용 파라미터:
- enforceProdNightWindow
	- true: KST 야간 배포 윈도우 체크 강제
- prodWindowStartHourKst
	- 배포 시작 시각(기본 22)
- prodWindowEndHourKst
	- 배포 종료 시각(기본 6)
- PROD_ALLOWED_TAG_REGEX
	- 운영 릴리스 태그 허용 정규식

## DEV/PROD 변수 그룹 템플릿

- DEV 템플릿: [devops/variable-groups/dev.variable-group.template.yml](../../devops/variable-groups/dev.variable-group.template.yml)
- PROD 템플릿: [devops/variable-groups/prod.variable-group.template.yml](../../devops/variable-groups/prod.variable-group.template.yml)

적용 방법:
1. Azure DevOps Library에서 Variable Group 생성
2. 템플릿 키를 동일 이름으로 등록
3. 비밀 값은 반드시 secret으로 저장
4. 파이프라인에서 variable group 연결

자동화 스크립트 사용:
1. [devops/scripts/create-variable-groups.py](../../devops/scripts/create-variable-groups.py) 실행
2. org/project 인자와 그룹명 지정
3. secret 키는 `VG_SECRET_<KEY>` 환경변수로 전달

## 5. 운영 권장사항

1. 배포 분리
- 운영은 deployTarget을 분리해 점진 배포

2. DB 변경 관리
- SQL은 롤백 스크립트와 함께 버전 관리

3. 비밀 관리
- DB 계정/키/서비스 연결 정보는 Variable Group + Secret으로만 관리

4. 변경 추적
- 파이프라인 실행 결과와 아티팩트를 릴리스 단위로 보관

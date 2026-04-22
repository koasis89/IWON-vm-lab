# 3단계 가이드: 애플리케이션 코드와 DB SQL 반영

이 단계는 개발자가 수정한 산출물(JAR, 정적 파일, SQL)을 서버에 반영하는 배포 단계입니다.

대상 파일:
- [devops/azure-pipelines-vm-dev.yml](../../devops/azure-pipelines-vm-dev.yml)
- [devops/azure-pipelines-vm-prod.yml](../../devops/azure-pipelines-vm-prod.yml)
- [devops/ansible/deploy-db-migrations.yml](../../devops/ansible/deploy-db-migrations.yml)
- [vm-ansible/group_vars/all.yml](../../vm-ansible/group_vars/all.yml)

## 생성 절차

1. 애플리케이션 산출물 경로 지정
- WEB_HTML_ZIP_PATH
- WAS_JAR_PATH
- APP_JAR_PATH
- INTEGRATION_JAR_PATH

2. 서버 반영 실행
- deployTarget 파라미터 선택
- all: 전체 서버 반영
- was/app/integration/web/db/kafka: 부분 반영

3. DB 마이그레이션 반영(옵션)
- runDbMigrations=true
- dbMigrationsRoot에 마이그레이션 루트 경로 지정
- enableRollbackHook=true/false 선택
- playbook: [devops/ansible/deploy-db-migrations.yml](../../devops/ansible/deploy-db-migrations.yml)

## 구성

애플리케이션 반영:
- web01: html.zip 반영 및 nginx 재기동
- was01/app01/smartcontract01: JAR 교체 및 서비스 재기동

DB 마이그레이션 반영:
- db01에서 날짜/버전 폴더의 SQL을 정렬 순서대로 적용
- 적용 이력은 appdb.schema_migrations 테이블에 기록
- 실패 시 같은 이름의 .rollback.sql 파일을 선택적으로 실행
- root 계정 비밀번호는 DB_ROOT_PASSWORD(secret) 사용

## 결과물

성공 시:
- 개발자가 수정한 코드가 VM 서비스에 반영됨
- 서비스 재기동 후 최신 버전으로 동작
- 선택 시 DB 마이그레이션도 같은 파이프라인에서 적용

점검 포인트:
- 서비스별 systemd 상태
- 애플리케이션 엔드포인트 응답
- DB 스키마/데이터 변경 적용 여부

운영 권장:
- SQL은 롤백 스크립트와 함께 관리
- 운영 배포는 deployTarget을 분리해 점진 배포

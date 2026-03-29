# OPS Automation Overview

이 문서는 `ops` 폴더의 운영 배포 자동화 구성을 설명합니다.
현재 구성은 단일 운영 흐름만 유지하며, 추가 환경 배포 단계는 포함하지 않습니다.

개발자 실행 모델:
- Azure DevOps 웹 포털 수동 실행 대신 `bash deploy.sh` 호출로 배포 실행
- 개발자는 Azure 리소스/인프라 코드 직접 제어 없이 배포 요청만 수행

## 1. 폴더 구조

```text
ops/
  azure-pipelines-vm.yml
  ansible/
    install-ado-agent.yml
    site-app.yml
  scripts/
    artifacts.conf.example
    deploy.sh
    make-deploy-conf.sh
    maven-path-mapping.template.env
    ops-defaults.env
    publish-universal-package.sh
    generate_inventory_from_tf.py
    reconnect-ado-pipeline.ps1
  docs/
    readme-ado-artifacts.md
    readme-ops-developer-quickstart.md
    readme-ado-setup-developer.md
```

루트 실행 스크립트:

```text
deploy.sh
```

스크립트 위치:
- `deploy.sh` (루트 래퍼)
- `ops/scripts/deploy.sh` (실제 API 호출)

## 2. 배포 원칙

- 개발자가 로컬에서 빌드한 산출물을 Azure DevOps Feed에 업로드한 뒤 운영 배포
- 개발자는 `bash deploy.sh` 방식으로 배포를 요청
- DB 작업은 파이프라인에서 수행하지 않음 (필요 시 DBeaver로 수동 작업)
- 운영 배포 대상은 애플리케이션 계층(web/was/app/integration/kafka)만 포함

Feed-only 원칙:
- 파이프라인은 저장소의 소스를 빌드하지 않음
- 파이프라인은 Feed에서 패키지를 내려받아 검증 후 Ansible 배포만 수행
- 패키지 타입은 Universal 기본, Maven 허용

## 2.1 PAT 기반 로컬 호출 방식

운영자가 값을 채운 `deploy.conf`를 개발자에게 전달하는 방식을 권장합니다.

역할 분리:
- Azure DevOps 포털: PAT 발급, 파이프라인 ID 확인
- 로컬/CLI: `deploy.conf` 생성 및 배포 실행

운영자 절차:
1. (포털) PAT 발급, 파이프라인 ID 확인
2. (로컬) 아래 명령으로 `deploy.conf` 생성

```bash
bash ops/scripts/make-deploy-conf.sh
```

3. 생성된 `deploy.conf`를 저장소에 커밋하지 않고(로컬/보안 채널) 개발자에게 전달

보안 기본값:
- `deploy.conf`는 `.gitignore`로 커밋 차단

개발자 절차:
1. 전달받은 `deploy.conf`를 프로젝트 루트에 저장
2. `bash deploy.sh` 실행 (`deploy.sh`가 `deploy.conf` 자동 로드)

실행:

```bash
bash deploy.sh
```

Windows PowerShell 참고:
- `sh` 대신 `bash`를 사용합니다.

## 2.2 Azure 포털에서 OPS가 할 일

1. 배포 대상 구독/리소스 그룹/핵심 리소스 상태 확인
2. Service Connection 서비스 주체의 RBAC 권한 확인
3. tfstate 저장소(Storage/Container) 접근 및 잠금 상태 확인
4. Key Vault 시크릿/인증서 만료 여부 확인
5. Azure Monitor 경고 상태와 배포 후 점검 대시보드 준비

## 3. Feed 패키지 정책

필수 산출물(패키지 내부 상대경로):
- `web/html.zip`
- `was/app.jar`
- `app/app.jar`
- `integration/app.jar`

운영 기본:
- `ops/scripts/ops-defaults.env`에서 중앙 관리
- 파이프라인 파라미터가 비어 있거나 `from-defaults`이면 중앙 기본값 적용
- 기본 Feed 타입은 `universal`

호환 모드:
- Maven Feed도 허용하되, 산출물 상대경로를 파이프라인 파라미터로 정확히 지정

Universal 업로드 자동화:
- `bash ops/scripts/publish-universal-package.sh`
- 커밋 로그 기반 릴리즈 노트 자동 생성: `release/notes/universal-<version>.md`

## 4. 최소 실행 순서

1. Azure DevOps Service Connection 및 SSH Secure File 등록
2. Terraform 상태 저장소 변수(`TFSTATE_RG`, `TFSTATE_STORAGE`) 설정
3. 운영자 가이드 기준으로 Azure DevOps 구성/권한/Agent Pool 점검
4. Self-hosted agent 자동 설치 실행 (필요 시)
  - `ansible-playbook -i <inventory> ops/ansible/install-ado-agent.yml --extra-vars "ado_url=... ado_pool=... ado_pat=..."`
5. 필요 시 Terraform 적용 (`runTerraform=true`)
6. Feed 패키지 타입/버전 지정 (`artifactFeedType`, `universalPackageVersion` 등)
7. Ansible 배포 실행 (`deployTarget=all` 또는 개별 타깃)

자세한 단계는 `ops/docs` 하위 3개 문서를 참고하세요.

- 운영자용 가이드: `ops/docs/readme-ado-artifacts.md`
- 개발자용 가이드: `ops/docs/readme-ops-developer-quickstart.md`
- 개발자 환경설정 가이드: `ops/docs/readme-ado-setup-developer.md`

## 5. Azure DevOps 파이프라인 경로 재연결

`ops/azure-pipelines-vm.yml`로 재연결하려면 아래 스크립트를 사용합니다.

```powershell
pwsh ./ops/scripts/reconnect-ado-pipeline.ps1 \
  -Organization "https://dev.azure.com/<org>" \
  -Project "<project>" \
  -PipelineName "<pipeline-name>"
```

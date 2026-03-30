# GitOps Architecture (GitHub + Azure DevOps + Ansible)

이 문서는 `gitops/gitops구성요약.md`를 기반으로, 실제 운영 가능한 수준의 상세 절차를 정리한 문서입니다.

대상 목표:
- GitHub: 소스 관리 및 빌드 결과물 생성
- Azure DevOps: 배포 오케스트레이션(Terraform + Ansible)
- Ansible: VM 설정/배포 자동화

---

## 1. 최종 아키텍처

### 1.1 역할 분리

- GitHub (CI)
  - 시스템별 저장소(Web/WAS/App/Integration)에서 빌드
  - 산출물(JAR/ZIP) 생성
  - Azure DevOps Artifacts Feed로 업로드
- Azure DevOps (CD)
  - 수동 실행 파이프라인으로 배포 트리거
  - Terraform 단계(선택)로 인프라 반영
  - Feed에서 산출물 다운로드
  - Ansible 플레이북으로 VM 반영 및 서비스 재시작
- VM Ansible
  - 서비스별 role 기반 배포
  - 웹/와스/앱/연계 분리 배포 가능

### 1.2 배포 기준

- Feed-only 배포(소스 빌드 없음)
- Universal Packages 기본, Maven Feed 허용
- 파이프라인 YAML: `ops/azure-pipelines-vm.yml`
- 앱 배포 플레이북: `ops/ansible/site-app.yml`

---

## 2. 저장소 구조 및 표준 파일

- 배포 파이프라인: `ops/azure-pipelines-vm.yml`
- 운영 기본값: `ops/scripts/ops-defaults.env`
- Universal 업로드 스크립트: `ops/scripts/publish-universal-package.sh`
- 배포 호출 스크립트: `ops/scripts/deploy.sh` (루트 `deploy.sh` 래퍼)
- 인벤토리 생성 스크립트: `ops/scripts/generate_inventory_from_tf.py`
- 앱 배포 플레이북: `ops/ansible/site-app.yml`
- 인프라 코드: `vm-azure/*.tf`
- Ansible 운영 베이스: `vm-ansible/*`

---

## 3. Azure DevOps 포털 수동 설정 절차

## 3.1 Project 및 Feed 생성

1. Organization 접속: `https://dev.azure.com/iteyes-ito`
2. Project 생성/확인: `iwon-smart-ops`
3. Artifacts Feed 생성/확인: `iwon-feed`

권장 설정:
- Feed scope: project
- View: release 운영

## 3.2 Service Connection 생성

1. Project Settings -> Service connections
2. New service connection -> Azure Resource Manager
3. Subscription/Scope를 실제 배포 구독으로 지정
4. 이름 예시: `iwon-azure-rm-conn`

## 3.3 Secure File 및 변수 설정

1. Pipelines -> Library -> Secure files
2. SSH private key 업로드 (예: `iwon-vm-key.pem`)
3. Pipeline 변수(또는 Variable Group) 설정

필수 변수:
- `AZURE_SERVICE_CONNECTION`
- `ANSIBLE_SSH_PRIVATE_KEY_SECURE_FILE`
- `TFSTATE_RG`
- `TFSTATE_STORAGE`
- `TFSTATE_CONTAINER` (기본 `tfstate`)
- `TFSTATE_KEY` (기본 `vm-azure/prod.tfstate`)

## 3.4 Environment 구성

1. Pipelines -> Environments
2. `iwon-vm-ops-infra`, `iwon-vm-ops-app` 생성
3. 필요 시 Approvals and checks 설정

## 3.5 Pipeline 생성

1. Pipelines -> New pipeline
2. 저장소 연결
3. Existing Azure Pipelines YAML file 선택
4. 경로 지정: `ops/azure-pipelines-vm.yml`
5. 기본 브랜치: `main`

---

## 4. 파이프라인 실행 파라미터 설계

핵심 파라미터 (`ops/azure-pipelines-vm.yml`):
- `runTerraform`: 인프라 반영 여부
- `deployTarget`: `all|web|was|app|integration|kafka`
- `artifactFeedType`: `from-defaults|universal|maven`
- `artifactFeedName`
- `universalPackageName`, `universalPackageVersion`
- `mavenPackageDefinition`, `mavenPackageVersion`
- `webHtmlZipRelative`, `wasJarRelative`, `appJarRelative`, `integrationJarRelative`

운영 기본값은 `ops/scripts/ops-defaults.env`에서 중앙관리합니다.

---

## 5. GitHub(시스템별) 빌드/업로드 절차

## 5.1 공통 Gradle 설정

아래 feed 연결을 `repositories` 및 `publishing.repositories`에 추가:

```gradle
maven {
  url 'https://pkgs.dev.azure.com/iteyes-ito/iwon-ops/_packaging/iwon-feed/maven/v1'
  name 'iwon-feed'
  credentials(PasswordCredentials)
  authentication {
      basic(BasicAuthentication)
  }
}
```

Windows PowerShell 기준 gradle.properties 위치:
- `$env:USERPROFILE\.gradle\gradle.properties`

예시:

```properties
iwon-feedUsername=iteyes-ito
iwon-feedPassword=PERSONAL_ACCESS_TOKEN
```

## 5.2 산출물 업로드 (Universal 기준)

```bash
bash ops/scripts/publish-universal-package.sh --feed iwon-feed --name iwon-ops-bundle --version 2026.3.30-main
```

스크립트 동작:
- `release/web`, `release/was`, `release/app`, `release/integration` 산출물 점검
- release notes 자동 생성
- Universal Package publish

---

## 6. Ansible 자동화 상세

## 6.1 파이프라인 내 Ansible 흐름

1. Terraform output 확보
2. `generate_inventory_from_tf.py`로 동적 inventory 생성
3. SSH 키 설치
4. Ansible 설치
5. Feed 산출물 다운로드 + 검증
6. `ops/ansible/site-app.yml` 실행

## 6.2 실제 플레이북 구조 (요약)

`ops/ansible/site-app.yml`은 아래 구조로 역할 분리되어 있음:
- common
- nfs_client (선택)
- web
- java_service (was/app/integration)
- kafka

핵심 변수 예시:

```yaml
- name: Configure app service
  hosts: app
  become: true
  roles:
    - role: java_service
      vars:
        java_service_name: app
        java_app_dir: /opt/apps/app
        java_jar_local_src: "{{ app_jar_src }}"
        java_jar_remote_name: app.jar
```

## 6.3 실행 예시(수동)

```bash
ansible-playbook -i vm-ansible/inventory.ini ops/ansible/site-app.yml \
  --extra-vars "was_jar_src=/tmp/was.jar app_jar_src=/tmp/app.jar integration_jar_src=/tmp/integration.jar web_html_zip_src=/tmp/web.zip"
```

---

## 7. 운영 Runbook (End-to-End)

## 7.1 운영자 초기 1회

1. Azure DevOps Project/Feed 생성
2. Service Connection 생성
3. Secure File 등록
4. Pipeline 생성 및 YAML 연결
5. `ops/scripts/ops-defaults.env` 기본값 점검

## 7.2 개발자 배포 사이클

1. 소스 수정 후 빌드
2. Feed 업로드(Universal/Maven)
3. `bash deploy.sh`로 파이프라인 호출
4. Azure DevOps Run 결과 확인

## 7.3 장애 대응 포인트

- Feed 다운로드 실패: feed/package/version 확인
- semver 실패: 버전 형식 점검
- artifact not found: 상대경로/패턴 확인
- ansible 연결 실패: SSH key/NSG/host 접근 확인

---

## 8. 보안 및 거버넌스

1. PAT는 저장소에 커밋 금지
2. `deploy.conf`, `ops/scripts/artifacts.conf` 로컬 관리
3. 권한 최소화
   - Packaging: read/write
   - Build: read/execute
4. 수동 트리거 유지 (`trigger: none`)
5. 운영 변경 이력은 PR + 승인으로 관리

---

## 9. 코드 스니펫 모음

## 9.1 deploy.conf 예시

```bash
ADO_ORG="iteyes-ito"
ADO_PROJECT="iwon-ops"
ADO_PIPELINE_ID="123"
ADO_PAT="<PAT>"
ADO_BRANCH="refs/heads/main"
```

## 9.2 Azure DevOps CLI 컨텍스트 설정

```powershell
$env:AZURE_DEVOPS_EXT_PAT = "<PAT>"
az devops configure --defaults organization=https://dev.azure.com/iteyes-ito project=iwon-ops
```

## 9.3 Pipeline 생성 시 YAML 경로

```text
ops/azure-pipelines-vm.yml
```

---

## 10. 결론

현재 구조는 소스 저장소 분리 환경에서 안정적으로 운영 가능한 하이브리드 GitOps 방식입니다.
핵심은 "빌드/업로드"와 "배포/기동"을 분리하고, Azure DevOps 파이프라인에서 Terraform/Ansible을 일관된 방식으로 실행하는 것입니다.

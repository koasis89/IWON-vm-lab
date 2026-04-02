# GitOps 기반 Azure DevOps 구축 실행 리포트

작성일: 2026-03-30
작업 경로: C:\Workspace\IWON-vm-lab
요청 범위: gitops 폴더 기반 DevOps 구축 (GitHub Actions 설정은 수동)

## 1) 수행 목표
- gitops 저장소에 준비된 IaC/파이프라인 구성으로 Azure DevOps 리소스 부트스트랩 실행
- 실행 절차, 명령어, 결과를 문서화

## 2) 사전 점검

### 실행 명령
```powershell
Set-Location gitops/terraform/azuredevops-bootstrap
Write-Host "PWD: $((Get-Location).Path)"
Get-Command terraform -ErrorAction SilentlyContinue | Select-Object Name,Source
Get-Command az -ErrorAction SilentlyContinue | Select-Object Name,Source
if ($env:AZDO_PERSONAL_ACCESS_TOKEN) { "AZDO_PERSONAL_ACCESS_TOKEN=SET" } else { "AZDO_PERSONAL_ACCESS_TOKEN=NOT_SET" }
if ($env:ARM_CLIENT_ID) { "ARM_CLIENT_ID=SET" } else { "ARM_CLIENT_ID=NOT_SET" }
if ($env:ARM_TENANT_ID) { "ARM_TENANT_ID=SET" } else { "ARM_TENANT_ID=NOT_SET" }
if ($env:ARM_SUBSCRIPTION_ID) { "ARM_SUBSCRIPTION_ID=SET" } else { "ARM_SUBSCRIPTION_ID=NOT_SET" }
Get-ChildItem -Name
```

### 결과
- Terraform 설치 확인: 성공 (`terraform.exe` 탐지)
- Azure CLI 설치 확인: 성공 (`az.cmd` 탐지)
- 필수 인증 환경변수 상태:
  - `AZDO_PERSONAL_ACCESS_TOKEN=NOT_SET`
  - `ARM_CLIENT_ID=NOT_SET`
  - `ARM_TENANT_ID=NOT_SET`
  - `ARM_SUBSCRIPTION_ID=NOT_SET`

판정: 도구 설치는 완료, 인증 정보 미설정 상태.

## 3) Terraform 초기화/검증

### 실행 명령
```powershell
Set-Location gitops/terraform/azuredevops-bootstrap
if (-not (Test-Path terraform.tfvars)) { Copy-Item terraform.tfvars.example terraform.tfvars }
terraform fmt -check
terraform init -input=false
terraform validate
```

### 결과
- `terraform.tfvars` 생성: 성공 (`terraform.tfvars.example` 복사)
- `terraform init`: 성공
- `terraform validate`: 성공 (`Success! The configuration is valid.`)
- 참고: 첫 실행에서 상대경로 이동이 중복되어 `Set-Location` 경로 오류 1회 발생했으나, 이후 절대경로로 재실행하여 정상 진행함.

판정: IaC 구문/초기화 정상.

## 4) Terraform Plan (실제 생성 전 단계)

### 실행 명령
```powershell
Set-Location C:/Workspace/IWON-vm-lab/gitops/terraform/azuredevops-bootstrap
terraform plan -input=false -out tfplan
```

### 결과
- Plan 계산 도중 Azure DevOps 인증 오류로 실패:

```text
Error: Identity 7b60c72d-19d6-4faf-8d43-258a58f71c97 has not been materialized,
please use interactive login over the browser first.
```

- 종료 코드: 1

판정: 인증 미완료로 실제 리소스 생성 단계 차단.

## 5) 현재 구축 상태 요약

| 항목 | 상태 | 근거 |
|---|---|---|
| GitOps 코드 준비 상태 | 완료 | gitops 내 Terraform/Ansible/Pipeline 파일 확인 |
| Terraform 초기화/검증 | 완료 | `init`, `validate` 성공 |
| Azure DevOps 리소스 생성(Apply) | 미완료 | 인증 오류로 `plan` 단계 실패 |
| GitHub Actions 연동 | 수동 대상 | 요청사항에 따라 미수행 |

## 6) 확인된 핵심 파일

- `gitops/terraform/azuredevops-bootstrap/main.tf`
- `gitops/terraform/azuredevops-bootstrap/variables.tf`
- `gitops/terraform/azuredevops-bootstrap/outputs.tf`
- `gitops/ansible/azure-pipelines-vm.yml`
- `gitops/ansible/deploy-playbook.yml`
- `gitops/scripts/generate_inventory_from_tf.py`

## 7) 차단 해소 후 즉시 실행 명령

아래를 설정하면 이어서 구축 완료 가능:

```powershell
# Azure DevOps PAT
$env:AZDO_PERSONAL_ACCESS_TOKEN = "<ado-pat>"

# Azure RM Service Connection 생성까지 Terraform으로 처리 시
$env:ARM_CLIENT_ID = "<sp-client-id>"
$env:ARM_CLIENT_SECRET = "<sp-client-secret>"
$env:ARM_TENANT_ID = "<tenant-id>"
$env:ARM_SUBSCRIPTION_ID = "<subscription-id>"

Set-Location C:/Workspace/IWON-vm-lab/gitops/terraform/azuredevops-bootstrap
terraform plan -input=false -out tfplan
terraform apply -auto-approve tfplan
```

## 8) 구축 완료 기준

아래 출력 확인 시 구축 완료로 판정:
- `terraform output project_id`
- `terraform output feed_id`
- `terraform output service_connection_id` (옵션 활성화 시)
- `terraform output pipeline_id` (옵션 활성화 시)

`pipeline_id` 값은 GitHub Actions 저장소 시크릿의 `ADO_PIPELINE_ID`로 수동 등록 필요.

## 9) 추가 요청에 따른 plan/apply 재시도 결과

사용자 추가 요청에 따라 인증값 적용 후 실행을 시도하기 위해 현재 세션의 환경변수를 재점검함.

### 실행 명령
```powershell
Set-Location C:/Workspace/IWON-vm-lab/gitops/terraform/azuredevops-bootstrap
Write-Host "AZDO_PERSONAL_ACCESS_TOKEN:" ($(if($env:AZDO_PERSONAL_ACCESS_TOKEN){'SET'}else{'NOT_SET'}))
Write-Host "ARM_CLIENT_ID:" ($(if($env:ARM_CLIENT_ID){'SET'}else{'NOT_SET'}))
Write-Host "ARM_CLIENT_SECRET:" ($(if($env:ARM_CLIENT_SECRET){'SET'}else{'NOT_SET'}))
Write-Host "ARM_TENANT_ID:" ($(if($env:ARM_TENANT_ID){'SET'}else{'NOT_SET'}))
Write-Host "ARM_SUBSCRIPTION_ID:" ($(if($env:ARM_SUBSCRIPTION_ID){'SET'}else{'NOT_SET'}))
```

### 결과
- `AZDO_PERSONAL_ACCESS_TOKEN: NOT_SET`
- `ARM_CLIENT_ID: NOT_SET`
- `ARM_CLIENT_SECRET: NOT_SET`
- `ARM_TENANT_ID: NOT_SET`
- `ARM_SUBSCRIPTION_ID: NOT_SET`

판정: 현재 세션에는 인증값이 적용되지 않아 `terraform plan -> apply`를 진행할 수 없음.

## 10) 1단계(1.3) 재실행 및 프로젝트/피드 생성 완료

사용자와 단계별 검증 방식(한 단계 실행 -> 확인 -> 다음 단계)으로 진행하여, PAT를 동일 세션 명령에 포함해 1.3을 재실행함.

### 실행 명령(요약)
```powershell
$env:AZDO_PERSONAL_ACCESS_TOKEN = "<redacted>"
Set-Location C:/Workspace/IWON-vm-lab/gitops/terraform/azuredevops-bootstrap
terraform init -input=false
terraform validate
terraform plan -input=false -out tfplan
terraform apply -auto-approve tfplan
terraform output
```

### 결과
- `terraform init`: 성공
- `terraform validate`: 성공
- `terraform plan`: 성공
- `terraform apply`: 성공
- 생성 리소스: 2개
  - `azuredevops_project.this[0]` (`iwon-smart-ops`)
  - `azuredevops_feed.this` (`iwon-smart-feed`)

### 출력값
- `project_id = 5ee0e6d6-4048-4f24-aef3-b8643fe57c71`
- `project_name = iwon-smart-ops`
- `feed_id = 358edfde-6c6f-44ae-a0af-b7ea6a24e297`
- `feed_name = iwon-smart-feed`

판정: 신규 프로젝트/피드 생성 완료.

## 11) 1단계(1.3 확장) tfvars 활성화 및 재적용

요청에 따라 `terraform.tfvars`에서 아래 옵션을 활성화해 Service Connection/Pipeline까지 확장 생성을 시도함.

### tfvars 반영 항목
- `create_project = true`
- `create_service_connection = true`
- `service_connection_name = "iwon-smart-ops-sc"`
- `azure_subscription_name = "아이티아이즈-sub-gtm-msp-ktpartners-17"`
- `create_pipeline = true`
- `pipeline_name = "iwon-vm-cd"`
- `gitops_repo_type = "GitHub"`
- `gitops_repo_id = "koasis89/IWON-vm-lab"`
- `gitops_branch = "main"`
- `pipeline_yaml_path = "gitops/ansible/azure-pipelines-vm.yml"`
- `github_service_connection_name = "iwon-github-sc"`

### 1차 시도 결과
- 실패: `github_pat` 미설정으로 GitHub Service Endpoint 생성 차단
- 오류 요약: `auth_personal.personal_access_token` 빈값 불가

### 2차 시도(수정)
- `TF_VAR_github_pat` 환경변수로 GitHub PAT 주입
- `azure_client_secret`은 실행 시점 `-var`로 주입(파일 저장 안 함)

### 실행 명령(요약)
```powershell
$env:AZDO_PERSONAL_ACCESS_TOKEN = "<redacted>"
$env:TF_VAR_github_pat = "<redacted>"
Set-Location C:/Workspace/IWON-vm-lab/gitops/terraform/azuredevops-bootstrap

# SP secret 발급 후 실행시점 주입
$newSecret = az ad app credential reset --id <appId> --append --query password -o tsv
terraform init -input=false
terraform validate
terraform plan -input=false -var "azure_client_secret=$newSecret" -out tfplan
terraform apply -auto-approve -var "azure_client_secret=$newSecret" tfplan
terraform output
```

### 결과
- `terraform apply`: 성공
- 추가 생성 리소스: 4개
  - `azuredevops_serviceendpoint_github.this[0]` (`iwon-github-sc`)
  - `azuredevops_serviceendpoint_azurerm.this[0]` (`iwon-smart-ops-sc`)
  - `azuredevops_build_definition.cd[0]` (`iwon-vm-cd`)
  - `azuredevops_pipeline_authorization.sc_arm[0]`

### 출력값
- `pipeline_id = 2`
- `pipeline_name = iwon-vm-cd`
- `service_connection_id = 29a1593d-c9f6-4c13-a0ff-dbba61aa4b25`
- `service_connection_name = iwon-smart-ops-sc`

판정: 1단계(생성/확장) 완료.

## 12) 2단계(Portal 점검) CLI 대행 검증 결과

Portal 점검 항목을 Azure DevOps CLI로 대행 검증함.

### 실행 명령(요약)
```powershell
$env:AZDO_PERSONAL_ACCESS_TOKEN = "<redacted>"
az devops project show --organization https://dev.azure.com/iteyes-ito --project iwon-smart-ops
az devops service-endpoint list --organization https://dev.azure.com/iteyes-ito --project iwon-smart-ops
az pipelines list --organization https://dev.azure.com/iteyes-ito --project iwon-smart-ops
az pipelines show --organization https://dev.azure.com/iteyes-ito --project iwon-smart-ops --id 2
az pipelines variable-group list --organization https://dev.azure.com/iteyes-ito --project iwon-smart-ops
az devops invoke --organization https://dev.azure.com/iteyes-ito --area distributedtask --resource securefiles --route-parameters project=iwon-smart-ops --api-version 7.1-preview
```

### 결과
- Project 확인: 성공 (`iwon-smart-ops`)
- Service Connections 확인: 성공 (`iwon-github-sc`, `iwon-smart-ops-sc`, 둘 다 Ready)
- Pipeline 확인: 성공 (`iwon-vm-cd`, `id=2`)
- Variable Group: 0개
- Secure Files: 0개

판정: 2단계 핵심 리소스 검증 완료. 운영 배포에 필요한 Secure File/Variable Group은 후속 등록 필요.

## 13) 보안 및 운영 메모

- 실행 중 사용한 민감 환경변수는 완료 후 세션에서 제거함:
  - `AZDO_PERSONAL_ACCESS_TOKEN`
  - `TF_VAR_github_pat`
- `ARM_CLIENT_SECRET`, PAT는 로그/문서에 평문 기록 금지.
- PAT/Secret 노출 이력이 있으므로 운영 전환 전 재발급(rotate) 권장.

## 14) 최신 상태 요약 (2026-04-02 기준)

| 항목 | 상태 | 비고 |
|---|---|---|
| Azure DevOps Project | 완료 | `iwon-smart-ops` |
| Azure Artifacts Feed | 완료 | `iwon-smart-feed` |
| Azure RM Service Connection | 완료 | `iwon-smart-ops-sc` |
| GitHub Service Connection | 완료 | `iwon-github-sc` |
| Azure Pipeline 등록 | 완료 | `iwon-vm-cd` (`pipeline_id=2`) |
| Pipeline Authorization | 완료 | ARM endpoint authorize 완료 |
| Variable Group | 미구성 | 필요 시 추가 |
| Secure Files | 미구성 | SSH 키 등록 필요 |
| GitHub Actions 연동(3단계) | 진행 전 | 저장소 워크플로우/시크릿 반영 필요 |

## 15) 3단계(GitHub 연동) 체크리스트 누적 기록

2단계까지 생성/검증된 ADO 리소스를 기준으로, GitHub 연동 단계(수동 수행 대상) 체크리스트를 동일 형식으로 기록함.

### 입력값(ADO 출력 연계)
- `ADO_ORG = iteyes-ito`
- `ADO_PROJECT = iwon-smart-ops`
- `ADO_PIPELINE_ID = 2`
- `ADO_PAT = <redacted>`

### 3.1 저장소별 워크플로우 파일 반영 체크

대상 저장소(수동 반영):
1. `IWonPaymentWeb`
  - `.github/workflows/deploy-web.yml`
  - `.github/workflows/deploy-was.yml`
2. `IWonPaymentApp`
  - `.github/workflows/deploy-app.yml`
3. `IWonPaymentIntegration`
  - `.github/workflows/deploy-integration.yml`

검증 항목:
- web 산출물은 `*.zip`
- was/app/integration 산출물은 `*.jar`
- Feed publish 이후 ADO Runs API 호출 포함

현재 상태: 미반영(외부 저장소 수동 작업 필요)

### 3.2 GitHub Secrets 등록 체크

각 저장소에 아래 시크릿 등록 필요:
1. `ADO_ORG`
2. `ADO_PROJECT`
3. `ADO_PAT`
4. `ADO_PIPELINE_ID`

검증 항목:
- 저장소별 Actions Secrets 화면에서 4개 키 존재 확인
- `ADO_PIPELINE_ID=2` 값 확인

현재 상태: 미등록(수동 작업 필요)

### 3.3 실행 정책 체크

검증 항목:
1. `main` 브랜치 보호 규칙
2. PR 병합 정책
3. Actions 권한 최소화

현재 상태: 미확인(수동 점검 필요)

## 16) 3단계 완료 판정 기준

아래 3개가 모두 충족되면 3단계 완료로 판정:
1. 3개 저장소에 워크플로우 파일 반영 완료
2. 3개 저장소에 `ADO_ORG/ADO_PROJECT/ADO_PAT/ADO_PIPELINE_ID` 등록 완료
3. 각 저장소에서 `main` 기준 1회 실행 시 Feed publish + ADO Pipeline(`id=2`) 호출 성공

후속 실행 로그가 확보되면 본 리포트에 17번 섹션으로 누적 반영 예정.

## 17) Secure File/Variable Group 정리 반영

요청사항:
- YAML 기본값을 `id_rsa`로 사용
- `iwon-smart-ops-vg`에서 변수로 운영값을 관리

### 파이프라인 반영 내용
- 파일: `gitops/ansible/azure-pipelines-vm.yml`
1. `ANSIBLE_SSH_PRIVATE_KEY_SECURE_FILE` 기본값을 `id_rsa`로 변경
2. Variable Group(`iwon-smart-ops-vg`) 선언을 variables 블록 마지막으로 이동
  - 동일 변수명이 있을 때 Variable Group 값이 기본값을 덮어쓰도록 조정

### 문서 반영 내용
- 파일: `gitops/devops-업무절차서.md` (2.5)
1. Variable Group 권장 변수 목록 명시
  - `ANSIBLE_SSH_PRIVATE_KEY_SECURE_FILE = id_rsa`
  - `AZURE_SERVICE_CONNECTION = iwon-smart-ops-sc`
  - `TFSTATE_RG = <backend-rg>`
  - `TFSTATE_STORAGE = <backend-storage-account>`
2. Secure Files 업로드 파일명(`id_rsa`) 규칙 명시

### 현재 판정
- YAML 기준 기본값/오버라이드 정책 정리 완료
- ADO 포털에서 실제 Secure Files(`id_rsa`) 업로드 및 Variable Group 값 입력은 수동 반영 필요

## 18) 포털 수동 작업 수행 완료 반영 (사용자 확인)

사용자 확인 기준으로 아래 Azure DevOps 포털 작업이 완료됨.

### 완료 항목
1. Secure Files
- `id_rsa` 업로드 완료

2. Variable Group
- `iwon-smart-ops-vg` 생성/설정 완료
- 반영 변수:
  - `AZURE_SERVICE_CONNECTION`
  - `ANSIBLE_SSH_PRIVATE_KEY_SECURE_FILE` (`id_rsa`)
  - `TFSTATE_RG`
  - `TFSTATE_STORAGE`

3. 첫 실행 시 리소스 권한 승인
- Authorize resources 수행 완료

4. 재실행 검증
- `Install SSH private key` 단계 통과 확인 완료

### 상태 업데이트
- 2단계(Portal 점검): 완료
- Secure Files: 구성 완료
- Variable Group: 구성 완료
- SSH 키 설치 단계: 정상 통과

### 후속 권장
1. 파이프라인 Run 로그에서 `DeployByAnsible` 전체 단계 성공 여부 추가 확인
2. `runTerraform=false`/`true` 각 1회씩 실행해 분기별 정상 동작 확인
3. 3단계(GitHub 연동) 진행 시 `ADO_PIPELINE_ID=2` 값으로 REST 호출 검증

## 19) 파이프라인 실행 오류 수정 반영

사용자 재실행 과정에서 아래 오류가 확인됨.

### 오류 내용
`Job TerraformApply: Step input azureSubscription references service connection which could not be found`

### 원인
- Azure DevOps의 `AzureCLI@2` task는 `azureSubscription` 입력을 실행 전 validation 단계에서 해석한다.
- 따라서 변수 참조(`$(AZURE_SERVICE_CONNECTION)`)를 사용하면 service connection 이름을 resolve하지 못하는 경우가 있다.

### 수정 내용
- 파일: `gitops/ansible/azure-pipelines-vm.yml`
- 수정 지점 2곳:
  1. Terraform stage `AzureCLI@2`
  2. Deploy stage `AzureCLI@2`
- 수정 전:
  - `azureSubscription: $(AZURE_SERVICE_CONNECTION)`
- 수정 후:
  - `azureSubscription: iwon-smart-ops-sc`

### 영향
- `AZURE_SERVICE_CONNECTION` 변수는 더 이상 `AzureCLI@2`의 service connection 바인딩에는 사용하지 않음
- Secure File / TFSTATE 관련 Variable Group 변수는 계속 사용 가능

### 현재 판정
- 파이프라인 YAML 수정 완료
- 다음 실행에서 동일 validation 오류는 제거될 것으로 예상

먼저 현재 파이프라인 YAML 상태와 git 상태를 동시에 확인합니다.  

Ran terminal command: git log --oneline -5; git status --short

읽기 [](file:///c%3A/Workspace/IWON-vm-lab/gitops/ansible/azure-pipelines-vm.yml#1-1), 1 줄에서 80 줄까지

git 상태 파악됐습니다. YAML은 이미 원격에 push된 상태이고 `id_rsa` 기본값도 보입니다. 이제 핵심 수정 사항인 `azureSubscription` 하드코딩과 Variable Group 위치를 확인합니다. 

읽기 [](file:///c%3A/Workspace/IWON-vm-lab/gitops/ansible/azure-pipelines-vm.yml#80-80), 80 줄에서 200 줄까지

모든 핵심 수정 사항을 확인했습니다.

**검증 결과 요약:**

| 수정 항목 | 위치 | 현재 상태 |
|---|---|---|
| `ANSIBLE_SSH_PRIVATE_KEY_SECURE_FILE` 기본값 | variables 블록 | ✅ `"id_rsa"` 설정됨 |
| Variable Group 위치 | variables 블록 마지막 | ✅ `- group: iwon-smart-ops-vg`가 모든 variable 정의 이후 |
| `azureSubscription` 하드코딩 (TerraformApply job) | AzureCLI@2 | ✅ `iwon-smart-ops-sc` 하드코딩 |
| `azureSubscription` 하드코딩 (DeployByAnsible job) | AzureCLI@2 | ✅ `iwon-smart-ops-sc` 하드코딩 |
| 원격 반영 여부 | `origin/main` | ✅ `f07c864` 커밋으로 이미 push 완료 |

**현재 미커밋 파일:**
```
M gitops/devops-업무절차서.md
```
이 세션에서 섹션 6을 추가한 업무절차서만 uncommitted 상태입니다. 커밋/푸시가 필요하면 말씀해 주세요.

**파이프라인 재실행 가능 여부:** fix는 이미 `origin/main`에 반영되어 있으므로 바로 재실행 가능합니다.
```powershell
$env:AZDO_PERSONAL_ACCESS_TOKEN="<ado-pat>"
az pipelines run --organization https://dev.azure.com/iteyes-ito --project iwon-smart-ops --id 2 --branch main --output json
```
이전 `azureSubscription references service connection` 오류는 이미 수정되어 있으므로 다음 실패 지점은 `TFSTATE_RG`/`TFSTATE_STORAGE` 미설정 여부일 가능성이 높습니다.

## 6.0 사전 조건 확인 결과

| 항목 | 확인 결과 | 비고 |
|---|---|---|
| ✅ ADO Pipeline ID | **2** | URL `definitionId=2` 확인 |
| ✅ Azure Artifacts Feed | **조회 가능** | `iwon-smart-feed` 정상 접근 |
| ✅ ADO PAT 발급 | **Active** | `iwon-smart-ops` Full access, 만료 2026-06-30 |
| ✅ Service Connection | **Verification Succeeded** | `iwon-smart-ops-sc` isReady=True |
| ✅ 소스 저장소 권한 | **Settings 접근 가능** | GitHub Secrets/Variables 탭 열림 |

모든 사전 조건 **통과**입니다.

---
## 6.0 사전 조건 확인 (착수 전 필수)

| 항목 | 확인 방법 | 기대값 | 결과 |
|---|---|---|---|
| ADO Pipeline ID | URL `definitionId=` 파라미터 확인 | 숫자 (예: 2) | ✅ **2** |
| Azure Artifacts Feed | ADO > Artifacts > iwon-smart-feed | Feed 조회 가능 | ✅ 정상 |
| ADO PAT 발급 | ADO User Settings > Personal Access Tokens | Pipelines R&E + Artifacts R&W | ✅ Full access, Active |
| Service Connection 준비 | Edit > Verify 버튼 클릭 | Verification Succeeded | ✅ iwon-smart-ops-sc |
| 소스 저장소 권한 | GitHub > Settings > Secrets/Variables 접근 | 탭 열림 | ✅ Admin 권한 확인 |

---

## 1. Secure Files — id_rsa 업로드

**경로:** ADO > Pipelines > Library > Secure files

1. `+ Secure file` 클릭
2. `id_rsa` 파일 선택 후 업로드
3. 업로드 완료 후 목록에 `id_rsa` 표시 확인

> ⚠️ 업로드 후 Pipeline permissions 설정 필요 (3단계 참고)

---

## 2. Variable Group 생성 — iwon-smart-ops-vg

**경로:** ADO > Pipelines > Library > Variable groups > `+ Variable group`

### 입력값

| 변수명 | 값 | 비고 |
|---|---|---|
| `ANSIBLE_SSH_PRIVATE_KEY_SECURE_FILE` | `id_rsa` | Secure File 파일명 |
| `AZURE_SERVICE_CONNECTION` | `iwon-smart-ops-sc` | Service Connection 이름 |
| `TFSTATE_RG` | *(실제값 입력)* | Terraform 상태 저장 RG명 |
| `TFSTATE_STORAGE` | *(실제값 입력)* | Terraform 상태 Storage 계정명 |

### 주의사항
- **Pipeline permissions** 탭 → `+` → `iwon-vm-cd` 파이프라인 추가 필수
- 미설정 시 파이프라인 실행 시 Variable Group 접근 불가 에러 발생

---

## 3. Secure File Pipeline 권한 설정

**경로:** ADO > Library > Secure files > `id_rsa` 클릭 > Pipeline permissions 탭

1. `+` 버튼 클릭
2. `iwon-vm-cd` 선택
3. 목록에 `iwon-vm-cd` 표시 확인

---

## 4. Service Connection 권한 설정

**경로:** ADO > Project Settings > Service connections > `iwon-smart-ops-sc` > Edit

- **Security 섹션:** `Grant access permission to all pipelines` ☑ 체크
- `Verify and save` 클릭 → `Verification Succeeded` 확인

> ⚠️ 미체크 시 `azureSubscription references service connection which could not be found` 에러 발생

---

## 5. Pipeline YAML 수정 — azureSubscription 하드코딩

**파일:** `gitops/ansible/azure-pipelines-vm.yml`

### 변경 전 (에러 발생)
```yaml
azureSubscription: $(AZURE_SERVICE_CONNECTION)
```

### 변경 후 (정상 동작)
```yaml
azureSubscription: iwon-smart-ops-sc
```

**수정 위치 2곳:**
1. `TerraformApply` job의 `AzureCLI@2` task
2. `DeployByAnsible` job의 `AzureCLI@2` task

> **원인:** Azure DevOps는 파이프라인 실행 전 validation 단계에서  
> `azureSubscription` 값을 변수로 참조할 경우 resolve하지 못함 (알려진 제한)

---

## 6. Environments 생성

**경로:** ADO > Pipelines > Environments > `Create environment`

| Environment 이름 | 용도 | Resource |
|---|---|---|
| `iwon-gitops-infra` | Terraform Apply 스테이지 | None |
| `iwon-gitops-app` | Artifact Download & VM Deploy 스테이지 | None |

> 첫 파이프라인 실행 시 Permit 승인 필요 (아래 참고)

---

## 7. 파이프라인 첫 실행 — Authorize resources 승인

### 실행 파라미터 (필수값)

| 파라미터 | 값 |
|---|---|
| Run Terraform Apply | `false` (기본값) |
| Ansible deploy target | `was` (기본값) |
| Artifacts feed name | `iwon-smart-feed` |
| Artifacts feed view (maven) | `Release` |
| Maven package definition | `com.iteyes.smart:smart-was` |
| Maven package version | `latest` |
| Downloaded artifact filename pattern | `*.jar` |

### 승인 절차
1. `Run pipeline` → `Next: Resources` → `Run` 클릭
2. Job 실행 후 노란 경고 배너 확인:  
   `"This pipeline needs permission to access a resource..."`
3. `View` 클릭 → Permission 다이얼로그에서 `Permit` 클릭
4. `"Permit access?"` 확인 팝업 → `Permit` 클릭
5. `iwon-gitops-app` Environment에 대한 영구 권한 부여 완료

---

## 8. 알려진 에러 및 해결 방법

### ❌ azureSubscription 에러
```
The pipeline is not valid. Job TerraformApply: Step input azureSubscription 
references service connection which could not be found.
```
**해결:** YAML에서 `$(AZURE_SERVICE_CONNECTION)` → `iwon-smart-ops-sc` 하드코딩

---

### ❌ No hosted parallelism 에러
```
No hosted parallelism has been purchased or granted.
```
**해결 방법 1 (무료, 2~3 영업일):** https://aka.ms/azpipelines-parallelism-request 신청  
**해결 방법 2 (즉시):** Self-hosted Agent 구성 후 YAML 수정
```yaml
# 변경 전
pool:
  vmImage: ubuntu-latest

# 변경 후
pool:
  name: <agent-pool-name>
```

---

## 현재 구성 상태 요약

| 항목 | 상태 |
|---|---|
| Secure File `id_rsa` | ✅ 업로드 완료 |
| Variable Group `iwon-smart-ops-vg` | ✅ 생성 완료 (TFSTATE_RG/STORAGE 입력 필요) |
| Service Connection `iwon-smart-ops-sc` | ✅ Verified, 전체 파이프라인 권한 허용 |
| Environment `iwon-gitops-infra` | ✅ 생성 완료 |
| Environment `iwon-gitops-app` | ✅ 생성 완료, Permit 완료 |
| Pipeline YAML | ✅ azureSubscription 하드코딩 수정 완료 |
| Hosted Parallelism | ❌ 미구성 → 신청 또는 Self-hosted Agent 필요 |


---

**다음 작업 시** 버튼 클릭/입력 동작이 포함된 흐름에서 GIF를 자동 녹화하겠습니다. `TFSTATE_RG`, `TFSTATE_STORAGE` 값 입력이 준비되면 알려주세요!

## 20) TFSTATE 미설정 시 PoC 임시 우회 반영

사용자 선택에 따라 운영용 remote state 구성을 바로 도입하지 않고, `runTerraform=false` 기준 배포 검증이 가능하도록 임시 우회를 추가함.

### 배경
- 현재 `vm-azure`는 `provider.tf` 기준 remote backend(`backend "azurerm"`)가 아직 설정되지 않음
- 따라서 Azure DevOps managed agent에서 `terraform output -json`을 실행하려면 `TFSTATE_RG`, `TFSTATE_STORAGE` 값이 필요하지만, 현재 Variable Group에 실값이 비어 있어 배포 단계가 중단됨

### 우회 방식
- 파일: `gitops/ansible/azure-pipelines-vm.yml`
- 적용 대상: Deploy stage의 `runTerraform=false` 분기

반영 내용:
1. `TFSTATE_RG` 또는 `TFSTATE_STORAGE`가 비어 있으면 `AzureCLI@2` 단계에서 실패하지 않고 warning만 출력
2. Terraform output JSON이 없을 경우 `vm-ansible/inventory.ini`를 정적 inventory fallback으로 사용
3. fallback inventory 복사 후 `ansible_user`, `ansible_ssh_private_key_file` 값은 파이프라인 변수(`ANSIBLE_SSH_USER`, `ANSIBLE_SSH_KEY_PATH`)로 다시 맞춤

### 기대 효과
- PoC 단계에서 remote state 미구성 상태여도 `DownloadPackage -> Ansible deploy` 흐름 검증 가능
- 기존 Terraform output 경로가 준비된 경우에는 기존 동작을 그대로 유지

### 제한 사항
- 이 우회는 `runTerraform=false` 배포 검증용 임시 조치임
- 실제 운영 전환 시에는 반드시 Azure Storage remote backend를 구성하고 `TFSTATE_RG`, `TFSTATE_STORAGE`를 Variable Group에 실값으로 등록해야 함
- `runTerraform=true` 경로는 여전히 backend 구성이 필요함

### 현재 판정
- PoC 임시 우회 YAML 반영 완료
- 다음 파이프라인 실행에서는 TFSTATE 미설정으로 즉시 실패하지 않고 정적 inventory 기반으로 Ansible 배포 단계까지 진행 가능
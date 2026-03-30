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

# Azure DevOps Terraform Bootstrap

This Terraform module creates Azure DevOps resources using the Microsoft Azure DevOps provider (REST API based).

## 리소스 포함 여부

| 리소스 | 포함 여부 | 제어 변수 | 비고 |
|---|---|---|---|
| **Organization** | ❌ 수동 생성 | - | ADO 콘솔에서 별도 생성 후 존재해야 함 |
| **Project** | ✅ 선택 | `create_project` (기본 `false`) | `false` 시 기존 project 참조 |
| **Feed** (Artifacts) | ✅ 항상 | - | `azuredevops_feed.this` — 항상 생성됨 |
| **Service Connection** (Azure RM) | ✅ 선택 | `create_service_connection` (기본 `false`) | SP 인증 방식 |
| **Service Connection** (GitHub) | ✅ 선택 | `create_pipeline && gitops_repo_type == "GitHub"` | Pipeline 등록 시 자동 연동 |
| **Variable Group** | ✅ 선택 | `create_variable_group` (기본 `false`) | CD용 시크릿 변수 그룹 |
| **Environment** | ✅ 선택 | `create_environments` (기본 `false`) | dev/stage/prod |
| **Pipeline** | ✅ 선택 | `create_pipeline` (기본 `false`) | `azure-pipelines-vm.yml` 등록 |

> **수동으로 해야 하는 것**: Organization 생성만 수동 필요.  
> `terraform output pipeline_id` 결과값을 GitHub Secrets `PIPELINE_ID`에 등록해야 자동배포가 동작함.

## Input values (requested baseline)
- ADO_ORG: `iteyes-ito`
- ADO_PROJECT: `iwon-smart-ops`
- ADO_PAT: from environment variable only
- ARTIFACT_FEED_NAME: `iwon-smart-feed`
- UNIVERSAL_PACKAGE_NAME: `iwon-smart-ops-bundle`

## Prerequisites
1. Install Terraform.
2. Export PAT in environment variable:

PowerShell:
```powershell
$env:AZDO_PERSONAL_ACCESS_TOKEN = "<your-pat>"
```

3. (Optional) Set org URL via env var if preferred:

```powershell
$env:AZDO_ORG_SERVICE_URL = "https://dev.azure.com/iteyes-ito"
```

## Usage
```powershell
cd gitops/terraform/azuredevops-bootstrap
Copy-Item terraform.tfvars.example terraform.tfvars
terraform init
terraform plan
terraform apply
```

## Notes
- If the project already exists, keep `create_project = false`.
- If the project does not exist, set `create_project = true`.
- Universal package artifacts are published by CI/CD commands (for example, `az artifacts universal publish`). The provider manages Feed and project resources.
- Variable group includes: AZURE_CLIENT_ID, AZURE_CLIENT_SECRET, AZURE_TENANT_ID, AZURE_SUBSCRIPTION_ID, VM_USER_NAME.
- If you enable prod approval check, fill `prod_approval_approver_ids` with Azure DevOps approver origin IDs.

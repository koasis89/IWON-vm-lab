# Azure DevOps Terraform Bootstrap

This Terraform module creates Azure DevOps resources using the Microsoft Azure DevOps provider (REST API based):
- Azure DevOps Project (optional)
- Azure Artifacts Feed (project scoped)
- Azure DevOps Variable Group for CD pipeline (optional)
- Azure DevOps Environments for dev/stage/prod (optional)
- Production approval check on Environment (optional)

It also keeps the Universal package name as Terraform input/output for pipeline consistency.

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

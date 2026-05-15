# Variable Group Automation Script

This script creates or updates DEV/PROD variable groups in Azure DevOps Library using template key files.

Script:
- devops/scripts/create-variable-groups.py

Templates:
- devops/variable-groups/dev.variable-group.template.yml
- devops/variable-groups/prod.variable-group.template.yml

## Prerequisites

1. Azure CLI installed
2. Azure DevOps extension available (script can auto-add)
3. Logged in:

```bash
az login
az devops login
```

## Secret value convention

Set secrets in environment variables with `VG_SECRET_` prefix and uppercase key.

Examples:

- `DB_APP_PASSWORD` -> `VG_SECRET_DB_APP_PASSWORD`
- `DB_ROOT_PASSWORD` -> `VG_SECRET_DB_ROOT_PASSWORD`
- `DB_ROLLBACK_NOTIFY_WEBHOOK_URL` -> `VG_SECRET_DB_ROLLBACK_NOTIFY_WEBHOOK_URL`

## Usage

```bash
python devops/scripts/create-variable-groups.py \
  --org https://dev.azure.com/<your-org> \
  --project <your-project> \
  --dev-group-name iwon-vm-dev-vg \
  --prod-group-name iwon-vm-prod-vg \
  --authorize
```

Optional:

```bash
python devops/scripts/create-variable-groups.py \
  --org https://dev.azure.com/<your-org> \
  --project <your-project> \
  --secret-keys "DB_APP_PASSWORD,DB_ROOT_PASSWORD,DB_ROLLBACK_NOTIFY_WEBHOOK_URL"
```

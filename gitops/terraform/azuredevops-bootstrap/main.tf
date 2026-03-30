provider "azuredevops" {
  org_service_url = "https://dev.azure.com/${var.ado_org}"
  # personal_access_token is intentionally omitted.
  # Set AZDO_PERSONAL_ACCESS_TOKEN in environment.
}

resource "azuredevops_project" "this" {
  count = var.create_project ? 1 : 0

  name               = var.ado_project
  description        = var.project_description
  visibility         = "private"
  version_control    = "Git"
  work_item_template = "Agile"

  features = {
    boards       = "enabled"
    repositories = "enabled"
    pipelines    = "enabled"
    testplans    = "disabled"
    artifacts    = "enabled"
  }
}

data "azuredevops_project" "existing" {
  count = var.create_project ? 0 : 1
  name  = var.ado_project
}

locals {
  project_id = var.create_project ? azuredevops_project.this[0].id : data.azuredevops_project.existing[0].id
}

resource "azuredevops_feed" "this" {
  name       = var.artifact_feed_name
  project_id = local.project_id

  features {
    permanent_delete = false
    restore          = true
  }
}

resource "azuredevops_variable_group" "cd" {
  count = var.create_variable_group ? 1 : 0

  project_id   = local.project_id
  name         = var.variable_group_name
  description  = "CD variable group managed by Terraform"
  allow_access = true

  variable {
    name  = "AZURE_CLIENT_ID"
    value = var.azure_client_id
  }

  variable {
    name         = "AZURE_CLIENT_SECRET"
    secret_value = var.azure_client_secret
    is_secret    = true
  }

  variable {
    name  = "AZURE_TENANT_ID"
    value = var.azure_tenant_id
  }

  variable {
    name  = "AZURE_SUBSCRIPTION_ID"
    value = var.azure_subscription_id
  }

  variable {
    name  = "VM_USER_NAME"
    value = var.vm_user_name
  }
}

locals {
  environment_map = {
    dev   = var.environment_names.dev
    stage = var.environment_names.stage
    prod  = var.environment_names.prod
  }
}

resource "azuredevops_environment" "cd" {
  for_each = var.create_environments ? local.environment_map : {}

  project_id  = local.project_id
  name        = each.value
  description = "${upper(each.key)} deployment environment managed by Terraform"
}

resource "azuredevops_check_approval" "prod" {
  count = var.create_environments && var.create_prod_approval_check && length(var.prod_approval_approver_ids) > 0 ? 1 : 0

  project_id           = local.project_id
  target_resource_id   = azuredevops_environment.cd["prod"].id
  target_resource_type = "environment"

  requester_can_approve = var.prod_approval_requester_can_approve
  approvers             = var.prod_approval_approver_ids
  timeout               = var.prod_approval_timeout_minutes
  instructions          = "Production deployment approval is required."
}

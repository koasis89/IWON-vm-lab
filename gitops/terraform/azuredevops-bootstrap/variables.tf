variable "ado_org" {
  description = "Azure DevOps organization name (e.g., iteyes-ito)."
  type        = string
  default     = "iteyes-ito"
}

variable "ado_project" {
  description = "Azure DevOps project name."
  type        = string
  default     = "iwon-smart-ops"
}

variable "artifact_feed_name" {
  description = "Azure Artifacts feed name."
  type        = string
  default     = "iwon-smart-feed"
}

variable "universal_package_name" {
  description = "Universal package name to be used by publish pipeline."
  type        = string
  default     = "iwon-smart-ops-bundle"
}

variable "create_project" {
  description = "If true, create the Azure DevOps project. If false, use existing project by name."
  type        = bool
  default     = false
}

variable "project_description" {
  description = "Description used when create_project=true."
  type        = string
  default     = "Managed by Terraform"
}

variable "create_variable_group" {
  description = "If true, create the CD variable group described in gitops plan."
  type        = bool
  default     = false
}

variable "variable_group_name" {
  description = "Azure DevOps variable group name for CD pipeline."
  type        = string
  default     = "iwon-smart-ops-vg"
}

variable "vm_user_name" {
  description = "VM SSH user name stored in variable group."
  type        = string
  default     = ""
}

variable "azure_client_id" {
  description = "Azure service principal client id for Terraform/CD."
  type        = string
  default     = ""
}

variable "azure_tenant_id" {
  description = "Azure tenant id for Terraform/CD."
  type        = string
  default     = ""
}

variable "azure_subscription_id" {
  description = "Azure subscription id for Terraform/CD."
  type        = string
  default     = ""
}

variable "azure_client_secret" {
  description = "Azure service principal client secret for Terraform/CD."
  type        = string
  sensitive   = true
  default     = ""
}

variable "create_environments" {
  description = "If true, create Azure DevOps environments for deployment promotion."
  type        = bool
  default     = false
}

variable "environment_names" {
  description = "Environment names to create in Azure DevOps."
  type = object({
    dev   = string
    stage = string
    prod  = string
  })
  default = {
    dev   = "dev"
    stage = "stage"
    prod  = "prod"
  }
}

variable "create_prod_approval_check" {
  description = "If true, create approval check on prod environment."
  type        = bool
  default     = false
}

variable "prod_approval_approver_ids" {
  description = "Approver origin IDs for prod environment approval check."
  type        = list(string)
  default     = []
}

variable "prod_approval_requester_can_approve" {
  description = "Whether requester can approve prod deployment."
  type        = bool
  default     = false
}

variable "prod_approval_timeout_minutes" {
  description = "Approval timeout in minutes for prod environment check."
  type        = number
  default     = 43200
}

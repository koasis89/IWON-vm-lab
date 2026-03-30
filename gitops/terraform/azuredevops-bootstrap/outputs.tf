output "ado_org_service_url" {
  description = "Azure DevOps organization URL used by provider."
  value       = "https://dev.azure.com/${var.ado_org}"
}

output "project_name" {
  description = "Azure DevOps project name."
  value       = var.ado_project
}

output "project_id" {
  description = "Resolved Azure DevOps project ID."
  value       = local.project_id
}

output "feed_name" {
  description = "Artifacts feed name."
  value       = azuredevops_feed.this.name
}

output "feed_id" {
  description = "Artifacts feed ID."
  value       = azuredevops_feed.this.id
}

output "universal_package_name" {
  description = "Universal package logical name for publish pipelines."
  value       = var.universal_package_name
}

output "variable_group_name" {
  description = "CD variable group name."
  value       = var.create_variable_group ? azuredevops_variable_group.cd[0].name : null
}

output "environment_ids" {
  description = "Created environment IDs keyed by dev/stage/prod."
  value = {
    for k, v in azuredevops_environment.cd : k => v.id
  }
}

output "prod_approval_check_id" {
  description = "Prod approval check ID when enabled."
  value       = length(azuredevops_check_approval.prod) > 0 ? azuredevops_check_approval.prod[0].id : null
}

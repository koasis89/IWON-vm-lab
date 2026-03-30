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

output "service_connection_id" {
  description = "Azure RM service connection ID when enabled."
  value       = length(azuredevops_serviceendpoint_azurerm.this) > 0 ? azuredevops_serviceendpoint_azurerm.this[0].id : null
}

output "service_connection_name" {
  description = "Azure RM service connection name when enabled."
  value       = length(azuredevops_serviceendpoint_azurerm.this) > 0 ? azuredevops_serviceendpoint_azurerm.this[0].service_endpoint_name : null
}

output "pipeline_id" {
  description = "CD pipeline ID when enabled. GitHub Actions REST API 호출 시 PIPELINE_ID로 사용."
  value       = length(azuredevops_build_definition.cd) > 0 ? azuredevops_build_definition.cd[0].id : null
}

output "pipeline_name" {
  description = "CD pipeline display name when enabled."
  value       = length(azuredevops_build_definition.cd) > 0 ? azuredevops_build_definition.cd[0].name : null
}

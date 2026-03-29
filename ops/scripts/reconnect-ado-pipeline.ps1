param(
  [Parameter(Mandatory = $true)]
  [string]$Organization,

  [Parameter(Mandatory = $true)]
  [string]$Project,

  [Parameter(Mandatory = $true)]
  [string]$PipelineName
)

$ErrorActionPreference = 'Stop'

$yamlPath = '/ops/azure-pipelines-vm.yml'

Write-Host "[INFO] Azure DevOps extension check..."
az extension add --name azure-devops --only-show-errors | Out-Null

Write-Host "[INFO] Configure defaults..."
az devops configure --defaults organization=$Organization project=$Project | Out-Null

Write-Host "[INFO] Find pipeline: $PipelineName"
$pipelineId = az pipelines list --query "[?name=='$PipelineName'].id | [0]" -o tsv
if (-not $pipelineId) {
  throw "Pipeline '$PipelineName' not found."
}

Write-Host "[INFO] Update YAML path to $yamlPath"
az pipelines update --id $pipelineId --yaml-path $yamlPath --output table

Write-Host "[DONE] Pipeline reconnected."

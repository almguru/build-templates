[CmdletBinding()]
param(
  [Parameter(Mandatory = $true)]
  [string] $DeploymentOutputsPrefix
)

<#
.SYNOPSIS
Builds legacy deployment output variables from BicepDeploy task outputs.

.DESCRIPTION
Finds BICEPDEPLOY_* environment variables produced by BicepDeploy@0 and publishes
legacy output variables expected by existing template consumers.

.PARAMETER DeploymentOutputsPrefix
Variable prefix used for the legacy output object and nested output variables.
#>

$ErrorActionPreference = "Stop"

function Assert-SafeAzureDevOpsVariableName {
  param(
    [Parameter(Mandatory = $true)]
    [string] $Name
  )

  if ($Name -notmatch '^[A-Za-z0-9_.-]+$') {
    throw "Unsafe Azure DevOps variable name detected: '$Name'. Allowed characters: letters, digits, underscore, dot, hyphen."
  }
}

$internalVariables = @(
  'BICEPDEPLOY_PARAMETERSJSON',
  'BICEPDEPLOY_SUBSCRIPTIONID',
  'BICEPDEPLOY_TENANTID'
)

$outputs = [ordered]@{}
$bicepOutputVariables = Get-ChildItem Env: | Where-Object {
  $_.Name.StartsWith('BICEPDEPLOY_') -and
  -not ($internalVariables -contains $_.Name)
}

foreach ($outputVar in $bicepOutputVariables) {
  $outputName = $outputVar.Name.Substring('BICEPDEPLOY_'.Length).ToLowerInvariant()
  $outputs[$outputName] = @{ value = $outputVar.Value }
}

Write-Host "##[group]Build legacy output variables"
Write-Host "BicepDeploy outputs discovered: $($outputs.Keys -join ', ')"

Assert-SafeAzureDevOpsVariableName -Name $DeploymentOutputsPrefix
$allOutputsJson = $outputs | ConvertTo-Json -Compress -Depth 100
Write-Host "##vso[task.setvariable variable=$DeploymentOutputsPrefix]$allOutputsJson"

foreach ($output in $outputs.GetEnumerator()) {
  $outputName = $output.Key
  $outputValue = $output.Value.value

  $nameVariableName = "$DeploymentOutputsPrefix.$outputName.name"
  $valueVariableName = "$DeploymentOutputsPrefix.$outputName.value"
  Assert-SafeAzureDevOpsVariableName -Name $nameVariableName
  Assert-SafeAzureDevOpsVariableName -Name $valueVariableName

  Write-Host "##vso[task.setvariable variable=$nameVariableName]$outputName"
  Write-Host "##vso[task.setvariable variable=$valueVariableName]$outputValue"
}

Write-Host "##[endgroup]"

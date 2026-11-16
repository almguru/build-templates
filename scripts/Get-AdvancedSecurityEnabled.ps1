[CmdletBinding()]
param()

<#
.SYNOPSIS
Gets Azure Repos Advanced Security enablement.

.DESCRIPTION
Returns false for non-Azure-Repos providers. For Azure Repos, queries the
repository enablement API and returns the Boolean advSecEnabled value. Reads
BUILD_REPOSITORY_PROVIDER, SYSTEM_COLLECTIONURI, SYSTEM_TEAMPROJECT and
BUILD_REPOSITORY_NAME from the pipeline environment; ACCESS_TOKEN must contain
System.AccessToken.
#>

$ErrorActionPreference = 'Stop'

if ($env:BUILD_REPOSITORY_PROVIDER -ne 'TfsGit') {
  Write-Verbose "Repository provider '$($env:BUILD_REPOSITORY_PROVIDER)' is not Azure Repos. Skipping Advanced Security enablement check."
  return $false
}

if ([string]::IsNullOrWhiteSpace($env:ACCESS_TOKEN)) {
  throw 'System.AccessToken is missing. Advanced Security validation cannot continue.'
}
if ([string]::IsNullOrWhiteSpace($env:SYSTEM_TEAMPROJECT) -or [string]::IsNullOrWhiteSpace($env:BUILD_REPOSITORY_NAME)) {
  throw 'Azure DevOps project and repository names are required for the Advanced Security enablement check.'
}

if ($env:SYSTEM_COLLECTIONURI -match 'https://dev\.azure\.com/([^/]+)/') {
  $organizationName = $matches[1]
}
elseif ($env:SYSTEM_COLLECTIONURI -match 'https://([^\.]+)\.visualstudio\.com') {
  $organizationName = $matches[1]
}
else {
  throw 'Unable to determine organization name from CollectionUri.'
}

$headers = @{ Authorization = "Bearer $($env:ACCESS_TOKEN)" }
$projectName = [uri]::EscapeDataString($env:SYSTEM_TEAMPROJECT)
$repositoryName = [uri]::EscapeDataString($env:BUILD_REPOSITORY_NAME)
try {
  $enablement = Invoke-RestMethod `
    -Uri "https://advsec.dev.azure.com/$organizationName/$projectName/_apis/management/repositories/$repositoryName/enablement?api-version=7.2-preview.1" `
    -Method Get `
    -Headers $headers `
    -ContentType 'application/json' `
    -StatusCodeVariable statusCode
}
catch {
  throw "Advanced Security enablement check failed: $($_.Exception.Message)"
}

if ($statusCode -ne 200) {
  throw "Advanced Security enablement check failed with HTTP status $statusCode."
}
if ($null -eq $enablement -or -not $enablement.PSObject.Properties.Name.Contains('advSecEnabled')) {
  throw 'Advanced Security enablement response was missing the advSecEnabled property.'
}
if ($enablement.advSecEnabled -isnot [bool]) {
  throw 'Advanced Security enablement response contained a non-Boolean advSecEnabled value.'
}

return $enablement.advSecEnabled

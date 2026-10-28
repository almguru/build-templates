<#
.SYNOPSIS
    Installs the selected stable Pester runtime for acceptance tests.
.DESCRIPTION
    Resolves latest against PowerShell Gallery, or validates an exact version,
    installs that exact version for the current user, and exports its version
    as the Azure Pipelines runtimePesterVersion variable and completes the
    runtimeResultsArguments used by the shared executor. Failures are terminating.
.PARAMETER Version
    latest (the default, including future stable major releases), or an exact
    stable Pester version, 5 or newer. Prerelease versions are not supported.
.EXAMPLE
    ./Install-PesterRuntime.ps1 -Version latest
#>
[CmdletBinding()]
param(
    [string]$Version = 'latest'
)

$ErrorActionPreference = 'Stop'
$findArguments = @{
    Name = 'Pester'
    Repository = 'PSGallery'
    ErrorAction = 'Stop'
}
if ($Version -ne 'latest') {
    if ($Version -notmatch '^\d+\.\d+\.\d+(\.\d+)?$' -or ([version]$Version).Major -lt 5) {
        throw "Invalid Pester version '$Version'. Use 'latest' or an exact stable version, 5 or newer."
    }
    $findArguments.RequiredVersion = $Version
}

# Find-Module excludes prereleases unless AllowPrerelease is explicitly requested.
$module = Find-Module @findArguments
$resolvedVersion = [version]$module.Version
if ($resolvedVersion.Major -lt 5) {
    throw "Pester 5 or newer is required; Gallery returned $resolvedVersion."
}
if ($Version -ne 'latest' -and $resolvedVersion -ne [version]$Version) {
    throw "Requested Pester $Version but Gallery returned $resolvedVersion."
}
Install-Module -Name Pester -RequiredVersion $resolvedVersion -Repository PSGallery `
    -Scope CurrentUser -Force -AllowClobber -ErrorAction Stop
Write-Host "Using Pester $resolvedVersion"
Write-Host "##vso[task.setvariable variable=runtimePesterVersion]$resolvedVersion"
Write-Host "##vso[task.setvariable variable=runtimeResultsArguments]NUnitXml $resolvedVersion"

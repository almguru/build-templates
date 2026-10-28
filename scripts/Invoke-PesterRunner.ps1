<#
.SYNOPSIS
    Runs one Pester test file within the calling PowerShell process.
.DESCRIPTION
    Adapts the shared test executor's positional arguments to Pester configuration.
    Keeps the caller's Azure CLI authentication environment and writes a unique
    NUnit report before returning an exit code to the executor. Exit code 11
    indicates a filtered-out file; configure the executor's NoTestsExitCode to 11.
.PARAMETER TestFile
    Test script selected by Invoke-TestRunner.ps1.
.PARAMETER OutputFormat
    Report format. NUnitXml is supported for Azure DevOps NUnit publishing.
.PARAMETER RequiredVersion
    Exact installed Pester version selected during runtime setup (5 or newer).
.PARAMETER ResultsDirectory
    Directory for per-file *.pester.xml reports.
.PARAMETER RunnerArguments
    Pester options: -TagFilter, -ExcludeTagFilter, -FullNameFilter, -ExcludePath,
    and -Output. Tag values may be repeated or comma-separated; other filters
    accept separate literal values.
.EXAMPLE
    ./Invoke-PesterRunner.ps1 ./Api.Tests.ps1 NUnitXml 6.2.0 ./results -RunnerArguments @('-TagFilter', 'Smoke')
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory, Position = 0)]
    [string]$TestFile,

    [Parameter(Mandatory, Position = 1)]
    [ValidateSet('NUnitXml')]
    [string]$OutputFormat,

    [Parameter(Mandatory, Position = 2)]
    [version]$RequiredVersion,

    [Parameter(Mandatory, Position = 3)]
    [string]$ResultsDirectory,

    [Parameter(Position = 4, ValueFromRemainingArguments)]
    [string[]]$RunnerArguments = @()
)

$ErrorActionPreference = 'Stop'
if ($RequiredVersion.Major -lt 5) {
    throw 'Pester 5 or newer is required.'
}

$options = @{
    TagFilter = @()
    ExcludeTagFilter = @()
    FullNameFilter = @()
    ExcludePath = @()
    Output = @()
}
$currentOption = $null
$needsValue = $false
foreach ($argument in $RunnerArguments) {
    if ($argument.StartsWith('-')) {
        if ($needsValue) {
            throw "Pester option -$currentOption requires a value."
        }
        $currentOption = $argument.TrimStart('-')
        if (-not $options.ContainsKey($currentOption)) {
            throw "Unsupported Pester option '$argument'. Supported options: -TagFilter, -ExcludeTagFilter, -FullNameFilter, -ExcludePath, -Output. Test paths, reports, and process lifetime are controlled by the acceptance-test template."
        }
        $needsValue = $true
    }
    elseif ($null -eq $currentOption) {
        throw "Expected a Pester option before '$argument'."
    }
    else {
        $values = if ($currentOption -in @('TagFilter', 'ExcludeTagFilter')) {
            $argument -split ','
        }
        else {
            @($argument)
        }
        if (@($values | Where-Object { [string]::IsNullOrWhiteSpace($_) }).Count -gt 0) {
            throw "Pester option -$currentOption requires nonempty values."
        }
        $options[$currentOption] += $values
        $needsValue = $false
    }
}
if ($needsValue) {
    throw "Pester option -$currentOption requires a value."
}
if ($options.Output.Count -gt 1 -or
    ($options.Output.Count -eq 1 -and $options.Output[0] -notin @('None', 'Minimal', 'Normal', 'Detailed', 'Diagnostic'))) {
    throw 'Pester -Output requires one of: None, Minimal, Normal, Detailed, Diagnostic.'
}

Import-Module Pester -RequiredVersion $RequiredVersion -Force -ErrorAction Stop
$configuration = New-PesterConfiguration
$configuration.Run.Path = @((Resolve-Path -LiteralPath $TestFile).Path)
foreach ($excludePath in $options.ExcludePath) {
    if ($configuration.Run.Path.Value[0].Replace('\', '/') -like $excludePath.Replace('\', '/')) {
        Write-Host "Pester file excluded by -ExcludePath: $TestFile"
        exit 11
    }
}
$configuration.Run.PassThru = $true
$configuration.Run.Exit = $false
$configuration.Run.Throw = $false
$configuration.Run.ExcludePath = @($options.ExcludePath | ForEach-Object { $_.Replace('\', '/') })
$configuration.Filter.Tag = $options.TagFilter
$configuration.Filter.ExcludeTag = $options.ExcludeTagFilter
$configuration.Filter.FullName = $options.FullNameFilter
if ($options.Output.Count -eq 1) {
    $configuration.Output.Verbosity = $options.Output[0]
}

$null = New-Item -ItemType Directory -Path $ResultsDirectory -Force
$pathBytes = [System.Text.Encoding]::UTF8.GetBytes($configuration.Run.Path.Value[0])
$pathHash = [Convert]::ToHexString([System.Security.Cryptography.SHA256]::HashData($pathBytes))
$configuration.TestResult.Enabled = $true
$configuration.TestResult.OutputFormat = $OutputFormat
$configuration.TestResult.OutputPath = Join-Path $ResultsDirectory "$pathHash.pester.xml"

$result = Invoke-Pester -Configuration $configuration
if ($null -eq $result -or $result.Result -eq 'Failed' -or $result.FailedCount -gt 0 -or
    $result.FailedContainersCount -gt 0 -or $result.FailedBlocksCount -gt 0) {
    Write-Host "##vso[task.logissue type=error]Pester failed or executed no tests in '$TestFile'."
    exit 1
}
if (($result.PassedCount + $result.FailedCount) -eq 0) {
    if ($result.TotalCount -gt 0 -and
        ($options.TagFilter.Count -gt 0 -or $options.ExcludeTagFilter.Count -gt 0 -or $options.FullNameFilter.Count -gt 0)) {
        Write-Host "Pester filters selected no tests in '$TestFile'."
        exit 11
    }
    Write-Host "##vso[task.logissue type=error]Pester executed no tests in '$TestFile'."
    exit 1
}
exit 0

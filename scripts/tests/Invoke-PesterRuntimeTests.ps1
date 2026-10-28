<#
.SYNOPSIS
    Exercises the acceptance-test executor and Pester runtime without Azure resources.
.DESCRIPTION
    Uses temporary fixtures to check real execution, NUnit reports, option forwarding,
    inherited context, and .NET-style runner arguments. Stubs Gallery commands to
    verify version selection and error handling without extra network installations.
.PARAMETER PesterVersion
    Exact installed Pester version to exercise. Defaults to the highest installed version.
.EXAMPLE
    ./scripts/tests/Invoke-PesterRuntimeTests.ps1 -PesterVersion 6.2.0
#>
[CmdletBinding()]
param(
    [string]$PesterVersion = (Get-Module -ListAvailable Pester |
        Sort-Object Version -Descending | Select-Object -First 1).Version.ToString()
)

$ErrorActionPreference = 'Stop'
$scriptsPath = Split-Path $PSScriptRoot -Parent
$executor = Join-Path $scriptsPath 'Invoke-TestRunner.ps1'
$adapter = Join-Path $scriptsPath 'Invoke-PesterRunner.ps1'
$installer = Join-Path $scriptsPath 'Install-PesterRuntime.ps1'
$root = Join-Path ([IO.Path]::GetTempPath()) "pester-runtime-$([guid]::NewGuid())"
$oldEnvironment = @{}
foreach ($name in @('PESTER_EXPECTED_PID', 'PESTER_EXPECTED_VERSION', 'AZURE_CONFIG_DIR', 'PESTER_EXPECTED_CONFIG', 'RUNNER_CAPTURE', 'ALMGURU_TEST_RUNNER_ARGUMENTS', 'PESTER_CONTEXT_VALUE', 'PESTER_CONTEXT_VERSION')) {
    $oldEnvironment[$name] = [Environment]::GetEnvironmentVariable($name)
}
$checks = 0

function Assert-True {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) { throw $Message }
}

function Write-Fixture {
    param([string]$Name, [string]$Content)
    $path = Join-Path $root $Name
    $null = New-Item -ItemType Directory -Path (Split-Path $path -Parent) -Force
    Set-Content -LiteralPath $path -Value $Content
    return $path
}

function Invoke-Case {
    param(
        [string]$Pattern,
        [string]$Arguments = '',
        [int]$ExpectedExit = 0,
        [string]$ExpectedError = '',
        [string]$Command = $adapter,
        [string]$ReportArguments = "NUnitXml $PesterVersion"
    )
    $results = Join-Path $root "results-$checks"
    $global:LASTEXITCODE = 0
    $caught = $null
    try {
        $output = & $executor -SearchPath (Join-Path $root 'input') -FilePattern $Pattern `
            -ResultsDirectory $results -AdditionalArguments $Arguments `
            -TestRunnerCommand $Command -TestResultsArguments $ReportArguments -NoTestsExitCode 11 6>&1
    }
    catch {
        $caught = $_
    }
    if ($ExpectedError) {
        Assert-True ($null -ne $caught -and "$caught" -like "*$ExpectedError*") "Expected error '$ExpectedError'; got '$caught'."
    }
    else {
        if ($caught) { throw $caught }
        Assert-True ($LASTEXITCODE -eq $ExpectedExit) "Expected exit $ExpectedExit, got $LASTEXITCODE for $Pattern $Arguments. Output: $output"
    }
    $script:checks++
    return $results
}

try {
    $null = New-Item -ItemType Directory -Path $root
    $env:PESTER_EXPECTED_PID = "$PID"
    $env:PESTER_EXPECTED_VERSION = $PesterVersion
    $env:AZURE_CONFIG_DIR = Join-Path $root 'Azure CLI context'
    $env:PESTER_EXPECTED_CONFIG = $env:AZURE_CONFIG_DIR
    $passing = @'
Describe 'Runtime context' {
    It 'keeps the authenticated host context' -Tag Smoke {
        $PID | Should -Be ([int]$env:PESTER_EXPECTED_PID)
        $env:AZURE_CONFIG_DIR | Should -Be $env:PESTER_EXPECTED_CONFIG
        (Get-Command Invoke-Pester).Module.Version.ToString() | Should -Be $env:PESTER_EXPECTED_VERSION
    }
    It 'supports another tag' -Tag Slow { 1 | Should -Be 1 }
}
'@
    $null = Write-Fixture 'input/Root.Tests.ps1' $passing
    $null = Write-Fixture 'input/nested directory/Root.Tests.ps1' $passing
    $results = Invoke-Case '**/*.Tests.ps1'
    $reports = @(Get-ChildItem -LiteralPath $results -Filter '*.pester.xml')
    Assert-True ($reports.Count -eq 2) 'Expected distinct root/nested reports for identical basenames.'
    foreach ($report in $reports) {
        [xml]$xml = Get-Content -LiteralPath $report.FullName -Raw
        Assert-True ($xml.DocumentElement.LocalName -eq 'test-results') 'Expected NUnit 2 XML.'
        Assert-True ([int]$xml.'test-results'.total -eq 2) 'Expected both tests in each report.'
    }

    $null = Invoke-Case '**/*.Tests.ps1' '-TagFilter Smoke,Slow -ExcludeTagFilter Slow -Output Detailed'
    $null = Invoke-Case '**/*.Tests.ps1' '-TagFilter Smoke -TagFilter Slow -Output Minimal'
    $null = Invoke-Case '**/*.Tests.ps1' '-FullNameFilter "Runtime context.keeps the authenticated host context"'
    $null = Invoke-Case '**/*.Tests.ps1' "-FullNameFilter 'Runtime context.keeps the authenticated host context'"
    $null = Invoke-Case '**/*.Tests.ps1' '-FullNameFilter "Runtime context.missing name"' -ExpectedExit 11
    $null = Invoke-Case '**/*.Tests.ps1' '-TagFilter Missing' -ExpectedExit 11
    $null = Invoke-Case 'Root.Tests.ps1' '-ExcludePath "**/Root.Tests.ps1"' -ExpectedExit 11
    $null = Invoke-Case 'Root.Tests.ps1' '-ExcludePath "**\Root.Tests.ps1"' -ExpectedExit 11
    $null = Invoke-Case '**/*.Tests.ps1' '-ExcludePath "**/nested directory/*" -Output Minimal'
    $null = Invoke-Case '**/*.Tests.ps1' '-ExcludePath "**\nested directory\*" -Output Minimal'
    $null = Invoke-Case 'Root.Tests.ps1' '-Configuration arbitrary' -ExpectedError 'Unsupported Pester option'
    $null = Invoke-Case 'Root.Tests.ps1' '-TagFilter' -ExpectedError 'requires a value'
    $null = Invoke-Case 'Root.Tests.ps1' '-TagFilter Smoke -TagFilter -Output Minimal' -ExpectedError 'requires a value'
    $null = Invoke-Case 'Root.Tests.ps1' '-Output Loud' -ExpectedError 'Pester -Output requires'
    $null = Invoke-Case 'Root.Tests.ps1' '-TagFilter Smoke,,Slow' -ExpectedError 'requires nonempty values'
    $null = Invoke-Case 'Root.Tests.ps1' '-FullNameFilter "unterminated' -ExpectedError 'Unterminated quote'
    $null = Invoke-Case 'Root.Tests.ps1' -ReportArguments 'NUnitXml 99.0.0' -ExpectedError 'no valid module'
    $null = Invoke-Case 'Missing.Tests.ps1' -ExpectedExit 10
    $null = Invoke-Case 'Root.Tests.ps1' -ReportArguments 'NUnitXml 4.10.1' -ExpectedError 'Pester 5 or newer'

    $wrapper = Write-Fixture 'Task-Wrapper.ps1' @'
param($ScriptsPath, $FixtureRoot, $PesterVersion)
$env:PESTER_EXPECTED_PID = "$PID"
& "$ScriptsPath/Invoke-TestRunner.ps1" -SearchPath "$FixtureRoot/input" `
    -FilePattern "**/*.Tests.ps1" -ResultsDirectory "$FixtureRoot/wrapper results" `
    -AdditionalArguments $env:ALMGURU_TEST_RUNNER_ARGUMENTS `
    -TestRunnerCommand "$ScriptsPath/Invoke-PesterRunner.ps1" `
    -TestResultsArguments "NUnitXml $PesterVersion" -NoTestsExitCode 11
exit $LASTEXITCODE
'@
    $env:ALMGURU_TEST_RUNNER_ARGUMENTS = '-TagFilter Smoke -FullNameFilter "Runtime context.keeps the authenticated host context"'
    $wrapperOutput = & pwsh -NoProfile -File $wrapper -ScriptsPath $scriptsPath -FixtureRoot $root -PesterVersion $PesterVersion 6>&1
    Assert-True ($LASTEXITCODE -eq 0) "Task-style environment argument transport failed: $wrapperOutput"
    Assert-True (@(Get-ChildItem -LiteralPath (Join-Path $root 'wrapper results') -Filter '*.pester.xml').Count -eq 2) 'Task wrapper must run both files.'
    $checks++

    $env:PESTER_CONTEXT_VALUE = 'pipeline context'
    $env:PESTER_CONTEXT_VERSION = $PesterVersion
    $pipelineFixture = Get-Content -LiteralPath (Join-Path $scriptsPath '../src/Pester.Acceptance.Tests/Context.Tests.ps1') -Raw
    $null = Write-Fixture 'input/pipeline/Context.Tests.ps1' $pipelineFixture
    $results = Invoke-Case 'pipeline/*.Tests.ps1' '-TagFilter Smoke -ExcludeTagFilter Slow -FullNameFilter "Acceptance runtime.*" -Output Detailed'
    $pipelineReport = Get-ChildItem -LiteralPath $results -Filter '*.pester.xml' | Select-Object -First 1
    [xml]$xml = Get-Content -LiteralPath $pipelineReport.FullName -Raw
    Assert-True ($xml.SelectNodes('//test-case[@result="Success"]').Count -eq 2) 'Pipeline fixture must report exactly two passing Smoke tests.'

    $null = Write-Fixture 'input/failing/Failure.Tests.ps1' "Describe 'Failure' { It 'fails' { 1 | Should -Be 2 } }"
    $null = Write-Fixture 'input/discovery/Broken.Tests.ps1' "throw 'Discovery fixture failure'"
    $null = Write-Fixture 'input/empty/Empty.Tests.ps1' "Describe 'Empty' {}"
    $null = Write-Fixture 'input/tagged/Slow.Tests.ps1' "Describe 'Slow only' { It 'is slow' -Tag Slow { 1 | Should -Be 1 } }"
    $null = Invoke-Case '**/*.Tests.ps1' '-TagFilter Smoke -ExcludePath "**/failing/*" "**/discovery/*" "**/empty/*"'
    $null = Invoke-Case 'failing/*.Tests.ps1' -ExpectedExit 1
    $null = Invoke-Case 'discovery/*.Tests.ps1' -ExpectedExit 1
    $null = Invoke-Case 'empty/*.Tests.ps1' -ExpectedExit 1
    $null = Invoke-Case 'empty/*.Tests.ps1' '-TagFilter Smoke' -ExpectedExit 1
    $results = Invoke-Case '**/*.Tests.ps1' -ExpectedExit 1
    Assert-True (@(Get-ChildItem -LiteralPath $results -Filter '*.pester.xml').Count -eq 7) 'Execution must continue after failing files.'

    $env:RUNNER_CAPTURE = Join-Path $root 'captured.json'
    $capture = Write-Fixture 'Capture-Runner.ps1' @'
param(
    [Parameter(Position=0)] [string]$TestFile,
    [Parameter(Position=1, ValueFromRemainingArguments)] [string[]]$Values
)
@{ File = $TestFile; Values = $Values } | ConvertTo-Json | Set-Content -LiteralPath $env:RUNNER_CAPTURE
exit 0
'@
    $null = Write-Fixture 'input/bin/Sample.Tests.dll' ''
    $results = Invoke-Case '**/*.Tests.dll' '--filter "Category=Smoke Test" --literal $(not-executed)' `
        -Command $capture -ReportArguments '--report-trx --results-directory'
    $captured = Get-Content -LiteralPath $env:RUNNER_CAPTURE -Raw | ConvertFrom-Json
    Assert-True (($captured.Values -join '|') -eq "--report-trx|--results-directory|$results|--filter|Category=Smoke Test|--literal|`$(not-executed)") 'Runner arguments must be literal and preserve order/quoting.'
    $null = Invoke-Case '**\*.Tests.dll' -Command $capture -ReportArguments '--report-trx --results-directory'
    $null = Invoke-Case '**/*[Tt]ests.dll' -Command $capture -ReportArguments '--report-trx --results-directory'
    $null = Invoke-Case 'bin/[A-Z]ample.Tests.dll' -Command $capture -ReportArguments '--report-trx --results-directory'
    $null = Invoke-Case 'bin/[Ss]ample.[Tt]ests.dll' -Command $capture -ReportArguments '--report-trx --results-directory'
    $null = Invoke-Case '**/*[Xx]ests.dll' -ExpectedExit 10 -Command $capture -ReportArguments '--report-trx --results-directory'

    $nativeInput = Write-Fixture 'input/native/Native.Tests.ps1' @'
param([Parameter(ValueFromRemainingArguments)] [string[]]$Values)
$Values | ConvertTo-Json | Set-Content -LiteralPath $env:RUNNER_CAPTURE
exit 0
'@
    $null = Invoke-Case 'native/*.Tests.ps1' '--filter "Category=Smoke Test"' `
        -Command 'pwsh' -ReportArguments '--report-trx --results-directory'
    $nativeArguments = @(Get-Content -LiteralPath $env:RUNNER_CAPTURE -Raw | ConvertFrom-Json)
    Assert-True ($nativeArguments[0] -eq '--report-trx' -and $nativeArguments[-1] -eq 'Category=Smoke Test') 'Native executables must retain argument boundaries.'

    $installation = @{ Requested = $null; Installed = $null; Available = '6.2.0'; FailLookup = $false; FailInstall = $false }
    function Find-Module {
        [CmdletBinding()]
        param($Name, $Repository, $RequiredVersion)
        if ($installation.FailLookup) { throw 'Fixture Gallery lookup failure' }
        Assert-True (-not $PSBoundParameters.ContainsKey('AllowPrerelease')) 'Must not request prereleases.'
        $installation.Requested = $RequiredVersion
        [pscustomobject]@{ Version = $installation.Available }
    }
    function Install-Module {
        [CmdletBinding()]
        param($Name, $RequiredVersion, $Repository, $Scope, [switch]$Force, [switch]$AllowClobber)
        if ($installation.FailInstall) { throw 'Fixture install failure' }
        Assert-True ($Scope -eq 'CurrentUser') 'Installation must be scoped to current user.'
        $installation.Installed = "$RequiredVersion"
    }
    $setupOutput = & $installer -Version latest 6>&1
    Assert-True ($null -eq $installation.Requested -and $installation.Installed -eq '6.2.0') 'latest must use the Gallery stable release.'
    Assert-True (($setupOutput -join "`n").Contains('##vso[task.setvariable variable=runtimeResultsArguments]NUnitXml 6.2.0')) 'Setup must pass the resolved version to the executor after installation.'
    $installation.Available = '7.0.0'
    $null = & $installer -Version latest 6>&1
    Assert-True ($installation.Installed -eq '7.0.0') 'latest must follow future stable major versions.'
    $installation.Available = '5.7.1'
    $null = & $installer -Version 5.7.1 6>&1
    Assert-True ($installation.Requested -eq '5.7.1' -and $installation.Installed -eq '5.7.1') 'Exact version overrides must be honored.'
    foreach ($invalidVersion in @('4.10.1', '6.x', '6.2.0-preview1', 'invalid')) {
        $caught = $null
        try { $null = & $installer -Version $invalidVersion 6>&1 } catch { $caught = $_ }
        Assert-True ("$caught" -like '*Invalid Pester version*') "Expected version validation for $invalidVersion."
    }
    $installation.Available = '6.2.0'
    $caught = $null
    try { $null = & $installer -Version 5.7.1 6>&1 } catch { $caught = $_ }
    Assert-True ("$caught" -like '*Gallery returned*') 'Must reject an incorrect resolved version.'
    foreach ($failure in @('FailLookup', 'FailInstall')) {
        $installation[$failure] = $true
        $caught = $null
        try { $null = & $installer -Version latest 6>&1 } catch { $caught = $_ }
        Assert-True ("$caught" -like '*Fixture*failure*') "Must surface $failure without fallback."
        $installation[$failure] = $false
    }
    Write-Host "Passed $checks executor/adapter cases, report/context assertions, and version-selection cases (Pester $PesterVersion)."
}
finally {
    foreach ($name in $oldEnvironment.Keys) {
        [Environment]::SetEnvironmentVariable($name, $oldEnvironment[$name])
    }
    if (Test-Path -LiteralPath $root) { Remove-Item -LiteralPath $root -Recurse -Force }
}

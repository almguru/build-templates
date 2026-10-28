<#
.SYNOPSIS
    Invokes test runners against test assemblies found in artifact directories.

.DESCRIPTION
    This script searches for test files matching a specified pattern in an artifact directory
    and executes them using a configured test runner. It supports various test runners and
    provides comprehensive test execution results. The script is designed to work within
    Azure DevOps pipelines but can be used standalone.

.PARAMETER SearchPath
    The root directory path where test files will be searched. This can be any directory
    containing test assemblies, not limited to Azure DevOps artifacts.

.PARAMETER FilePattern
    A glob pattern used to match test files. Supports Azure Pipelines glob patterns like
    '**/*.dll' or '**/bin/**/*Tests.dll'. The pattern is converted to PowerShell-compatible
    format automatically.

.PARAMETER ResultsDirectory
    The directory where test results will be stored. This value is automatically passed as an argument
    to the test runner after the TestResultsArguments, so the test runner receives the results directory
    as a command-line parameter.

.PARAMETER AdditionalArguments
    Optional additional arguments to pass to the test runner. These arguments will be appended
    to the test runner command for each test file. Single or double quotes group values
    containing spaces. Arguments are parsed as literal strings, never evaluated.

.PARAMETER TestRunnerCommand
    The command or executable name of the test runner to use. Supported test runners include:
    - 'vstest.console.exe' (Microsoft Test Platform)
    - 'xunit.console.exe' (xUnit v3)
    - 'dotnet' (for .NET projects)
    - 'nunit3-console.exe' (NUnit)

.PARAMETER TestResultsArguments
    Arguments specific to configuring test result output for the test runner. These arguments are
    passed first, followed by the ResultsDirectory as the next argument. Examples:
    - Microsoft Test Platform: '--logger:trx --ResultsDirectory:'
    - xUnit v3: '--reporter trx --output'
    - dotnet test: 'test --logger trx --results-directory'

.PARAMETER NoTestsExitCode
    Optional runner exit code indicating a file was filtered out. Such files do not
    fail a suite containing executed tests; a suite where every file is filtered
    out still fails. Defaults to -1 (disabled).

.EXAMPLE
    .\Invoke-TestRunner.ps1 -SearchPath "C:\build\output" -FilePattern "**/*Tests.dll" -ResultsDirectory "C:\TestResults" -TestRunnerCommand "vstest.console.exe" -TestResultsArguments "--logger:trx --ResultsDirectory:"

    Runs Microsoft Test Platform on all *Tests.dll files found in the C:\build\output directory.
    The actual command executed will be: vstest.console.exe [TestFile] --logger:trx --ResultsDirectory: C:\TestResults

.EXAMPLE
    .\Invoke-TestRunner.ps1 -SearchPath ".\bin\Release" -FilePattern "**/UnitTests.dll" -ResultsDirectory ".\results" -TestRunnerCommand "xunit.console.exe" -TestResultsArguments "--reporter trx --output"

    Runs xUnit v3 console on UnitTests.dll files.
    The actual command executed will be: xunit.console.exe [TestFile] --reporter trx --output .\results

.NOTES
    Author: Vladimir Gusarov
    Version: 1.2
    
    This script is designed to work with Azure DevOps build pipelines but can be used
    independently. It handles multiple test assemblies and aggregates exit codes to
    provide an overall test execution status.
    
    Command Construction Order:
    TestRunnerCommand [TestFile] [TestResultsArguments] [ResultsDirectory] [AdditionalArguments]
    
    Exit codes:
    - 0: All tests passed
    - Non-zero: One or more test assemblies failed (returns the first non-zero exit code)
    - 10: No files matched the pattern or were found

.LINK
    https://docs.microsoft.com/en-us/azure/devops/pipelines/
#>

[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory = $true, HelpMessage = "Root directory path where test files will be searched")]
    [ValidateNotNullOrEmpty()]
    [string]$SearchPath,
    
    [Parameter(Mandatory = $true, HelpMessage = "Glob pattern to match test files (e.g., '**/*.dll')")]
    [ValidateNotNullOrEmpty()]
    [string]$FilePattern,
    
    [Parameter(Mandatory = $true, HelpMessage = "Directory where test results will be stored")]
    [ValidateNotNullOrEmpty()]
    [string]$ResultsDirectory,
    
    [Parameter(Mandatory = $false, HelpMessage = "Additional arguments to pass to the test runner")]
    [string]$AdditionalArguments = "",
    
    [Parameter(Mandatory = $true, HelpMessage = "Test runner command or executable name")]
    [ValidateNotNullOrEmpty()]
    [string]$TestRunnerCommand,
    
    [Parameter(Mandatory = $true, HelpMessage = "Test results format and output arguments for the test runner")]
    [ValidateNotNullOrEmpty()]
    [string]$TestResultsArguments,

    [ValidateScript({ $_ -eq -1 -or $_ -gt 0 })]
    [int]$NoTestsExitCode = -1
)

$ErrorActionPreference = 'Stop'

function ConvertTo-RunnerArguments {
    param([string]$ArgumentString)

    $value = [System.Text.StringBuilder]::new()
    $quote = $null
    $started = $false
    foreach ($character in $ArgumentString.ToCharArray()) {
        if ($null -ne $quote) {
            if ($character -eq $quote) {
                $quote = $null
            }
            else {
                $null = $value.Append($character)
            }
        }
        elseif ($character -eq '"' -or $character -eq "'") {
            $quote = $character
            $started = $true
        }
        elseif ([char]::IsWhiteSpace($character)) {
            if ($started) {
                $value.ToString()
                $null = $value.Clear()
                $started = $false
            }
        }
        else {
            $null = $value.Append($character)
            $started = $true
        }
    }
    if ($null -ne $quote) {
        throw 'Unterminated quote in test runner arguments.'
    }
    if ($started) {
        $value.ToString()
    }
}

$testArguments = @()
$testArguments += @(ConvertTo-RunnerArguments $TestResultsArguments)
$testArguments += $ResultsDirectory
if (![string]::IsNullOrWhiteSpace($AdditionalArguments)) {
    $testArguments += @(ConvertTo-RunnerArguments $AdditionalArguments)
}

function Find-TestFiles {
    param(
        [string]$SearchPath,
        [string]$FilePattern
    )

    $SearchPath = (Resolve-Path -LiteralPath $SearchPath).Path
    $FilePattern = $FilePattern.Replace('\', '/')
    $hasWildcard = $FilePattern -match '[*?\[]'
    if ($hasWildcard) {
        Write-Verbose "Searching for files matching pattern: $FilePattern in $SearchPath"

        # A globstar includes zero directories, unlike a required slash after '*'.
        $pattern = [regex]::Replace($FilePattern, '\[[^\]]+\]|\*\*/|\*\*|\*|\?|.', {
            param($token)
            switch ($token.Value) {
                '**/' { '(?:.*/)?' }
                '**' { '.*' }
                '*' { '[^/]*' }
                '?' { '[^/]' }
                default {
                    if ($token.Value.StartsWith('[') -and $token.Value.EndsWith(']')) {
                        '[' + [regex]::Escape($token.Value.Substring(1, $token.Value.Length - 2)) + ']'
                    }
                    else {
                        [regex]::Escape($token.Value)
                    }
                }
            }
        })
        $files = Get-ChildItem -LiteralPath $SearchPath -Recurse -File | Where-Object {
            $relativePath = [System.IO.Path]::GetRelativePath($SearchPath, $_.FullName).Replace('\', '/')
            $matchPath = if ($FilePattern.Contains('/')) { $relativePath } else { $_.Name }
            $matchPath -match "^$pattern$"
        }
        
        return $files
    }
    else {
        # No wildcards - treat as direct path or file name
        $directFile = Join-Path -Path $SearchPath -ChildPath $FilePattern
        if (Test-Path -LiteralPath $directFile -PathType Leaf) {
            Write-Verbose "Found file by direct path: $directFile"
            return @(Get-Item -LiteralPath $directFile)
        }
        else {
            Write-Verbose "Attempting fallback search for file name '$FilePattern' in $SearchPath"
            return Get-ChildItem -Path $SearchPath -Recurse -File | Where-Object { $_.Name -ieq $FilePattern }
        }
    }
}

$files = @(Find-TestFiles -SearchPath $SearchPath -FilePattern $FilePattern)

if ($files.Count -eq 0) {
    Write-Warning "No files found matching pattern: $FilePattern"
    Write-Host "##vso[task.logissue type=error]No test files were found to execute."
    exit 10
}

$allExitCodes = @()

foreach ($file in $files) {
    $testRunCmd = @($TestRunnerCommand, $($file.FullName))
    $testRunCmd += $testArguments
    
    Write-Host "##[command]$($testRunCmd -join ' ')"
    
    if ($PSCmdlet.ShouldProcess($file.FullName, "Execute test runner $TestRunnerCommand")) {
        $global:LASTEXITCODE = 0
        $runnerArguments = $testRunCmd[1..($testRunCmd.Length - 1)]
        & $testRunCmd[0] @runnerArguments
        $allExitCodes += $LASTEXITCODE
    }
}

$overallExitCode = ($allExitCodes | Where-Object {
    $_ -ne 0 -and ($NoTestsExitCode -eq -1 -or $_ -ne $NoTestsExitCode)
}) | Select-Object -First 1
if ($null -ne $overallExitCode) {
    Write-Host "##vso[task.logissue type=warning]One or more test files failed"
    exit $overallExitCode
}
if ($NoTestsExitCode -ne -1 -and $allExitCodes.Count -gt 0 -and
    @($allExitCodes | Where-Object { $_ -ne $NoTestsExitCode }).Count -eq 0) {
    Write-Host "##vso[task.logissue type=error]No tests were executed; every test file was filtered out."
    exit $NoTestsExitCode
}
exit 0
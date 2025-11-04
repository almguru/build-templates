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
    to the test runner command for each test assembly.

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
    [string]$TestResultsArguments
)

# Construct test arguments
$testArguments = @()
$testArguments += $TestResultsArguments.Trim() -split '\s+' | Where-Object { $_ -ne '' }
$testArguments += $ResultsDirectory
if (![string]::IsNullOrWhiteSpace($AdditionalArguments)) {
    $testArguments += $AdditionalArguments.Trim() -split '\s+' | Where-Object { $_ -ne '' }
}

function Find-TestFiles {
    param(
        [string]$SearchPath,
        [string]$FilePattern
    )

    $hasWildcard = $FilePattern -match '[*?]'
    if ($hasWildcard) {
        # Special handling for patterns ending with a concrete file (e.g. **/subfolder/file.ext)
        # Convert '/' to '\' for Windows path matching
        $patternWin = $FilePattern -replace '/', '\'

        if ($FilePattern -match '^\*\*/.+[^*?]$') {
            # Find all files whose FullName ends with pattern after '**/' (replace '/' with '\')
            $tailPattern = $patternWin -replace '^\*\*\\', '' # Remove leading '**\'
            Write-Host "Searching for files ending with: $tailPattern under $SearchPath"
            return Get-ChildItem -Path $SearchPath -Recurse -File | Where-Object { $_.FullName -like "*$tailPattern" }
        } else {
            # General pattern, replace '**/' by '*' and '/' by '\'
            $searchPattern = $patternWin -replace '^\*\*/', '*' 
            Write-Host "Searching for files matching pattern: $searchPattern in $SearchPath"
            return Get-ChildItem -Path $SearchPath -Recurse -File | Where-Object { $_.FullName -like $searchPattern }
        }
    } else {
        # No wildcards - treat as direct path or file name
        $directFile = Join-Path -Path $SearchPath -ChildPath $FilePattern
        if (Test-Path $directFile) {
            Write-Host "Found file by direct path: $directFile"
            return @(Get-Item $directFile)
        } else {
            Write-Host "Attempting fallback search for file name '$FilePattern' in $SearchPath"
            return Get-ChildItem -Path $SearchPath -Recurse -File | Where-Object { $_.Name -ieq $FilePattern }
        }
    }
}

$files = Find-TestFiles -SearchPath $SearchPath -FilePattern $FilePattern

if ($files.Count -eq 0) {
    Write-Warning "No files found matching pattern: $FilePattern"
    Write-Host "##vso[task.logissue type=error]No test assemblies were found to execute."
    exit 10
}

$allExitCodes = @()

foreach ($file in $files) {
    $testRunCmd = @($TestRunnerCommand, $($file.FullName))
    $testRunCmd += $testArguments
    
    Write-Host "##[command]$($testRunCmd -join ' ')"
    & $testRunCmd[0] $testRunCmd[1..($testRunCmd.Length - 1)]
    $allExitCodes += $LASTEXITCODE
}

$overallExitCode = ($allExitCodes | Where-Object { $_ -ne 0 }) | Select-Object -First 1
if ($null -ne $overallExitCode) {
    Write-Host "##vso[task.logissue type=warning]One or more test assemblies failed"
    exit $overallExitCode
}
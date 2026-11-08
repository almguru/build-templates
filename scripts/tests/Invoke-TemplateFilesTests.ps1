<#
.SYNOPSIS
    Checks template-file setup conditions, path publication, and dependent wiring.
.DESCRIPTION
    Executes the helper's inline PowerShell with temporary workspace paths and checks
    the runtime guard contract without fetching repositories. Real checkout skipping
    is covered separately by the TestUseTemplateFiles pipeline stage.
#>
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$repositoryRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$helper = Get-Content -LiteralPath (Join-Path $repositoryRoot 'pipelines/lib/use-template-files.yml') -Raw
$guard = "condition: and(succeeded(), eq(variables.almguruTemplateFilesPath, ''))"
if (($helper.Split("`n") | Where-Object { $_.Trim() -eq $guard }).Count -ne 2) {
    throw 'Checkout and path publication must both have the same runtime readiness guard.'
}
$inline = [regex]::Match($helper, '(?ms)^  - pwsh: \|\r?\n(?<body>.*?)^    displayName:')
if (-not $inline.Success) { throw 'Cannot find the helper path-publication script.' }
$publishPath = [scriptblock]::Create(($inline.Groups['body'].Value -replace '(?m)^      ', ''))

foreach ($name in @('bicep-deploy', 'run-acceptance-tests')) {
    $template = Get-Content -LiteralPath (Join-Path $repositoryRoot "pipelines/lib/$name.yml") -Raw
    if ($template.Contains('Fail if template files are not configured')) {
        throw "$name still requires explicit helper setup."
    }
    if ($template -notmatch 'template: use-template-files.yml') {
        throw "$name must include the helper."
    }
    foreach ($parameter in @('repositoryResourceName', 'repositoryLocalPath')) {
        if ($template -notmatch "name: $parameter\b" -or
            -not $template.Contains(("$parameter" + ': ${{ parameters.' + $parameter + ' }}'))) {
            throw "$name must expose and forward $parameter."
        }
    }
    if ($name -eq 'bicep-deploy' -and
        $template -notmatch '(?m)^- \$\{\{ if parameters.useLegacyOverrideParameters \}\}:\r?\n  - template: use-template-files.yml') {
        throw 'Native Bicep mode must not automatically check out helper scripts.'
    }
}

$oldWorkspace = $env:PIPELINE_WORKSPACE
$oldRepositoryPath = $env:ALMGURU_TEMPLATE_REPOSITORY_PATH
$workspace = Join-Path ([IO.Path]::GetTempPath()) "template-files-$([guid]::NewGuid())"
try {
    $null = New-Item -ItemType Directory -Path $workspace
    $env:PIPELINE_WORKSPACE = $workspace
    foreach ($relativePath in @('almguru-templates', 'custom path/templates', 'templates%with-percent')) {
        $env:ALMGURU_TEMPLATE_REPOSITORY_PATH = $relativePath
        $output = @(& $publishPath 6>&1 | ForEach-Object { "$_" })
        $expectedPath = [IO.Path]::GetFullPath((Join-Path $workspace $relativePath))
        $escapedPath = $expectedPath.Replace('%', '%25').Replace("`r", '%0D').Replace("`n", '%0A')
        if ($output -notcontains "##vso[task.setvariable variable=almguruTemplateFilesPath]$escapedPath") {
            throw "Incorrect path publication for '$relativePath': $output"
        }
    }
    foreach ($invalidPath in @('', '../outside', 'nested/../outside', '/absolute', 'C:\absolute', '\\server\share')) {
        $env:ALMGURU_TEMPLATE_REPOSITORY_PATH = $invalidPath
        $caught = $false
        $output = @()
        try { $output = @(& $publishPath 6>&1) }
        catch { $caught = $true }
        if (-not $caught) { throw "Expected invalid path '$invalidPath' to fail." }
        if (@($output | Where-Object { "$_" -like '*##vso[task.setvariable*' }).Count -ne 0) {
            throw 'Invalid paths must not publish the readiness variable.'
        }
    }
    Write-Host 'Template-file guards, path publication, validation, and dependent wiring passed.'
}
finally {
    $env:PIPELINE_WORKSPACE = $oldWorkspace
    $env:ALMGURU_TEMPLATE_REPOSITORY_PATH = $oldRepositoryPath
    Remove-Item -LiteralPath $workspace -Recurse -Force
}

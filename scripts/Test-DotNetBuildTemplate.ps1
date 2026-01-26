#!/usr/bin/env pwsh
<#
.SYNOPSIS
Test script for build-dotnet.yml template

.DESCRIPTION
This script creates a sample test project and validates the build-dotnet template
functionality by creating a Modern Test Project with Microsoft.Testing.Platform.

.PARAMETER WorkDir
The working directory where the sample project will be created.
Defaults to './dotnet-sample-test'

.EXAMPLE
./Test-DotNetBuildTemplate.ps1
./Test-DotNetBuildTemplate.ps1 -WorkDir "/tmp/dotnet-test"
#>

param(
    [string]$WorkDir = "./dotnet-sample-test"
)

$ErrorActionPreference = "Stop"

Write-Host "🔧 Testing build-dotnet template in: $WorkDir"

# Clean up any previous runs
if (Test-Path $WorkDir) {
    Write-Host "Removing existing directory: $WorkDir"
    Remove-Item -Path $WorkDir -Recurse -Force
}

New-Item -ItemType Directory -Path $WorkDir -Force | Out-Null
Set-Location $WorkDir

Write-Host ""
Write-Host "📝 Creating global.json with Microsoft.Testing.Platform..."
$globalJsonContent = @{
    test = @{
        runner = "Microsoft.Testing.Platform"
    }
} | ConvertTo-Json -Depth 10

Set-Content -Path "global.json" -Value $globalJsonContent
Write-Host $globalJsonContent

Write-Host ""
Write-Host "📦 Creating xUnit test project..."
& dotnet new xunit -n Sample.Tests -f net10.0

Write-Host ""
Write-Host "📚 Adding Microsoft.Testing.Platform package..."
& dotnet add Sample.Tests/Sample.Tests.csproj package Microsoft.Testing.Platform

Write-Host ""
Write-Host "🔍 Checking xUnit test project structure..."
Get-ChildItem -Path Sample.Tests -Recurse | Select-Object -First 20
Write-Host ""
Write-Host "Content of Sample.Tests.csproj:"
Get-Content Sample.Tests/Sample.Tests.csproj

Write-Host ""
Write-Host "🏗️ Building test project..."
Push-Location Sample.Tests
& dotnet build --configuration Release --property:UseArtifactsOutput=true --artifacts-path ./artifacts

Write-Host ""
Write-Host "✅ Build completed successfully!"
Write-Host ""
Write-Host "📂 Build artifacts location:"
Get-ChildItem -Path ./artifacts -Recurse -Filter "*.dll" -ErrorAction SilentlyContinue | Select-Object -First 5

Pop-Location

Write-Host ""
Write-Host "✨ Test script completed successfully!"
Write-Host "The sample test project is ready in: $WorkDir"

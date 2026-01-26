#!/usr/bin/env pwsh
<#
.SYNOPSIS
Test script for build-dotnet.yml template

.DESCRIPTION
This script creates a sample xUnit test project to validate the build-dotnet.yml template.
Uses a standard xUnit template without modifications to avoid conflicts.

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
    Write-Host "Removing existing directory..."
    Remove-Item -Path $WorkDir -Recurse -Force
}

New-Item -ItemType Directory -Path $WorkDir -Force | Out-Null
Set-Location $WorkDir

Write-Host "Current directory: $(Get-Location)"

Write-Host ""
Write-Host "📦 Creating xUnit test project (.NET 8.0)..."
& dotnet new xunit -n Sample.Tests -f net8.0

Write-Host ""
Write-Host "📂 Project structure:"
Get-ChildItem -Path Sample.Tests -Recurse | Select-Object -First 10

Write-Host ""
Write-Host "Content of Sample.Tests.csproj:"
Get-Content Sample.Tests/Sample.Tests.csproj

Write-Host ""
Write-Host "🏗️ Building test project with UseArtifactsOutput=true..."
Push-Location Sample.Tests
try {
    & dotnet build --configuration Release --property:UseArtifactsOutput=true --artifacts-path ./artifacts
    if ($LASTEXITCODE -ne 0) {
        throw "Build failed with exit code: $LASTEXITCODE"
    }
}
finally {
    Pop-Location
}

Write-Host ""
Write-Host "✅ Build completed successfully!"

Write-Host ""
Write-Host "📂 Build artifacts:"
if (Test-Path "Sample.Tests/artifacts") {
    Get-ChildItem -Path "Sample.Tests/artifacts" -Recurse -Filter "*.dll" | Select-Object -First 3
}

Write-Host ""
Write-Host "✨ Test script completed successfully!"
Write-Host "Sample test project ready in: $WorkDir"

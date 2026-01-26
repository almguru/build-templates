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
Write-Host "⚙️ Configuring project to disable automatic assembly info generation..."
$csprojPath = "$PWD/Sample.Tests/Sample.Tests.csproj"

# Read the project file
[xml]$csproj = Get-Content $csprojPath

# Find or create PropertyGroup
$propertyGroup = $csproj.Project.PropertyGroup | Select-Object -First 1
if ($propertyGroup) {
    # Check if element already exists
    if (-not $propertyGroup.GenerateAssemblyInfo) {
        $generateAssemblyInfo = $csproj.CreateElement("GenerateAssemblyInfo")
        $generateAssemblyInfo.InnerText = "false"
        $propertyGroup.AppendChild($generateAssemblyInfo) | Out-Null
    } else {
        $propertyGroup.GenerateAssemblyInfo = "false"
    }
    
    # Check if runtime config element already exists
    if (-not $propertyGroup.GenerateRuntimeConfigurationFiles) {
        $generateRuntimeConfigurationFiles = $csproj.CreateElement("GenerateRuntimeConfigurationFiles")
        $generateRuntimeConfigurationFiles.InnerText = "true"
        $propertyGroup.AppendChild($generateRuntimeConfigurationFiles) | Out-Null
    } else {
        $propertyGroup.GenerateRuntimeConfigurationFiles = "true"
    }
    
    # Save with proper XML settings
    $xmlSettings = New-Object System.Xml.XmlWriterSettings
    $xmlSettings.Indent = $true
    $xmlSettings.IndentChars = "  "
    $xmlSettings.Encoding = [System.Text.Encoding]::UTF8
    
    $xmlWriter = [System.Xml.XmlWriter]::Create($csprojPath, $xmlSettings)
    $csproj.WriteTo($xmlWriter)
    $xmlWriter.Close()
    
    Write-Host "✓ Assembly info generation disabled and runtime config enabled"
    Write-Host ""
    Write-Host "Verifying project file update:"
    $updatedContent = Get-Content $csprojPath
    if ($updatedContent -match "GenerateAssemblyInfo") {
        Write-Host "✓ GenerateAssemblyInfo property found in project file"
    } else {
        Write-Host "⚠️ WARNING: GenerateAssemblyInfo not found in project file!"
    }
} else {
    Write-Host "⚠️ Could not find PropertyGroup in project file"
}

Write-Host ""
Write-Host "� Adding test method to verify tests run..."
$testFileContent = @'
namespace Sample.Tests;

public class UnitTest1
{
    [Fact]
    public void TestMethod_PassingTest()
    {
        Assert.True(true, "This is a passing test");
    }

    [Fact]
    public void TestMethod_ArithmeticTest()
    {
        Assert.Equal(4, 2 + 2);
    }
}
'@

Set-Content -Path "Sample.Tests/UnitTest1.cs" -Value $testFileContent
Write-Host "✓ Test methods added"
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

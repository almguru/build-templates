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
Write-Host "   Absolute path: $(Resolve-Path $WorkDir -ErrorAction SilentlyContinue)"

# Clean up any previous runs
if (Test-Path $WorkDir) {
    Write-Host "Removing existing directory: $WorkDir"
    Remove-Item -Path $WorkDir -Recurse -Force
}

New-Item -ItemType Directory -Path $WorkDir -Force | Out-Null
Set-Location $WorkDir

Write-Host "   Current directory: $(Get-Location)"

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
Write-Host "⚙️ Configuring project to disable automatic assembly info generation (BEFORE adding packages)..."
$csprojPath = Join-Path (Get-Location) "Sample.Tests" "Sample.Tests.csproj"
Write-Host "   Project file path: $csprojPath"
Write-Host "   Project file exists: $(Test-Path $csprojPath)"

function Update-ProjectFile {
    param([string]$Path)
    
    # Read the project file
    [xml]$csproj = Get-Content $Path
    
    # Find or create PropertyGroup
    $propertyGroup = $csproj.Project.PropertyGroup | Select-Object -First 1
    if (-not $propertyGroup) {
        throw "Could not find PropertyGroup in project file"
    }
    
    $modified = $false
    
    # Check if element already exists
    if (-not $propertyGroup.GenerateAssemblyInfo) {
        $generateAssemblyInfo = $csproj.CreateElement("GenerateAssemblyInfo")
        $generateAssemblyInfo.InnerText = "false"
        $propertyGroup.AppendChild($generateAssemblyInfo) | Out-Null
        $modified = $true
    } elseif ($propertyGroup.GenerateAssemblyInfo -ne "false") {
        $propertyGroup.GenerateAssemblyInfo = "false"
        $modified = $true
    }
    
    # Check if runtime config element already exists
    if (-not $propertyGroup.GenerateRuntimeConfigurationFiles) {
        $generateRuntimeConfigurationFiles = $csproj.CreateElement("GenerateRuntimeConfigurationFiles")
        $generateRuntimeConfigurationFiles.InnerText = "true"
        $propertyGroup.AppendChild($generateRuntimeConfigurationFiles) | Out-Null
        $modified = $true
    } elseif ($propertyGroup.GenerateRuntimeConfigurationFiles -ne "true") {
        $propertyGroup.GenerateRuntimeConfigurationFiles = "true"
        $modified = $true
    }
    
    if ($modified) {
        # Save with proper XML settings
        $xmlSettings = New-Object System.Xml.XmlWriterSettings
        $xmlSettings.Indent = $true
        $xmlSettings.IndentChars = "  "
        $xmlSettings.Encoding = [System.Text.Encoding]::UTF8
        $xmlSettings.NewLineHandling = [System.Xml.NewLineHandling]::Replace
        
        $xmlWriter = [System.Xml.XmlWriter]::Create($Path, $xmlSettings)
        $csproj.WriteTo($xmlWriter)
        $xmlWriter.Close()
        $xmlWriter.Dispose()
        
        # Force flush
        [System.GC]::Collect()
        Start-Sleep -Milliseconds 100
    }
    
    return $modified
}

# Update project file
if (Update-ProjectFile $csprojPath) {
    Write-Host "✓ Project file updated with assembly info settings"
} else {
    Write-Host "✓ Project file already has assembly info settings"
}

# Verify the settings are in place
$csprojContent = Get-Content $csprojPath -Raw
if ($csprojContent -match "GenerateAssemblyInfo") {
    Write-Host "✓ Verified: GenerateAssemblyInfo property is in project file"
} else {
    Write-Host "❌ ERROR: GenerateAssemblyInfo property NOT found in project file after update!"
    Write-Host "Project file content (first 2000 chars):"
    Write-Host $csprojContent.Substring(0, [Math]::Min(2000, $csprojContent.Length))
    throw "Failed to update project file with required properties"
}

Write-Host ""
Write-Host "📚 Adding Microsoft.Testing.Platform package (AFTER configuration)..."
& dotnet add Sample.Tests/Sample.Tests.csproj package Microsoft.Testing.Platform

Write-Host ""
Write-Host "🔍 Verifying GenerateAssemblyInfo is still set after package addition..."
$postPackageContent = Get-Content $csprojPath -Raw
if ($postPackageContent -match "GenerateAssemblyInfo.*false") {
    Write-Host "✓ GenerateAssemblyInfo=false still present after dotnet add"
} else {
    Write-Host "⚠️  WARNING: dotnet add may have modified the project file"
    Write-Host "Re-applying GenerateAssemblyInfo=false..."
    Update-ProjectFile $csprojPath | Out-Null
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

# Verify the csproj file one more time after all operations
Write-Host ""
Write-Host "📋 Final verification of project configuration:"
$finalCsprojPath = Join-Path $WorkDir "Sample.Tests" "Sample.Tests.csproj"
if (Test-Path $finalCsprojPath) {
    $finalContent = Get-Content $finalCsprojPath -Raw
    if ($finalContent -match "GenerateAssemblyInfo.*false") {
        Write-Host "✓ VERIFIED: GenerateAssemblyInfo=false is present in final project file"
    } else {
        Write-Host "❌ CRITICAL: GenerateAssemblyInfo=false NOT found in final project file!"
        Write-Host "This will cause build failures in the pipeline."
        throw "Project file verification failed"
    }
} else {
    Write-Host "❌ Project file not found at: $finalCsprojPath"
    throw "Project file missing"
}

Write-Host ""
Write-Host "✨ Test script completed successfully!"
Write-Host "The sample test project is ready in: $WorkDir"

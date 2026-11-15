<#
.SYNOPSIS
    Tests the sample PowerShell module used by the build template.
.DESCRIPTION
    Exercises the exported module function through Pester.
#>
BeforeAll {
    $moduleManifest = Join-Path $PSScriptRoot '../Sample.PowerShell/Sample.PowerShell.Manifest.psd1'
    Import-Module -Name $moduleManifest -Force
}

Describe 'Sample.PowerShell module' {
    It 'returns a greeting for the supplied name' {
        Get-SampleGreeting -Name 'Pipeline' | Should -Be 'Hello, Pipeline!'
    }
}

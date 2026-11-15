<#
.SYNOPSIS
    Provides a sample greeting function for build-template verification.
.DESCRIPTION
    Exports a small function used by the PowerShell Pester unit-test fixture.
#>
function Get-SampleGreeting {
    [CmdletBinding()]
    param(
        [Parameter()]
        [string]$Name = 'PowerShell'
    )

    "Hello, $Name!"
}

Export-ModuleMember -Function Get-SampleGreeting

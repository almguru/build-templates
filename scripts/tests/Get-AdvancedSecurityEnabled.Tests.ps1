<#
.SYNOPSIS
    Tests the Advanced Security enablement helper.
.DESCRIPTION
    Verifies Boolean enablement results and that unsupported repository
    providers skip the API request.
#>
BeforeAll {
  $script:enablementScript = Join-Path $PSScriptRoot '../Get-AdvancedSecurityEnabled.ps1'
  $script:previousEnvironment = @{}
  foreach ($name in @('ALMGURU_TEST_ADVSEC_ENABLED', 'BUILD_REPOSITORY_PROVIDER', 'ACCESS_TOKEN',
      'SYSTEM_COLLECTIONURI', 'SYSTEM_TEAMPROJECT', 'BUILD_REPOSITORY_NAME')) {
    $script:previousEnvironment[$name] = [Environment]::GetEnvironmentVariable($name)
  }
  $script:previousGlobalStatusCode = Get-Variable -Name statusCode -Scope Global -ErrorAction SilentlyContinue
}

Describe 'Get-AdvancedSecurityEnabled.ps1' {
  BeforeEach {
    $env:ALMGURU_TEST_ADVSEC_ENABLED = 'false'
    $env:BUILD_REPOSITORY_PROVIDER = 'TfsGit'
    $env:ACCESS_TOKEN = 'test-token'
    $env:SYSTEM_COLLECTIONURI = 'https://dev.azure.com/example/'
    $env:SYSTEM_TEAMPROJECT = 'project'
    $env:BUILD_REPOSITORY_NAME = 'repository'
    Mock Invoke-RestMethod {
      Set-Variable -Name $StatusCodeVariable -Value 200 -Scope Global
      [pscustomobject]@{
        advSecEnabled = [bool]::Parse($env:ALMGURU_TEST_ADVSEC_ENABLED)
      }
    }
  }

  It 'returns only a Boolean true when Advanced Security is enabled' {
    $env:ALMGURU_TEST_ADVSEC_ENABLED = 'true'
    $output = @(& $script:enablementScript)

    $output.Count | Should -Be 1
    $output[0] | Should -BeOfType [bool]
    $output[0] | Should -BeTrue
    Should -Invoke Invoke-RestMethod -Times 1 -Exactly -ParameterFilter {
      $Uri -eq 'https://advsec.dev.azure.com/example/project/_apis/management/repositories/repository/enablement?api-version=7.2-preview.1' -and
      $Headers.Authorization -eq 'Bearer test-token'
    }
  }

  It 'returns only a Boolean false when Advanced Security is disabled' {
    $output = @(& $script:enablementScript)

    $output.Count | Should -Be 1
    $output[0] | Should -BeOfType [bool]
    $output[0] | Should -BeFalse
  }

  It 'escapes project and repository names as separate path segments' {
    $env:SYSTEM_TEAMPROJECT = 'project name'
    $env:BUILD_REPOSITORY_NAME = 'repo%20name'
    & $script:enablementScript | Out-Null

    Should -Invoke Invoke-RestMethod -Times 1 -Exactly -ParameterFilter {
      $Uri -eq 'https://advsec.dev.azure.com/example/project%20name/_apis/management/repositories/repo%2520name/enablement?api-version=7.2-preview.1'
    }
  }

  It 'returns only Boolean false and skips the API for non-Azure-Repos providers' {
    $env:BUILD_REPOSITORY_PROVIDER = 'GitHub'
    $output = @(& $script:enablementScript)

    $output.Count | Should -Be 1
    $output[0] | Should -BeOfType [bool]
    $output[0] | Should -BeFalse
    Should -Invoke Invoke-RestMethod -Times 0 -Exactly
  }

  It 'fails clearly when an Azure Repos access token is missing' {
    $env:ACCESS_TOKEN = ''
    { & $script:enablementScript } | Should -Throw '*System.AccessToken is missing*'
  }

  AfterAll {
    foreach ($name in $script:previousEnvironment.Keys) {
      [Environment]::SetEnvironmentVariable($name, $script:previousEnvironment[$name])
    }

    if ($null -ne $script:previousGlobalStatusCode) {
      Set-Variable -Name statusCode -Value $script:previousGlobalStatusCode.Value -Scope Global
    }
    else {
      Remove-Variable -Name statusCode -Scope Global -ErrorAction SilentlyContinue
    }
  }
}

Describe 'Acceptance runtime' {
    It 'receives the configured environment' -Tag Smoke {
        $env:PESTER_CONTEXT_VALUE | Should -Be 'pipeline context'
    }

    It 'uses the resolved Pester version' -Tag Smoke {
        (Get-Command Invoke-Pester).Module.Version.ToString() | Should -Be $env:PESTER_CONTEXT_VERSION
    }

    It 'can be excluded by a tag filter' -Tag Slow {
        throw 'This test must be excluded by the template arguments.'
    }
}

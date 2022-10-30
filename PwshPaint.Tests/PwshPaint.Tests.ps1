#Requires -Modules PSScriptAnalyzer

BeforeAll {
    Set-StrictMode -Version "3.0"
    $script:ModuleDir = "$PSScriptRoot/../PwshPaint"
}

Describe "PwshPaint" {
    It "shows no warnings and errors of PSScriptAnalyzer" {
        $result = Invoke-ScriptAnalyzer -Path $script:ModuleDir -Recurse
        $result | Out-String | Write-Host
        $result | Should -Be $null
    }

    It "is importable without strictmode errors" {
        $errors = ""
        Import-Module "$script:ModuleDir/PwshPaint.psm1" -ErrorVariable errors -Force
        $errors.Count | Should -Be 0
        Write-Host "$errors"
    }
}


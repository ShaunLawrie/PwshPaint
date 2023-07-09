@{
    ModuleVersion = '1.0.5'
    GUID = '32c58857-b36b-4d16-845d-fd72f34dfd72'
    Author = 'Shaun Lawrie'
    CompanyName = 'Shaun Lawrie'
    Copyright = '(c) Shaun Lawrie. All rights reserved.'
    Description = 'A simple painting application for PowerShell'
    PowerShellVersion = '5.0'
    PowerShellHostName = 'ConsoleHost'
    RootModule = 'PwshPaint'
    FunctionsToExport = @('Invoke-Paint', 'Invoke-PaintGallery')
    CmdletsToExport = @()
    VariablesToExport = '*'
    AliasesToExport = @()
    PrivateData = @{
        PSData = @{
            Tags = @("Windows", "Linux")
            LicenseUri = 'https://github.com/ShaunLawrie/PwshPaint/blob/main/LICENSE.md'
            ProjectUri = 'https://github.com/ShaunLawrie/PwshPaint'
            IconUri = 'https://shaunlawrie.com/images/pwshpaint.png'
        }
    }
}
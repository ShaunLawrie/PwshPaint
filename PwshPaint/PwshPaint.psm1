Set-StrictMode -Version "3.0"

$ErrorActionPreference = "Stop"

. "$PSScriptRoot/Private/Invoke-Paint.ps1"
. "$PSScriptRoot/Private/Invoke-PaintGallery.ps1"

Export-ModuleMember -Function @("Invoke-Paint", "Invoke-PaintGallery")
param (
    [int] $ImageWidth = 28,
    [int] $ImageHeight = 28,
    [string] $AppSettingsPath = "$PSScriptRoot/appsettings.json",
    [string] $Path
)

$ErrorActionPreference = "Stop"

Import-Module "$PSScriptRoot/modules/SpriteHandler.psm1" -Force

if(!(Test-Path $AppSettingsPath)) {
    Write-Error "Could not find a settings file at '$AppSettingsPath'"
}
$global:AppSettings = Get-Content $AppSettingsPath | ConvertFrom-Json
$global:KeyBindings = $global:AppSettings.Keybindings
$global:SwitchToolControlHeader = Get-SwitchToolControlHeader
$global:ColorKeys = Get-ColorKeys
$global:Tools = @("Pen", "Fill", "Snake", "Dropper", "Pen Eraser", "Fill Eraser")
$global:Commands = Get-AnnotatedCommands -Commands @("New", "Open", "Save", "Undo", "Redo", "Close") -Section "Commands"
$global:NavigationControls = Get-AnnotatedCommands -Commands @("Left", "Right", "Up", "Down") -Section "Navigation"
$global:CurrentHue = 0
$global:CurrentSaturation = 100
$global:CurrentValue = 100
$global:HueChunkSize = 36
$global:CurrentTool = "Pen"
$global:ForceRefresh = $false
$global:BackgroundColors = @(@(35, 35, 35), @(30, 30, 30))
$global:Image = @($null) * $ImageWidth
$global:ImageWidth = $ImageWidth
$global:ImageHeight = $ImageHeight

if($Path) {
    if(Test-Path $Path) {
        Open-JsonSprite -Path $Path
        $ImageWidth = $global:Image.Count
        $ImageHeight = $global:Image[0].Count
    } else {
        Write-Error "Could not find an image to load at $Path"
    }
} else {
    for($x = 0; $x -lt $ImageWidth; $x++) {
        $global:Image[$x] = @($null) * $ImageHeight
    }
}

Wait-ForCanvasToFitInTerminal
$CanvasTopLeft = $Host.UI.RawUI.CursorPosition
$currentPosition = @{ X = 0; Y = 0 }
[Console]::CursorVisible = $false
$previousPosition = @{
    X = $currentPosition.X
    Y = $currentPosition.Y
}
$previousWindowSize = @{
    X = $Host.UI.RawUI.WindowSize.Width
    Y = $Host.UI.RawUI.WindowSize.Height
}

try {
    while($true) {
        Write-Frame -CanvasTopLeft $CanvasTopLeft -CurrentPosition $currentPosition -PreviousPosition $previousPosition
        $inputReceived = $false
        while(!$inputReceived) {
            # Redraw on window resize
            if($previousWindowSize.X -ne $Host.UI.RawUI.WindowSize.Width -or $previousWindowSize.Y -ne $Host.UI.RawUI.WindowSize.Height) {
                Clear-Host
                Wait-ForCanvasToFitInTerminal -Path $Path
                $previousWindowSize = @{
                    X = $Host.UI.RawUI.WindowSize.Width
                    Y = $Host.UI.RawUI.WindowSize.Height
                }
                $global:ForceRefresh = $true
                $inputReceived = $true
                break
            }
            [Console]::TreatControlCAsInput = $true
            $key = [Console]::ReadKey($true)
            $previousPosition = @{
                X = $currentPosition.X
                Y = $currentPosition.Y
            }
            $action = Get-ActionForKey -Key $key
            switch($action) {
                "Left" {
                    $currentPosition.X = [Math]::Max($currentPosition.X - 1, 0)
                }
                "Right" {
                    $currentPosition.X = [Math]::Min($currentPosition.X + 1, $ImageWidth - 1)
                }
                "Up" {
                    $currentPosition.Y = [Math]::Max($currentPosition.Y - 1, 0)
                }
                "Down" {
                    $currentPosition.Y = [Math]::Min($currentPosition.Y + 1, $ImageHeight - 1)
                }
                "HueLeft" {
                    $global:CurrentHue = [Math]::Max($global:CurrentHue - $global:HueChunkSize, 0)
                    $inputReceived = $true
                }
                "HueRight" {
                    $global:CurrentHue = [Math]::Min($global:CurrentHue + $global:HueChunkSize, 360 - $global:HueChunkSize)
                    $inputReceived = $true
                }
                "SaturationLeft" {
                    $global:CurrentSaturation = [Math]::Max($global:CurrentSaturation - 20, 0)
                    $inputReceived = $true
                }
                "SaturationRight" {
                    $global:CurrentSaturation = [Math]::Min($global:CurrentSaturation + 20, 100)
                    $inputReceived = $true
                }
                "Undo" {
                    Pop-UndoState
                    $global:ForceRefresh = $true
                    $inputReceived = $true
                }
                "ValueLeft" {
                    $global:CurrentValue = [Math]::Max($global:CurrentValue - 20, 0)
                    $inputReceived = $true
                }
                "ValueRight" {
                    $global:CurrentValue = [Math]::Min($global:CurrentValue + 20, 100)
                    $inputReceived = $true
                }
                "SwitchTool" {
                    $index = $global:Tools.IndexOf($global:CurrentTool)
                    if($key.Modifiers -eq "Shift") {
                        $targetIndex = $index - 1
                        if($targetIndex -lt 0) {
                            $targetIndex = $global:Tools.Count - 1
                        }
                    } else {
                        $targetIndex = ($index + 1) % $global:Tools.Count
                    }
                    $global:CurrentTool = $global:Tools[$targetIndex]
                    $inputReceived = $true
                }
                "Open" {
                    Open-JsonSpriteDialog -ScriptRoot $PSScriptRoot
                    $inputReceived = $true
                }
                "New" {
                    New-JsonSpriteDialog
                    $inputReceived = $true
                }
                "Save" {
                    Save-JsonSprite -Path $Path -ScriptRoot $PSScriptRoot
                    $inputReceived = $true
                }
                "Spacebar" {

                    switch($global:CurrentTool) {
                        "Pen" {
                            $global:Image[$currentPosition.X][$currentPosition.Y] = (Convert-HsvToRgb -Hue $global:CurrentHue -Saturation $global:CurrentSaturation -Value $global:CurrentValue)
                        }
                        "Snake" {
                            $global:Image[$currentPosition.X][$currentPosition.Y] = (Convert-HsvToRgb -Hue $global:CurrentHue -Saturation $global:CurrentSaturation -Value $global:CurrentValue)
                        }
                        "Pen Eraser" {
                            $global:Image[$currentPosition.X][$currentPosition.Y] = $null
                        }
                        "Fill" {
                            Add-Fill -OriginalColor $global:Image[$currentPosition.X][$currentPosition.Y] -CurrentPosition $currentPosition
                            $global:ForceRefresh = $true
                        }
                        "Fill Eraser" {
                            Remove-Fill -OriginalColor $global:Image[$currentPosition.X][$currentPosition.Y] -CurrentPosition $currentPosition
                            $global:ForceRefresh = $true
                        }
                        "Dropper" {
                            $originalColor = $global:Image[$currentPosition.X][$currentPosition.Y]
                            if($null -ne $originalColor) {
                                $result = Find-Hsv -Rgb $originalColor
                                if($result) {
                                    $global:CurrentHue = $result.H
                                    $global:CurrentSaturation = $result.S
                                    $global:CurrentValue = $result.V
                                }
                                $global:ForceRefresh = $true
                            }
                        }
                    }

                    Push-UndoState
                    $inputReceived = $true
                }
                "Close" {
                    $inputReceived = $true
                    exit 0
                }
                "Redo" {
                    Pop-RedoState
                    $global:ForceRefresh = $true
                    $inputReceived = $true
                }
            }
            if(@("HueLeft", "HueRight", "ValueLeft", "ValueRight", "SaturationLeft", "SaturationRight", "SwitchTool") -contains $action) {
                if($global:CurrentMode -eq "Snake") {
                    if($global:CurrentTool -eq "Pen") {
                        $global:Image[$currentPosition.X][$currentPosition.Y] = (Convert-HsvToRgb -Hue $global:CurrentHue -Saturation $global:CurrentSaturation -Value $global:CurrentValue)
                    } elseif($global:CurrentTool -eq "Eraser") {
                        $global:Image[$currentPosition.X][$currentPosition.Y] = $null
                    }
                    Push-UndoState
                }
            }
            if($previousPosition.X -ne $currentPosition.X -or $previousPosition.Y -ne $currentPosition.Y) {
                if($global:CurrentTool -eq "Snake") {
                    $global:Image[$currentPosition.X][$currentPosition.Y] = (Convert-HsvToRgb -Hue $global:CurrentHue -Saturation $global:CurrentSaturation -Value $global:CurrentValue)
                    Push-UndoState
                }
                $inputReceived = $true
            }
        }
    }
} finally {
    [Console]::CursorVisible = $true
}
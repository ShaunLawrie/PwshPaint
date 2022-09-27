param (
    [int] $ImageWidth = 28,
    [int] $ImageHeight = 28,
    [string] $Path
)

$ErrorActionPreference = "Stop"

Import-Module "$PSScriptRoot/modules/SpriteHandler.psm1" -Force

$global:Tools = @("Pen", "Fill", "Snake", "Dropper", "Pen Eraser", "Fill Eraser")
$global:Commands = @("New   (ctrl+N)", "Open  (ctrl+O)", "Save  (ctrl+S)", "Undo  (ctrl+Z)", "Redo  (ctrl+Y)", "Close (ctrl+C)")
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
            switch($key.Key) {
                "LeftArrow" {
                    $currentPosition.X = [Math]::Max($currentPosition.X - 1, 0)
                }
                "RightArrow" {
                    $currentPosition.X = [Math]::Min($currentPosition.X + 1, $ImageWidth - 1)
                }
                "UpArrow" {
                    $currentPosition.Y = [Math]::Max($currentPosition.Y - 1, 0)
                }
                "DownArrow" {
                    $currentPosition.Y = [Math]::Min($currentPosition.Y + 1, $ImageHeight - 1)
                }
                "Q" {
                    $global:CurrentHue = [Math]::Max($global:CurrentHue - $global:HueChunkSize, 0)
                    $inputReceived = $true
                }
                "W" {
                    $global:CurrentHue = [Math]::Min($global:CurrentHue + $global:HueChunkSize, 360 - $global:HueChunkSize)
                    $inputReceived = $true
                }
                "A" {
                    $global:CurrentSaturation = [Math]::Max($global:CurrentSaturation - 20, 0)
                    $inputReceived = $true
                }
                "S" {
                    if($key.Modifiers -eq "Control") {
                        Save-JsonSprite -Path $Path -ScriptRoot $PSScriptRoot
                        $inputReceived = $true
                    } else {
                        $global:CurrentSaturation = [Math]::Min($global:CurrentSaturation + 20, 100)
                        $inputReceived = $true
                    }
                }
                "Z" {
                    if($key.Modifiers -eq "Control") {
                        Pop-UndoState
                        $global:ForceRefresh = $true
                        $inputReceived = $true
                    } else {
                        $global:CurrentValue = [Math]::Max($global:CurrentValue - 20, 0)
                        $inputReceived = $true
                    }
                }
                "X" {
                    $global:CurrentValue = [Math]::Min($global:CurrentValue + 20, 100)
                    $inputReceived = $true
                }
                "T" {
                    $index = $global:Tools.IndexOf($global:CurrentTool)
                    $global:CurrentTool = $global:Tools[(($index + 1) % $global:Tools.Count)]
                    $inputReceived = $true
                }
                "O" {
                    if($key.Modifiers -eq "Control") {
                        Open-JsonSpriteDialog -ScriptRoot $PSScriptRoot
                        $inputReceived = $true
                    }
                }
                "N" {
                    if($key.Modifiers -eq "Control") {
                        New-JsonSpriteDialog
                        $inputReceived = $true
                    }
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
                "C" {
                    if($key.Modifiers -eq "Control") {
                        $inputReceived = $true
                        exit 1
                    }
                }
                "Y" {
                    if($key.Modifiers -eq "Control") {
                        Pop-RedoState
                        $global:ForceRefresh = $true
                        $inputReceived = $true
                    }
                }
            }
            if(@("Q", "W", "A", "S", "Z", "X", "T") -contains $key.Key) {
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
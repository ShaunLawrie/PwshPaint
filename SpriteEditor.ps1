param (
    [int] $ImageWidth = 28,
    [int] $ImageHeight = 28,
    [string] $Path
)

$ErrorActionPreference = "Stop"

Import-Module "$PSScriptRoot/modules/SpriteHandler.psm1" -Force

$global:Tools = @("Pen", "Eraser")
$global:Modes = @("Spacebar", "Snake")
$global:CurrentHue = 0
$global:CurrentSaturation = 100
$global:CurrentValue = 100
$global:HueChunkSize = 36
$global:CurrentTool = "Pen"
$global:CurrentMode = "Spacebar"
$global:ForceRefresh = $false
$global:BackgroundColors = @(@(35, 35, 35), @(30, 30, 30))
$global:Image = @($null) * $ImageWidth

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

Clear-Host
Write-Host -NoNewline "~ SpriteEditor.ps1 "
if($Path) {
    Write-Host -ForegroundColor DarkGray "$(Split-Path $Path -Leaf)`n"
} else {
    Write-Host "`n"
}
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
        Write-Frame -CanvasTopLeft $CanvasTopLeft -CurrentPosition $currentPosition -PreviousPosition $previousPosition -ImageHeight $ImageHeight -ImageWidth $ImageWidth
        $inputReceived = $false
        while(!$inputReceived) {
            # Redraw on window resize
            if($previousWindowSize.X -ne $Host.UI.RawUI.WindowSize.Width -or $previousWindowSize.Y -ne $Host.UI.RawUI.WindowSize.Height) {
                Clear-Host
                if(!(Test-CanvasFitsInTerminal -ImageWidth $ImageWidth -ImageHeight $ImageHeight)) {
                    Write-Warning "Your canvas is too large for the terminal window, try zooming out"
                    while(!(Test-CanvasFitsInTerminal -ImageWidth $ImageWidth -ImageHeight $ImageHeight)) {
                        Start-Sleep -Milliseconds 100
                    }
                }
                $previousWindowSize = @{
                    X = $Host.UI.RawUI.WindowSize.Width
                    Y = $Host.UI.RawUI.WindowSize.Height
                }
                Write-Host -NoNewline "~ SpriteEditor.ps1 "
                if($Path) {
                    Write-Host -ForegroundColor DarkGray "$(Split-Path $Path -Leaf)`n"
                } else {
                    Write-Host "`n"
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
                        while($true) {
                            Clear-Host
                            Write-Host "~ SpriteEditor.ps1 - Save your pixel art`n"
                            [Console]::CursorVisible = $true
                            if($Path) {
                                $defaultPath = $Path
                                Write-Host -ForegroundColor DarkGray "Press ENTER to use the default '$Path'"
                                Write-Host -NoNewline -ForegroundColor DarkGray "Enter a filename or path to save the sprite json: "
                                $Path = Read-Host
                                if([string]::IsNullOrEmpty($Path)) {
                                    $Path = $defaultPath
                                }
                            } else {
                                Write-Host -NoNewline -ForegroundColor DarkGray "Enter a filename or path to save the sprite json: "
                                $Path = Read-Host
                            }
                            if($Path -notmatch "\.json$") {
                                $Path = $Path + ".json"
                            }
                            if($Path -eq (Split-Path $Path -Leaf)) {
                                $Path = Join-Path "$PSScriptRoot/sprites" $Path
                            }
                            if(Test-Path $Path) {
                                Write-Host -ForegroundColor Yellow -NoNewline "A file exists at $Path, do you want to overwrite it? (y/n) "
                                $answer = Read-Host
                                if($answer -ne "y") {
                                    continue
                                }
                            }
                            $c = $global:Image | ConvertTo-Json -Depth 25
                            Set-Content -Path $Path -Value $c
                            Out-Gif -Path ($Path -replace "[^\.]+$", "gif") -ImageHeight $ImageHeight -ImageWidth $ImageWidth
                            Write-Host -ForegroundColor DarkGray -NoNewline "Saved at $Path"
                            [Console]::CursorVisible = $false
                            0..3 | Foreach-Object {
                                Start-Sleep -Milliseconds 500
                                Write-Host -ForegroundColor DarkGray -NoNewline "."
                            }
                            Clear-Host
                            Write-Host -NoNewline "~ SpriteEditor.ps1 "
                            Write-Host -ForegroundColor DarkGray "$(Split-Path $Path -Leaf)`n"
                            $CanvasTopLeft = $Host.UI.RawUI.CursorPosition
                            $inputReceived = $true
                            break
                        }
                    } else {
                        $global:CurrentSaturation = [Math]::Min($global:CurrentSaturation + 20, 100)
                        $inputReceived = $true
                    }
                }
                "Z" {
                    $global:CurrentValue = [Math]::Max($global:CurrentValue - 20, 0)
                    $inputReceived = $true
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
                "M" {
                    $index = $global:Modes.IndexOf($global:CurrentMode)
                    $global:CurrentMode = $global:Modes[(($index + 1) % $global:Modes.Count)]
                    if($global:CurrentMode -eq "Snake") {
                        if($global:CurrentTool -eq "Pen") {
                            $global:Image[$currentPosition.X][$currentPosition.Y] = [int[]](Convert-HsvToRgb -Hue $global:CurrentHue -Saturation $global:CurrentSaturation -Value $global:CurrentValue)
                        } elseif($global:CurrentTool -eq "Eraser") {
                            $global:Image[$currentPosition.X][$currentPosition.Y] = $null
                        }
                    }
                    $inputReceived = $true
                }
                "O" {
                    if($key.Modifiers -eq "Control") {
                        while($true) {
                            Clear-Host
                            Write-Host "~ SpriteEditor.ps1 - Open a saved pixel art"
                            $jsonFiles = Get-ChildItem "$PSScriptRoot/sprites/" -Filter "*.json"
                            $latestJsonFiles = $jsonFiles `
                                | Select-Object Name, FullName, @{ Name = "Last Modified"; Expression = { (Get-ItemProperty $_.FullName).LastWriteTime} } `
                                | Sort-Object { $_."Last Modified" } `
                                | Select-Object -Last 10 *
                            $script:i = $latestJsonFiles.Count
                            $output = $latestJsonFiles | Select-Object @{ Name = "#"; Expression = { [int]$script:i-- }}, Name, "Last Modified"
                            Write-Host -Foreground DarkGray ($output | Format-Table * | Out-String).TrimEnd()
                            [Console]::CursorVisible = $true
                            Write-Host -Foreground DarkGray -NoNewline "`nEnter the # of the recent file to open or enter a file path: "
                            $Path = Read-Host
                            [Console]::CursorVisible = $false
                            if([int]::TryParse($Path, [ref]$null)) {
                                $Path = $latestJsonFiles[($script:i - $Path)].FullName
                            }
                            if(Test-Path $Path) {
                                Open-JsonSprite -Path $Path
                                $ImageWidth = $global:Image.Count
                                $ImageHeight = $global:Image[0].Count
                                if(!(Test-CanvasFitsInTerminal -ImageWidth $ImageWidth -ImageHeight $ImageHeight)) {
                                    Write-Warning "Your canvas is too large for the terminal window, try zooming out"
                                    while(!(Test-CanvasFitsInTerminal -ImageWidth $ImageWidth -ImageHeight $ImageHeight)) {
                                        Start-Sleep -Milliseconds 100
                                    }
                                }
                                Clear-Host
                                Write-Host -NoNewline "~ SpriteEditor.ps1 "
                                Write-Host -ForegroundColor DarkGray "$(Split-Path $Path -Leaf)`n"
                                $CanvasTopLeft = $Host.UI.RawUI.CursorPosition
                                $inputReceived = $true
                                break
                            } else {
                                Write-Error "File '$Path' doesn't exist"
                            }
                        }
                    }
                }
                "N" {
                    if($key.Modifiers -eq "Control") {
                        Clear-Host
                        Write-Host "~ SpriteEditor.ps1 - Create a new canvas`n"
                        while($true) {
                            Write-Host -ForegroundColor DarkGray -NoNewline "Enter a width in pixels: "
                            $ImageWidth = Read-Host
                            Write-Host -ForegroundColor DarkGray -NoNewline "Enter a height in pixels: "
                            $ImageHeight = Read-Host
                            if(!(Test-CanvasFitsInTerminal -ImageWidth $ImageWidth -ImageHeight $ImageHeight)) {
                                Write-Warning "Your canvas width is too large for the terminal window, try zooming out and entering the size you want again"
                                continue
                            }
                            $global:Image = @($null) * $ImageWidth
                            for($x = 0; $x -lt $ImageWidth; $x++) {
                                $global:Image[$x] = @($null) * $ImageHeight
                            }
                            Clear-Host
                            Write-Host "~ SpriteEditor.ps1`n"
                            $CanvasTopLeft = $Host.UI.RawUI.CursorPosition
                            $inputReceived = $true
                            break
                        }
                    }
                }
                "Spacebar" {
                    if($global:CurrentTool -eq "Pen") {
                        $global:Image[$currentPosition.X][$currentPosition.Y] = (Convert-HsvToRgb -Hue $global:CurrentHue -Saturation $global:CurrentSaturation -Value $global:CurrentValue)
                    }

                    if($global:CurrentTool -eq "Eraser") {
                        $global:Image[$currentPosition.X][$currentPosition.Y] = $null
                    }
                    $inputReceived = $true
                }
                "C" {
                    if($key.Modifiers -eq "Control") {
                        $inputReceived = $true
                        exit 1
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
                }
            }
            if($previousPosition.X -ne $currentPosition.X -or $previousPosition.Y -ne $currentPosition.Y) {
                if($global:CurrentMode -eq "Snake") {
                    if($global:CurrentTool -eq "Pen") {
                        $global:Image[$currentPosition.X][$currentPosition.Y] = (Convert-HsvToRgb -Hue $global:CurrentHue -Saturation $global:CurrentSaturation -Value $global:CurrentValue)
                    } elseif($global:CurrentTool -eq "Eraser") {
                        $global:Image[$currentPosition.X][$currentPosition.Y] = $null
                    }
                }
                $inputReceived = $true
            }
        }
    }
} finally {
    [Console]::CursorVisible = $true
}
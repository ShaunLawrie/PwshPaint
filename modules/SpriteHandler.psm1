$script:ToolboxDivider = "---------------"
$script:UndoStates = [System.Collections.Stack]::new()
$script:RedoStates = [System.Collections.Stack]::new()

function Convert-HsvToRgb {
    param(
        [int] $Hue,
        [int] $Saturation,
        [int] $Value
    )

    $valuePercent = $Value / 100.0

    $chroma = $valuePercent * ($Saturation / 100.0)
    $H = $Hue / 60.0
    $X = $chroma * (1.0 - [Math]::Abs($H % 2 - 1))

    $m = $valuePercent - $chroma
    $rgb = @($m, $m, $m)

    $xIndex = (7 - [Math]::Floor($H)) % 3
    $cIndex = [int]($H / 2) % 3

    $rgb[$xIndex] += $X
    $rgb[$cIndex] += $chroma

    return @(
        [int]($rgb[0] * 255),
        [int]($rgb[1] * 255),
        [int]($rgb[2] * 255)
    )
}

function Find-Hsv {
    param (
        [array] $Rgb
    )
    for($h = 0; $h -lt 360; $h += $global:HueChunkSize) {
        for($s = 0; $s -le 100; $s += 20) {
            for($v = 0; $v -le 100; $v += 20) {
                $colorSearch = Convert-HsvToRgb -Hue $h -Saturation $s -Value $v
                if(
                    [Math]::Abs($colorSearch[0] - $Rgb[0]) -lt 5 -and
                    [Math]::Abs($colorSearch[1] - $Rgb[1]) -lt 5 -and
                    [Math]::Abs($colorSearch[2] - $Rgb[2]) -lt 5
                ) {
                    return @{
                        H = $h
                        S = $s
                        V = $v
                    }
                }
            }
        }
    }
}

function Get-Color {
    param (
        [int] $R,
        [int] $G,
        [int] $B,
        [array] $Rgb,
        [array] $ForegroundRgb,
        [string] $Content = "  "
    )
    if($Rgb) {
        $R = $Rgb[0]
        $G = $Rgb[1]
        $B = $Rgb[2]
    }
    $cursorIndicatorColor = "255;255;255"
    if(($R + ($G + 5) + $B) -gt 255) {
        $cursorIndicatorColor = "0;0;0"
    }
    if($ForegroundRgb) {
        if(!($ForegroundRgb[0] -eq $R -and $ForegroundRgb[1] -eq $G -and $ForegroundRgb[2] -eq $B)) {
            $cursorIndicatorColor = "$($ForegroundRgb[0]);$($ForegroundRgb[1]);$($ForegroundRgb[2])"
        }
    }
    return ("$([Char]27)[48;2;${R};${G};${B}m$([Char]27)[38;2;${cursorIndicatorColor}m$Content$([Char]27)[0m")
}

function Get-ForegroundColoredText {
    param (
        [int] $R,
        [int] $G,
        [int] $B,
        [array] $Rgb,
        [string] $Content = ""
    )
    if($Rgb) {
        $R = $Rgb[0]
        $G = $Rgb[1]
        $B = $Rgb[2]
    }
    return ("$([Char]27)[38;2;${R};${G};${B}m$Content$([Char]27)[0m")
}

function Write-ToolboxHeaders {
    param (
        [array] $Headers,
        [int] $X,
        [int] $Y
    )
    foreach($header in $Headers) {
        [Console]::SetCursorPosition($X, [int]$Y++)
        [Console]::Write($header)
    }
    return $Y
}

function Write-ToolboxControls {
    param (
        [array] $Controls,
        [string] $CurrentControl,
        [int] $X,
        [int] $Y
    )
    foreach($tool in $Controls) {
        [Console]::SetCursorPosition($X, [int]$Y++)
        if(-not [string]::IsNullOrEmpty($CurrentControl)) {
            if($tool -eq $CurrentControl) {
                $tool = "[x] " + $tool
            } else {
                $tool = "[ ] " + $tool
            }
        }
        Write-Host -NoNewline -ForegroundColor DarkGray $tool
    }
    return $Y
}

function Write-Toolbox {
    param (
        [object] $ToolboxTopLeft
    )

    if($ToolboxTopLeft.X -lt 56) {
        $ToolboxTopLeft.X = 56
    }

    $toolboxOffsetY = $ToolboxTopLeft.Y

    $toolboxOffsetY = Write-ToolboxHeaders -Headers @("(T)ools: ", $script:ToolboxDivider) -X $ToolboxTopLeft.X -Y $toolboxOffsetY
    $toolboxOffsetY = Write-ToolboxControls -Controls $global:Tools -CurrentControl $global:CurrentTool -X $ToolboxTopLeft.X -Y $toolboxOffsetY

    $toolboxOffsetY = Write-ToolboxHeaders -Headers @("", "Commands:", $script:ToolboxDivider) -X $ToolboxTopLeft.X -Y $toolboxOffsetY
    Write-ToolboxControls -Controls $global:Commands -X $ToolboxTopLeft.X -Y $toolboxOffsetY | Out-Null
}

function Write-ColorControls {
    $controls = [System.Text.StringBuilder]::new()
    $controls.AppendLine() | Out-Null
    $currentColor = (Get-Color -Rgb (Convert-HsvToRgb -Hue $global:CurrentHue -Saturation $global:CurrentSaturation -Value $global:CurrentValue) -Content "      ")
    $controls.Append("  $currentColor  ") | Out-Null
    for($h = 0; $h -lt 360; $h += $global:HueChunkSize) {
        $content = "    "
        if($h -eq $global:CurrentHue) {
            $content = "  H  "
        }
        $controls.Append( (Get-Color -Rgb (Convert-HsvToRgb -Hue $h -Saturation 100 -Value 100) -Content $content) ) | Out-Null
    }
    $controls.Append(" q/w `n  $currentColor  ") | Out-Null
    for($s = 0; $s -le 100; $s += 20) {
        $content = "       "
        if($s -eq $global:CurrentSaturation) {
            $content = "   S   "
        }
        if($s -eq 0) {
            $content = $content.Substring(0, $content.Length - 1)
        }
        $controls.Append( (Get-Color -Rgb (Convert-HsvToRgb -Hue $global:CurrentHue -Saturation $s -Value $global:CurrentValue) -Content $content) ) | Out-Null
    }
    $controls.Append(" a/s `n  $currentColor  ") | Out-Null
    for($v = 0; $v -le 100; $v += 20) {
        $content = "       "
        if($v -eq $global:CurrentValue) {
            $content = "   V   "
        }
        if($v -eq 0) {
            $content = $content.Substring(0, $content.Length - 1)
        }
        $controls.Append( (Get-Color -Rgb (Convert-HsvToRgb -Hue $global:CurrentHue -Saturation $global:CurrentSaturation -Value $v) -Content $content) ) | Out-Null
    }
    $controls.Append(" z/x ") | Out-Null
    [Console]::WriteLine($controls)
}

function Write-Cursor {
    param (
        [object] $CurrentPosition
    )

    $cursorColor = Convert-HsvToRgb -Hue $global:CurrentHue -Saturation $global:CurrentSaturation -Value $global:CurrentValue
    for($x = -1; $x -lt 2; $x++) {
        $relativeX = $CurrentPosition.X + $x
        for($y = -1; $y -lt 2; $y++) {
            if($x -eq 0 -and $y -eq 0) {
                continue
            }
            $relativeY = $CurrentPosition.Y + $y
            if($relativeX -ge 0 -and $relativeX -lt $global:ImageWidth -and $relativeY -ge 0 -and $relativeY -lt $global:ImageHeight) {
                $currentCharacter = [char]0x2588
                if($y -lt 0) {
                    $currentCharacter = [char]0x2584
                } elseif($y -gt 0) {
                    $currentCharacter = [char]0x2580
                }
                $currentContent = "$currentCharacter$currentCharacter"
                if($x -lt 0) {
                    $currentContent = " $currentCharacter"
                } elseif($x -gt 0) {
                    $currentContent = "$currentCharacter "
                }
                $currentPixel = $global:Image[$relativeX][$relativeY]
                if($null -eq $currentPixel) {
                    $currentPixel = $global:BackgroundColors[(($relativeX + $relativeY) % 2)]
                }
                [Console]::SetCursorPosition($CanvasTopLeft.X + ($relativeX * 2), $CanvasTopLeft.Y + $relativeY)
                [Console]::Write((Get-Color -Rgb $currentPixel -ForegroundRgb $cursorColor -Content $currentContent))
            }
        }
    }
}

function Write-Frame {
    param (
        [object] $CanvasTopLeft,
        [object] $CurrentPosition,
        [object] $PreviousPosition
    )
    $cursorColor = Convert-HsvToRgb -Hue $global:CurrentHue -Saturation $global:CurrentSaturation -Value $global:CurrentValue
    if($global:CurrentTool -eq "Eraser") {
        $cursorColor = @(255, 255, 255)
    }

    Write-Toolbox -ToolboxTopLeft @{
        X = ($CanvasTopLeft.X + $global:ImageWidth) * 2 + 1
        Y = $CanvasTopLeft.Y
    }

    if(!$global:ForceRefresh -and ($PreviousPosition.X -ne $currentPosition.X -or $PreviousPosition.Y -ne $currentPosition.Y)) {
        # Just render the changes
        for($x = -1; $x -lt 2; $x++) {
            $relativeX = $PreviousPosition.X + $x
            for($y = -1; $y -lt 2; $y++) {
                $relativeY = $PreviousPosition.Y + $y
                if($relativeX -ge 0 -and $relativeX -lt $global:ImageWidth -and $relativeY -ge 0 -and $relativeY -lt $global:ImageHeight) {
                    [Console]::SetCursorPosition($CanvasTopLeft.X + ($relativeX * 2), $CanvasTopLeft.Y + $relativeY)
                    $currentPixel = $global:Image[$relativeX][$relativeY]
                    if($null -ne $currentPixel) {
                        Write-Host -NoNewline (Get-Color -Rgb $currentPixel)
                    } else {
                        Write-Host -NoNewline (Get-Color -Rgb $global:BackgroundColors[(($relativeX + $relativeY) % 2)])
                    }           
                }
            }
        }
    } else {
        # Render the entire image
        $frame = [System.Text.StringBuilder]::new()
        for($y = 0; $y -lt $global:ImageHeight; $y++) {
            for($x = 0; $x -lt $global:ImageWidth; $x++) {
                if($y -eq $CurrentPosition.Y -and ($x + 1) -eq $CurrentPosition.X) {
                    $frame.Append( (Get-Color -Rgb $cursorColor -Content "$([char]0x257A)$([char]0x2578)") ) | Out-Null
                } else {
                    $currentPixel = $global:Image[$x][$y]
                    if($null -ne $currentPixel) {
                        $frame.Append( (Get-Color -Rgb $currentPixel) ) | Out-Null
                    } else {
                        $frame.Append( (Get-Color -Rgb $global:BackgroundColors[(($x + $y) % 2)]) ) | Out-Null
                    }
                }
            }
            $frame.AppendLine() | Out-Null
        }

        [Console]::SetCursorPosition($CanvasTopLeft.X, $CanvasTopLeft.Y)
        [Console]::Write($frame)
        $global:ForceRefresh = $false
    }

    Write-Cursor -CurrentPosition $CurrentPosition    
    [Console]::SetCursorPosition($CanvasTopLeft.X, $CanvasTopLeft.Y + $global:ImageHeight)
    Write-ColorControls
}

function Out-Gif {
    param (
        [string] $Path
    )
    $attempts = 0
    while($attempts -lt 2) {
        $attempts++
        try {
            $bitmap = [System.Drawing.Bitmap]::new($global:ImageWidth, $global:ImageHeight, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
            $palette = @()
            for($y = 0; $y -lt $global:ImageHeight; $y++) {
                for($x = 0; $x -lt $global:ImageWidth; $x++) {
                    $currentPixel = $global:Image[$x][$y]
                    if($null -ne $currentPixel) {
                        $c = [System.Drawing.Color]::FromArgb(255, $currentPixel[0], $currentPixel[1], $currentPixel[2])
                        $bitmap.SetPixel($x, $y, $c)
                        if(!$palette.Contains($c)) {
                            $palette += $c
                        }
                    } else {
                        $bitmap.SetPixel($x, $y, [System.Drawing.Color]::FromArgb(0, 0, 0, 0))
                    }
                }
            }

            $bitmap.Save(($Path -replace "[^.]+$", "png"), [System.Drawing.Imaging.ImageFormat]::Png)
        } catch {
            [System.Reflection.Assembly]::LoadWithPartialName("System.Drawing") | Out-Null
        }
    }
}

function Open-JsonSprite {
    param (
        [string] $Path,
        [string] $Json,
        [bool] $ResetUndo = $true
    )
    if($Path) {
        $Obj = Get-Content $Path | ConvertFrom-Json
    } else {
        $Obj = $Json | ConvertFrom-Json
    }

    if($ResetUndo) {
        $script:UndoStates = [System.Collections.Stack]::new()
        $script:RedoStates = [System.Collections.Stack]::new()
    }
    
    # Json saving on powershell 5 saves arrays with simple types as complex objects instead of vanilla json arrays
    # convert these back by grabbing their "value"
    $global:Image = @($null) * $Obj.Count
    for($i = 0; $i -lt $global:Image.Count; $i++){
        if($Obj[$i].value) {
            $global:Image[$i] = $Obj[$i].value
        } else {
            $global:Image[$i] = $Obj[$i]
        }
    }
}

function Save-JsonSprite {
    param (
        [string] $Path,
        [string] $ScriptRoot
    )
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
            $Path = Join-Path "$ScriptRoot/sprites" $Path
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
        Out-Gif -Path ($Path -replace "[^\.]+$", "gif")
        Write-Host -ForegroundColor DarkGray -NoNewline "Saved at $Path"
        [Console]::CursorVisible = $false
        0..3 | Foreach-Object {
            Start-Sleep -Milliseconds 500
            Write-Host -ForegroundColor DarkGray -NoNewline "."
        }
        Clear-Host
        Write-Host -NoNewline "~ SpriteEditor.ps1 "
        Write-Host -ForegroundColor DarkGray "$(Split-Path $Path -Leaf)`n"
        break
    }
}

function Open-JsonSpriteDialog {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSUseDeclaredVarsMoreThanAssignments","",Scope="Function")]
    param (
        [string] $ScriptRoot
    )
    while($true) {
        Clear-Host
        Write-Host "~ SpriteEditor.ps1 - Open a saved pixel art"
        $jsonFiles = Get-ChildItem "$ScriptRoot/sprites/" -Filter "*.json"
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
            $global:ImageWidth = $global:Image.Count
            $global:ImageHeight = $global:Image[0].Count
            if(!(Test-CanvasFitsInTerminal)) {
                Write-Warning "Your canvas is too large for the terminal window, try zooming out"
                while(!(Test-CanvasFitsInTerminal)) {
                    Start-Sleep -Milliseconds 100
                }
            }
            Clear-Host
            Write-Host -NoNewline "~ SpriteEditor.ps1 "
            Write-Host -ForegroundColor DarkGray "$(Split-Path $Path -Leaf)`n"
            break
        } else {
            Write-Error "File '$Path' doesn't exist"
        }
    }
}


function New-JsonSpriteDialog {
    Clear-Host
    Write-Host "~ SpriteEditor.ps1 - Create a new canvas`n"
    while($true) {
        Write-Host -ForegroundColor DarkGray -NoNewline "Enter a width in pixels: "
        $global:ImageWidth = Read-Host
        Write-Host -ForegroundColor DarkGray -NoNewline "Enter a height in pixels: "
        $global:ImageHeight = Read-Host
        if(!(Test-CanvasFitsInTerminal)) {
            Write-Warning "Your canvas width is too large for the terminal window, try zooming out and entering the size you want again"
            continue
        }
        $global:Image = @($null) * $global:ImageWidth
        for($x = 0; $x -lt $global:ImageWidth; $x++) {
            $global:Image[$x] = @($null) * $global:ImageHeight
        }
        Clear-Host
        Write-Host "~ SpriteEditor.ps1`n"
        break
    }
}

function Test-CanvasFitsInTerminal {
    return ($global:ImageWidth -lt (($Host.UI.RawUI.WindowSize.Width - $script:ToolboxDivider.Length) / 2) -and $global:ImageHeight -lt ($Host.UI.RawUI.WindowSize.Height - 7))
}

function Wait-ForCanvasToFitInTerminal {
    [Console]::TreatControlCAsInput = $false
    if(!(Test-CanvasFitsInTerminal)) {
        Write-Warning "Your canvas is too large for the terminal window, try zooming out"
        while(!(Test-CanvasFitsInTerminal)) {
            Start-Sleep -Milliseconds 100
        }
    }
    Clear-Host
    Write-Host -NoNewline "~ SpriteEditor.ps1 "
    if($Path) {
        Write-Host -ForegroundColor DarkGray "$(Split-Path $Path -Leaf)`n"
    } else {
        Write-Host "`n"
    }
}

function Add-Fill {
    param (
        [array] $OriginalColor,
        [object] $CurrentPosition
    )
    $global:Image[$CurrentPosition.X][$CurrentPosition.Y] = (Convert-HsvToRgb -Hue $global:CurrentHue -Saturation $global:CurrentSaturation -Value $global:CurrentValue)
    # Don't want to color on diagonals
    $pixelsToTryColor = @(
        @(-1, 0),
        @(1, 0),
        @(0, 1),
        @(0, -1)
    )

    foreach($pixel in $pixelsToTryColor) {
        $relativeX = $CurrentPosition.X + $pixel[0]
        $relativeY = $CurrentPosition.Y + $pixel[1]
        if($relativeX -ge 0 -and $relativeX -lt $global:ImageWidth -and $relativeY -ge 0 -and $relativeY -lt $global:ImageHeight) {
            $refObject = $global:Image[$relativeX][$relativeY]
            $diffObject = $OriginalColor
            if($null -eq $refObject) {
                $refObject = @(-1, -1, -1)
            }
            if($null -eq $diffObject) {
                $diffObject = @(-1, -1, -1)
            }
            if($null -eq (Compare-Object -ReferenceObject $refObject -DifferenceObject $diffObject)) {
                Add-Fill -OriginalColor $OriginalColor -CurrentPosition @{ X = $relativeX; Y = $relativeY } -ImageWidth $global:ImageWidth -ImageHeight $global:ImageHeight
            }
        }
    }
}

function Remove-Fill {
    param (
        [array] $OriginalColor,
        [object] $CurrentPosition
    )
    $global:Image[$CurrentPosition.X][$CurrentPosition.Y] = $null
    for($x = -1; $x -lt 2; $x++) {
        $relativeX = $CurrentPosition.X + $x
        for($y = -1; $y -lt 2; $y++) {
            $relativeY = $CurrentPosition.Y + $y
            if($relativeX -ge 0 -and $relativeX -lt $global:ImageWidth -and $relativeY -ge 0 -and $relativeY -lt $global:ImageHeight) {
                $refObject = $global:Image[$relativeX][$relativeY]
                $diffObject = $OriginalColor
                if($null -eq $refObject) {
                    $refObject = @(-1, -1, -1)
                }
                if($null -eq $diffObject) {
                    $diffObject = @(-1, -1, -1)
                }
                if($null -eq (Compare-Object -ReferenceObject $refObject -DifferenceObject $diffObject)) {
                    Remove-Fill -OriginalColor $OriginalColor -CurrentPosition @{ X = $relativeX; Y = $relativeY } -ImageWidth $global:ImageWidth -ImageHeight $global:ImageHeight
                }
            }
        }
    }
}

function Push-UndoState {
    $state = $global:Image | ConvertTo-Json -Depth 25
    $script:UndoStates.Push($state)
}

function Pop-UndoState {
    $currentState = $global:Image | ConvertTo-Json -Depth 25
    $targetState = $currentState
    while($script:UndoStates.Count -gt 0) {
        $targetState = $script:UndoStates.Pop()
        $script:RedoStates.Push($targetState)
        if($targetState -ne $currentState) {
            break
        }
    }
    Open-JsonSprite -Json $targetState -ResetUndo $false
}

function Pop-RedoState {
    $currentState = $global:Image | ConvertTo-Json -Depth 25
    $targetState = $currentState
    while($script:RedoStates.Count -gt 0) {
        $targetState = $script:RedoStates.Pop()
        $script:UndoStates.Push($targetState)
        if($targetState -ne $currentState) {
            break
        }
    }
    Open-JsonSprite -Json $targetState -ResetUndo $false
}
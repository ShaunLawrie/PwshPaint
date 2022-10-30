[Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSAvoidUsingWriteHost","",Scope="Function")]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSUseShouldProcessForStateChangingFunctions","",Scope="Function")]
param ()

$script:AppSettings = $null
$script:KeyBindings = $null
$script:SwitchToolControlHeader = $null
$script:Commands = $null
$script:NavigationControls = $null
$script:Image = $null
$script:ImageWidth = $null
$script:ImageHeight = $null

$script:Tools = @("Pen", "Fill", "Snake", "Dropper", "Pen Eraser", "Fill Eraser")
$script:CurrentHue = 0
$script:CurrentSaturation = 100
$script:CurrentValue = 100
$script:HueChunkSize = 36
$script:CurrentTool = "Pen"
$script:ForceRefresh = $false
$script:BackgroundColors = @(@(35, 35, 35), @(30, 30, 30))

$script:ToolboxDivider = "------------------"
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

    if($xIndex -eq $cIndex) {
        $cIndex = ($cIndex + 1) % 3
    }

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
    for($h = 0; $h -lt 360; $h += $script:HueChunkSize) {
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

function Write-ToolboxHeaderCollection {
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

function Write-ToolboxControlCollection {
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

function Get-AnnotatedCommandCollection {
    param (
        [array] $Commands,
        [string] $Section
    )
    $annotatedCommands = @()
    foreach($command in $Commands) {
        $keybinding = $script:Keybindings."$Section"."$command"
        $modifier = $null
        if($keybinding.Modifier) {
            $bound = $command + ("(" + $keybinding.Modifier + "+" + $keybinding.Key).PadLeft($script:ToolboxDivider.Length - 1 - $command.Length) + ")"
            $modifier = $keybinding.Modifier
        } else {
            $bound = $command + ("(" + $keybinding.Key).PadLeft($script:ToolboxDivider.Length - 1 - $command.Length) + ")"
        }
        $annotatedCommands += @{
            Text = $bound
            Key = $keybinding.Key
            Modifier = $modifier
        }
    }
    return $annotatedCommands
}

function Get-ActionForKey {
    param (
        [object] $Key
    )

    if($Key.Key -eq "Spacebar") {
        return "Spacebar"
    }

    foreach($section in $script:Keybindings.PSObject.Properties.Value) {
        if($Key.Modifiers -ne 0) {
            $foundKey = $section.PSObject.Properties | Where-Object { $_.Value.Key -eq $Key.Key -and $_.Value.Modifier -eq $Key.Modifiers }
            if($foundKey) {
                return $foundKey.Name
            }
        }
    }

    foreach($section in $script:Keybindings.PSObject.Properties.Value) {
        $foundKey = $section.PSObject.Properties | Where-Object { $_.Value.Key -eq $Key.Key }
        if($foundKey) {
            return $foundKey.Name
        }
    }
}

function Get-SwitchToolControlHeader {
    $toolKeybinding = $script:Keybindings.Tools.SwitchTool
    if($toolKeybinding.Modifier) {
        $bound = $toolKeybinding.Modifier + "+" + $toolKeybinding.Key
    } else {
        $bound = $toolKeybinding.Key
    }
    return "Tools: " + ("(" + $bound + ")").PadLeft($script:ToolboxDivider.Length - 6 - $bound.Length)
}

function Write-Toolbox {
    param (
        [object] $ToolboxTopLeft
    )

    if($ToolboxTopLeft.X -lt 56) {
        $ToolboxTopLeft.X = 56
    }

    $toolboxOffsetY = $ToolboxTopLeft.Y
    $toolboxOffsetY = Write-ToolboxHeaderCollection -Headers @($script:SwitchToolControlHeader, $script:ToolboxDivider) -X $ToolboxTopLeft.X -Y $toolboxOffsetY
    $toolboxOffsetY = Write-ToolboxControlCollection -Controls $script:Tools -CurrentControl $script:CurrentTool -X $ToolboxTopLeft.X -Y $toolboxOffsetY

    $toolboxOffsetY = Write-ToolboxHeaderCollection -Headers @("", "Commands:", $script:ToolboxDivider) -X $ToolboxTopLeft.X -Y $toolboxOffsetY
    $toolboxOffsetY = Write-ToolboxControlCollection -Controls $script:Commands.Text -X $ToolboxTopLeft.X -Y $toolboxOffsetY

    $toolboxOffsetY = Write-ToolboxHeaderCollection -Headers @("", "Navigation:", $script:ToolboxDivider) -X $ToolboxTopLeft.X -Y $toolboxOffsetY
    $toolboxOffsetY = Write-ToolboxControlCollection -Controls $script:NavigationControls.Text -X $ToolboxTopLeft.X -Y $toolboxOffsetY
}

function Get-ColorKeyCollection {
    $types = @("Hue", "Saturation", "Value")
    $controlText = @{}
    foreach($type in $types) {
        $leftControl = $script:KeyBindings.Color."${type}Left"
        if($leftControl.Modifier) {
            $controlText[$type] = $leftControl.Modifier + "+" + $leftControl.Key + "/"
        } else {
            $controlText[$type] = $leftControl.Key + "/"
        }

        $rightControl = $script:KeyBindings.Color."${type}Right"
        if($rightControl.Modifier) {
            $controlText[$type] += $rightControl.Modifier + "+" + $rightControl.Key
        } else {
            $controlText[$type] += $rightControl.Key
        }
    }

    return @{
        Hue = $controlText["Hue"]
        Saturation = $controlText["Saturation"]
        Value = $controlText["Value"]
    }
}

function Write-ColorControlCollection {
    $controls = [System.Text.StringBuilder]::new()
    $controls.AppendLine() | Out-Null
    $currentColor = (Get-Color -Rgb (Convert-HsvToRgb -Hue $script:CurrentHue -Saturation $script:CurrentSaturation -Value $script:CurrentValue) -Content "      ")
    $controls.Append("  $currentColor  ") | Out-Null
    for($h = 0; $h -lt 360; $h += $script:HueChunkSize) {
        $content = "    "
        if($h -eq $script:CurrentHue) {
            $content = "  H  "
        }
        $controls.Append( (Get-Color -Rgb (Convert-HsvToRgb -Hue $h -Saturation 100 -Value 100) -Content $content) ) | Out-Null
    }
    $controls.Append(" $($script:ColorKeys.Hue) `n  $currentColor  ") | Out-Null
    for($s = 0; $s -le 100; $s += 20) {
        $content = "       "
        if($s -eq $script:CurrentSaturation) {
            $content = "   S   "
        }
        if($s -eq 0) {
            $content = $content.Substring(0, $content.Length - 1)
        }
        $controls.Append( (Get-Color -Rgb (Convert-HsvToRgb -Hue $script:CurrentHue -Saturation $s -Value $script:CurrentValue) -Content $content) ) | Out-Null
    }
    $controls.Append(" $($script:ColorKeys.Saturation) `n  $currentColor  ") | Out-Null
    for($v = 0; $v -le 100; $v += 20) {
        $content = "       "
        if($v -eq $script:CurrentValue) {
            $content = "   V   "
        }
        if($v -eq 0) {
            $content = $content.Substring(0, $content.Length - 1)
        }
        $controls.Append( (Get-Color -Rgb (Convert-HsvToRgb -Hue $script:CurrentHue -Saturation $script:CurrentSaturation -Value $v) -Content $content) ) | Out-Null
    }
    $controls.Append(" $($script:ColorKeys.Value) ") | Out-Null
    [Console]::WriteLine($controls)
}

function Write-Cursor {
    param (
        [object] $CurrentPosition
    )

    $cursorColor = Convert-HsvToRgb -Hue $script:CurrentHue -Saturation $script:CurrentSaturation -Value $script:CurrentValue
    for($x = -1; $x -lt 2; $x++) {
        $relativeX = $CurrentPosition.X + $x
        for($y = -1; $y -lt 2; $y++) {
            if($x -eq 0 -and $y -eq 0) {
                continue
            }
            $relativeY = $CurrentPosition.Y + $y
            if($relativeX -ge 0 -and $relativeX -lt $script:ImageWidth -and $relativeY -ge 0 -and $relativeY -lt $script:ImageHeight) {
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
                $currentPixel = $script:Image[$relativeX][$relativeY]
                if($null -eq $currentPixel) {
                    $currentPixel = $script:BackgroundColors[(($relativeX + $relativeY) % 2)]
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
    $cursorColor = Convert-HsvToRgb -Hue $script:CurrentHue -Saturation $script:CurrentSaturation -Value $script:CurrentValue
    if($script:CurrentTool -eq "Eraser") {
        $cursorColor = @(255, 255, 255)
    }

    Write-Toolbox -ToolboxTopLeft @{
        X = ($CanvasTopLeft.X + $script:ImageWidth) * 2 + 1
        Y = $CanvasTopLeft.Y
    }

    if(!$script:ForceRefresh -and ($PreviousPosition.X -ne $currentPosition.X -or $PreviousPosition.Y -ne $currentPosition.Y)) {
        # Just render the changes
        for($x = -1; $x -lt 2; $x++) {
            $relativeX = $PreviousPosition.X + $x
            for($y = -1; $y -lt 2; $y++) {
                $relativeY = $PreviousPosition.Y + $y
                if($relativeX -ge 0 -and $relativeX -lt $script:ImageWidth -and $relativeY -ge 0 -and $relativeY -lt $script:ImageHeight) {
                    [Console]::SetCursorPosition($CanvasTopLeft.X + ($relativeX * 2), $CanvasTopLeft.Y + $relativeY)
                    $currentPixel = $script:Image[$relativeX][$relativeY]
                    if($null -ne $currentPixel) {
                        Write-Host -NoNewline (Get-Color -Rgb $currentPixel)
                    } else {
                        Write-Host -NoNewline (Get-Color -Rgb $script:BackgroundColors[(($relativeX + $relativeY) % 2)])
                    }
                }
            }
        }
    } else {
        # Render the entire image
        $frame = [System.Text.StringBuilder]::new()
        for($y = 0; $y -lt $script:ImageHeight; $y++) {
            for($x = 0; $x -lt $script:ImageWidth; $x++) {
                if($y -eq $CurrentPosition.Y -and ($x + 1) -eq $CurrentPosition.X) {
                    $frame.Append( (Get-Color -Rgb $cursorColor -Content "$([char]0x257A)$([char]0x2578)") ) | Out-Null
                } else {
                    $currentPixel = $script:Image[$x][$y]
                    if($null -ne $currentPixel) {
                        $frame.Append( (Get-Color -Rgb $currentPixel) ) | Out-Null
                    } else {
                        $frame.Append( (Get-Color -Rgb $script:BackgroundColors[(($x + $y) % 2)]) ) | Out-Null
                    }
                }
            }
            $frame.AppendLine() | Out-Null
        }

        [Console]::SetCursorPosition($CanvasTopLeft.X, $CanvasTopLeft.Y)
        [Console]::Write($frame)
        $script:ForceRefresh = $false
    }

    Write-Cursor -CurrentPosition $CurrentPosition
    [Console]::SetCursorPosition($CanvasTopLeft.X, $CanvasTopLeft.Y + $script:ImageHeight)
    Write-ColorControlCollection
}

function Out-Png {
    param (
        [string] $Path
    )
    $attempts = 0
    while($attempts -lt 2) {
        $attempts++
        try {
            $bitmap = [System.Drawing.Bitmap]::new($script:ImageWidth, $script:ImageHeight, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
            $palette = @()
            for($y = 0; $y -lt $script:ImageHeight; $y++) {
                for($x = 0; $x -lt $script:ImageWidth; $x++) {
                    $currentPixel = $script:Image[$x][$y]
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
            return
        } catch {
            [System.Reflection.Assembly]::LoadWithPartialName("System.Drawing") | Out-Null
        }
    }
    Write-Warning "Png was not saved, this is only supported on Windows"
}

function Open-JsonPainting {
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
    $script:Image = @($null) * $Obj.Count
    for($i = 0; $i -lt $script:Image.Count; $i++){
        if($Obj[$i].value) {
            $script:Image[$i] = $Obj[$i].value
        } else {
            $script:Image[$i] = $Obj[$i]
        }
    }
}

function Save-JsonPainting {
    param (
        [string] $Path
    )
    while($true) {
        Clear-Host
        Write-Host "~ PwshPaint - Save your pixel art`n"
        [Console]::CursorVisible = $true
        if($Path) {
            $defaultPath = $Path
            Write-Host -ForegroundColor DarkGray "Press ENTER to use the default '$Path'"
            Write-Host -NoNewline -ForegroundColor DarkGray "Enter a filename or path to save the image json: "
            $Path = Read-Host
            if([string]::IsNullOrEmpty($Path)) {
                $Path = $defaultPath
            }
        } else {
            Write-Host -NoNewline -ForegroundColor DarkGray "Enter a filename or path to save the image json: "
            $Path = Read-Host
        }
        if($Path -notmatch "\.json$") {
            $Path = $Path + ".json"
        }
        if($Path -eq (Split-Path $Path -Leaf)) {
            $Path = Join-Path "$PSScriptRoot/../Images" $Path
        }
        if(Test-Path $Path) {
            Write-Host -ForegroundColor Yellow -NoNewline "A file exists at $Path, do you want to overwrite it? (y/n) "
            $answer = Read-Host
            if($answer -ne "y") {
                continue
            }
        }
        $c = $script:Image | ConvertTo-Json -Depth 25
        try {
            Set-Content -Path $Path -Value $c
            Out-Png -Path ($Path -replace "[^\.]+$", "png")
        } catch {
            Write-Host -ForegroundColor Yellow -NoNewline "Failed to save at '$Path', try another file location"
            [Console]::CursorVisible = $false
            0..3 | Foreach-Object {
                Start-Sleep -Milliseconds 500
                Write-Host -ForegroundColor Yellow -NoNewline "."
            }
            continue
        }
        Write-Host -ForegroundColor DarkGray -NoNewline "Saved at '$Path'"
        [Console]::CursorVisible = $false
        0..3 | Foreach-Object {
            Start-Sleep -Milliseconds 500
            Write-Host -ForegroundColor DarkGray -NoNewline "."
        }
        Clear-Host
        Write-Host -NoNewline "~ PwshPaint "
        Write-Host -ForegroundColor DarkGray "$(Split-Path $Path -Leaf)`n"
        break
    }
}

function Open-JsonPaintingDialog {
    while($true) {
        Clear-Host
        Write-Host "~ PwshPaint - Open a saved pixel art"
        $jsonFiles = Get-ChildItem "$PSScriptRoot/../Images/" -Filter "*.json"
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
            Open-JsonPainting -Path $Path
            $script:ImageWidth = $script:Image.Count
            $script:ImageHeight = $script:Image[0].Count
            if(!(Test-CanvasFitsInTerminal)) {
                Write-Warning "Your canvas is too large for the terminal window, try zooming out"
                while(!(Test-CanvasFitsInTerminal)) {
                    Start-Sleep -Milliseconds 100
                }
            }
            Clear-Host
            Write-Host -NoNewline "~ PwshPaint "
            Write-Host -ForegroundColor DarkGray "$(Split-Path $Path -Leaf)`n"
            break
        } else {
            Write-Error "File '$Path' doesn't exist"
        }
    }
}


function New-JsonPaintingDialog {
    Clear-Host
    Write-Host "~ PwshPaint - Create a new canvas`n"
    while($true) {
        Write-Host -ForegroundColor DarkGray -NoNewline "Enter a width in pixels: "
        $script:ImageWidth = Read-Host
        Write-Host -ForegroundColor DarkGray -NoNewline "Enter a height in pixels: "
        $script:ImageHeight = Read-Host
        if(!(Test-CanvasFitsInTerminal)) {
            Write-Warning "Your canvas width is too large for the terminal window, try zooming out and entering the size you want again"
            continue
        }
        $script:Image = @($null) * $script:ImageWidth
        for($x = 0; $x -lt $script:ImageWidth; $x++) {
            $script:Image[$x] = @($null) * $script:ImageHeight
        }
        Clear-Host
        Write-Host "~ PwshPaint`n"
        break
    }
}

function Test-CanvasFitsInTerminal {
    return ($script:ImageWidth -lt (($Host.UI.RawUI.WindowSize.Width - $script:ToolboxDivider.Length) / 2) -and $script:ImageHeight -lt ($Host.UI.RawUI.WindowSize.Height - 7))
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
    Write-Host -NoNewline "~ PwshPaint "
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

    $currentFillColor = (Convert-HsvToRgb -Hue $script:CurrentHue -Saturation $script:CurrentSaturation -Value $script:CurrentValue)

    if($null -ne $OriginalColor -and $null -eq (Compare-Object -ReferenceObject $currentFillColor -DifferenceObject $script:Image[$CurrentPosition.X][$CurrentPosition.Y] -SyncWindow 0)) {
        return
    } else {
        $script:Image[$CurrentPosition.X][$CurrentPosition.Y] = $currentFillColor
    }
    
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
        if($relativeX -ge 0 -and $relativeX -lt $script:ImageWidth -and $relativeY -ge 0 -and $relativeY -lt $script:ImageHeight) {
            $refObject = $script:Image[$relativeX][$relativeY]
            $diffObject = $OriginalColor
            if($null -eq $refObject) {
                $refObject = @(-1, -1, -1)
            }
            if($null -eq $diffObject) {
                $diffObject = @(-1, -1, -1)
            }
            if($null -eq (Compare-Object -ReferenceObject $refObject -DifferenceObject $diffObject -SyncWindow 0)) {
                Add-Fill -OriginalColor $OriginalColor -CurrentPosition @{ X = $relativeX; Y = $relativeY } -ImageWidth $script:ImageWidth -ImageHeight $script:ImageHeight
            }
        }
    }
}

function Remove-Fill {
    param (
        [array] $OriginalColor,
        [object] $CurrentPosition
    )
    if($null -eq $script:Image[$CurrentPosition.X][$CurrentPosition.Y]) {
        return
    }

    $script:Image[$CurrentPosition.X][$CurrentPosition.Y] = $null
    $pixelsToTryColor = @(
        @(-1, 0),
        @(1, 0),
        @(0, 1),
        @(0, -1)
    )

    foreach($pixel in $pixelsToTryColor) {
        $relativeX = $CurrentPosition.X + $pixel[0]
        $relativeY = $CurrentPosition.Y + $pixel[1]
        if($relativeX -ge 0 -and $relativeX -lt $script:ImageWidth -and $relativeY -ge 0 -and $relativeY -lt $script:ImageHeight) {
            $refObject = $script:Image[$relativeX][$relativeY]
            $diffObject = $OriginalColor
            if($null -eq $refObject) {
                $refObject = @(-1, -1, -1)
            }
            if($null -eq $diffObject) {
                $diffObject = @(-1, -1, -1)
            }
            if($null -eq (Compare-Object -ReferenceObject $refObject -DifferenceObject $diffObject -SyncWindow 0)) {
                Remove-Fill -OriginalColor $OriginalColor -CurrentPosition @{ X = $relativeX; Y = $relativeY } -ImageWidth $script:ImageWidth -ImageHeight $script:ImageHeight
            }
        }
    }
}

function Push-UndoState {
    $state = $script:Image | ConvertTo-Json -Depth 25
    $script:UndoStates.Push($state)
}

function Pop-UndoState {
    $currentState = $script:Image | ConvertTo-Json -Depth 25
    $targetState = $currentState
    while($script:UndoStates.Count -gt 0) {
        $targetState = $script:UndoStates.Pop()
        $script:RedoStates.Push($targetState)
        if($null -ne (Compare-Object -ReferenceObject $currentState -DifferenceObject $targetState -SyncWindow 0)) {
            break
        }
    }
    Open-JsonPainting -Json $targetState -ResetUndo $false
}

function Pop-RedoState {
    $currentState = $script:Image | ConvertTo-Json -Depth 25
    $targetState = $currentState
    while($script:RedoStates.Count -gt 0) {
        $targetState = $script:RedoStates.Pop()
        $script:UndoStates.Push($targetState)
        if($null -ne (Compare-Object -ReferenceObject $currentState -DifferenceObject $targetState -SyncWindow 0)) {
            break
        }
    }
    Open-JsonPainting -Json $targetState -ResetUndo $false
}

function Invoke-Paint {
    <#
    .Synopsis
        Start the PwshPaint terminal based image editor
    .Description
        Opens a terminal based image editor that reads and writes image data from JSON files located in the Images folder of the module
    .Example
        # Open the painting editor with a new empty image
        Invoke-Paint
    .Example
        # Open the painting editor with a new empty image of a specific size
        Invoke-Paint -ImageWidth 10 -ImageHeight 10
    .Example
        # Open the painting editor with an existing image from the module images folder
        Invoke-Paint -Path "clippy.json"
    .Example
        # Open the painting editor with an existing image from an absolute file path
        Invoke-Paint -Path "C:\Users\shaun\Desktop\hello.json"
    .Example
        # Open the painting editor with the Vim keybindings (hjkl) instead of arrow keys for navigation
        Invoke-Paint -VimBindings
    #>
    param (
        [string] $Path,
        [int] $ImageWidth = 28,
        [int] $ImageHeight = 28,
        [switch] $VimBindings
    )

    $AppSettingsPath = if($VimBindings) { "$PSScriptRoot/appsettings.vim.json" } else { "$PSScriptRoot/appsettings.json" }

    if(!(Test-Path $AppSettingsPath)) {
        Write-Error "Could not find a settings file at '$AppSettingsPath'"
    }

    $script:AppSettings = Get-Content $AppSettingsPath | ConvertFrom-Json
    $script:KeyBindings = $script:AppSettings.Keybindings
    $script:SwitchToolControlHeader = Get-SwitchToolControlHeader
    $script:ColorKeys = Get-ColorKeyCollection
    $script:Commands = Get-AnnotatedCommandCollection -Commands @("New", "Open", "Save", "Undo", "Redo", "Close") -Section "Commands"
    $script:NavigationControls = Get-AnnotatedCommandCollection -Commands @("Left", "Right", "Up", "Down", "Draw/Use") -Section "Navigation"
    $script:Image = @($null) * $ImageWidth
    $script:ImageWidth = $ImageWidth
    $script:ImageHeight = $ImageHeight

    if($Path) {
        if(Test-Path $Path) {
            Open-JsonPainting -Path $Path
            $ImageWidth = $script:Image.Count
            $ImageHeight = $script:Image[0].Count
        } elseif(Test-Path "$PSScriptRoot/../Images/$Path") {
            $Path = "$PSScriptRoot/../Images/$Path"
            Open-JsonPainting -Path $Path
            $ImageWidth = $script:Image.Count
            $ImageHeight = $script:Image[0].Count
        } else {
            Write-Error "Could not find an image to load at $Path"
        }
    } else {
        for($x = 0; $x -lt $ImageWidth; $x++) {
            $script:Image[$x] = @($null) * $ImageHeight
        }
    }
    Push-UndoState

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
                    $script:ForceRefresh = $true
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
                        $script:CurrentHue = [Math]::Max($script:CurrentHue - $script:HueChunkSize, 0)
                        $inputReceived = $true
                    }
                    "HueRight" {
                        $script:CurrentHue = [Math]::Min($script:CurrentHue + $script:HueChunkSize, 360 - $script:HueChunkSize)
                        $inputReceived = $true
                    }
                    "SaturationLeft" {
                        $script:CurrentSaturation = [Math]::Max($script:CurrentSaturation - 20, 0)
                        $inputReceived = $true
                    }
                    "SaturationRight" {
                        $script:CurrentSaturation = [Math]::Min($script:CurrentSaturation + 20, 100)
                        $inputReceived = $true
                    }
                    "Undo" {
                        Pop-UndoState
                        $script:ForceRefresh = $true
                        $inputReceived = $true
                    }
                    "ValueLeft" {
                        $script:CurrentValue = [Math]::Max($script:CurrentValue - 20, 0)
                        $inputReceived = $true
                    }
                    "ValueRight" {
                        $script:CurrentValue = [Math]::Min($script:CurrentValue + 20, 100)
                        $inputReceived = $true
                    }
                    "SwitchTool" {
                        $index = $script:Tools.IndexOf($script:CurrentTool)
                        if($key.Modifiers -eq "Shift") {
                            $targetIndex = $index - 1
                            if($targetIndex -lt 0) {
                                $targetIndex = $script:Tools.Count - 1
                            }
                        } else {
                            $targetIndex = ($index + 1) % $script:Tools.Count
                        }
                        $script:CurrentTool = $script:Tools[$targetIndex]
                        $inputReceived = $true
                    }
                    "Open" {
                        Open-JsonPaintingDialog
                        $inputReceived = $true
                    }
                    "New" {
                        New-JsonPaintingDialog
                        $inputReceived = $true
                    }
                    "Save" {
                        Save-JsonPainting -Path $Path
                        $inputReceived = $true
                    }
                    "Spacebar" {

                        switch($script:CurrentTool) {
                            "Pen" {
                                $script:Image[$currentPosition.X][$currentPosition.Y] = (Convert-HsvToRgb -Hue $script:CurrentHue -Saturation $script:CurrentSaturation -Value $script:CurrentValue)
                            }
                            "Snake" {
                                $script:Image[$currentPosition.X][$currentPosition.Y] = (Convert-HsvToRgb -Hue $script:CurrentHue -Saturation $script:CurrentSaturation -Value $script:CurrentValue)
                            }
                            "Pen Eraser" {
                                $script:Image[$currentPosition.X][$currentPosition.Y] = $null
                            }
                            "Fill" {
                                Add-Fill -OriginalColor $script:Image[$currentPosition.X][$currentPosition.Y] -CurrentPosition $currentPosition
                                $script:ForceRefresh = $true
                            }
                            "Fill Eraser" {
                                Remove-Fill -OriginalColor $script:Image[$currentPosition.X][$currentPosition.Y] -CurrentPosition $currentPosition
                                $script:ForceRefresh = $true
                            }
                            "Dropper" {
                                $originalColor = $script:Image[$currentPosition.X][$currentPosition.Y]
                                if($null -ne $originalColor) {
                                    $result = Find-Hsv -Rgb $originalColor
                                    if($result) {
                                        $script:CurrentHue = $result.H
                                        $script:CurrentSaturation = $result.S
                                        $script:CurrentValue = $result.V
                                    }
                                    $script:ForceRefresh = $true
                                }
                            }
                        }

                        Push-UndoState
                        $inputReceived = $true
                    }
                    "Close" {
                        $inputReceived = $true
                        return
                    }
                    "Redo" {
                        Pop-RedoState
                        $script:ForceRefresh = $true
                        $inputReceived = $true
                    }
                }
                if($previousPosition.X -ne $currentPosition.X -or $previousPosition.Y -ne $currentPosition.Y) {
                    if($script:CurrentTool -eq "Snake") {
                        $script:Image[$currentPosition.X][$currentPosition.Y] = (Convert-HsvToRgb -Hue $script:CurrentHue -Saturation $script:CurrentSaturation -Value $script:CurrentValue)
                        Push-UndoState
                    }
                    $inputReceived = $true
                }
            }
        }
    } finally {
        [Console]::CursorVisible = $true
    }
}
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

function Write-Toolbox {
    param (
        [object] $ToolboxTopLeft
    )

    if($ToolboxTopLeft.X -lt 56) {
        $ToolboxTopLeft.X = 56
    }

    $toolHeaders = @("(T)ools: ", "------------")
    for($h = 0; $h -lt $toolHeaders.Count; $h++) {
        [Console]::SetCursorPosition($ToolboxTopLeft.X, $ToolboxTopLeft.Y + $h)
        [Console]::Write($toolHeaders[$h])
    }

    for($t = 0; $t -lt $global:Tools.Count; $t++) {
        [Console]::SetCursorPosition($ToolboxTopLeft.X, $ToolboxTopLeft.Y + $toolHeaders.Count + $t)
        $line = $global:Tools[$t]
        if($line -like "*$($global:CurrentTool)") {
            $line = "[x] " + $line
        } else {
            $line = "[ ] " + $line
        }
        Write-Host -NoNewline -ForegroundColor DarkGray $line
    }

    $modeHeaders = @("", "(M)odes: ", "------------")
    for($h = 0; $h -lt $modeHeaders.Count; $h++) {
        [Console]::SetCursorPosition($ToolboxTopLeft.X, $ToolboxTopLeft.Y + $toolHeaders.Count + $global:Tools.Count + $h)
        [Console]::Write($modeHeaders[$h])
    }

    for($t = 0; $t -lt $global:Modes.Count; $t++) {
        [Console]::SetCursorPosition($ToolboxTopLeft.X, $ToolboxTopLeft.Y + $toolHeaders.Count + $modeHeaders.Count + $global:Tools.Count + $t)
        $line = $global:Modes[$t]
        if($line -like "*$($global:CurrentMode)") {
            $line = "[x] " + $line
        } else {
            $line = "[ ] " + $line
        }
        Write-Host -NoNewline -ForegroundColor DarkGray $line
    }

    $commmandHeaders = @("", "Commands:", "------------")
    for($c = 0; $c -lt $commmandHeaders.Count; $c++) {
        [Console]::SetCursorPosition($ToolboxTopLeft.X, $ToolboxTopLeft.Y + $toolHeaders.Count + $modeHeaders.Count + $global:Tools.Count + $global:Modes.Count + $c)
        [Console]::Write($commmandHeaders[$c])
    }
    $commands = @("(ctrl+N)ew", "(ctrl+O)pen", "(ctrl+S)ave", "(ctrl+C)lose")
    for($c = 0; $c -lt $commands.Count; $c++) {
        [Console]::SetCursorPosition($ToolboxTopLeft.X, $ToolboxTopLeft.Y + $toolHeaders.Count + $modeHeaders.Count + $global:Tools.Count + $global:Modes.Count + $commmandHeaders.Count + $c)
        Write-Host -NoNewline -ForegroundColor DarkGray $commands[$c]
    }
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
            if($relativeX -ge 0 -and $relativeX -lt $ImageWidth -and $relativeY -ge 0 -and $relativeY -lt $ImageHeight) {
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
        [object] $PreviousPosition,
        [int] $ImageHeight,
        [int] $ImageWidth
    )
    $cursorColor = Convert-HsvToRgb -Hue $global:CurrentHue -Saturation $global:CurrentSaturation -Value $global:CurrentValue
    if($global:CurrentTool -eq "Eraser") {
        $cursorColor = @(255, 255, 255)
    }

    Write-Toolbox -ToolboxTopLeft @{
        X = ($CanvasTopLeft.X + $ImageWidth) * 2 + 1
        Y = $CanvasTopLeft.Y
    }

    if(!$global:ForceRefresh -and ($PreviousPosition.X -ne $currentPosition.X -or $PreviousPosition.Y -ne $currentPosition.Y)) {
        # Just render the changes
        for($x = -1; $x -lt 2; $x++) {
            $relativeX = $PreviousPosition.X + $x
            for($y = -1; $y -lt 2; $y++) {
                $relativeY = $PreviousPosition.Y + $y
                if($relativeX -ge 0 -and $relativeX -lt $ImageWidth -and $relativeY -ge 0 -and $relativeY -lt $ImageHeight) {
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
        for($y = 0; $y -lt $ImageHeight; $y++) {
            for($x = 0; $x -lt $ImageWidth; $x++) {
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
    [Console]::SetCursorPosition($CanvasTopLeft.X, $CanvasTopLeft.Y + $ImageHeight)
    Write-ColorControls
}

function Out-Gif {
    param (
        [string] $Path,
        [int] $ImageWidth,
        [int] $ImageHeight
    )
    $attempts = 0
    while($attempts -lt 2) {
        $attempts++
        try {
            $bitmap = [System.Drawing.Bitmap]::new($ImageWidth, $ImageHeight, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
            $palette = @()
            for($y = 0; $y -lt $ImageHeight; $y++) {
                for($x = 0; $x -lt $ImageWidth; $x++) {
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
            Write-Warning "Failed to save image on the first attempt, trying to load System.Drawing assemblies"
            [System.Reflection.Assembly]::LoadWithPartialName("System.Drawing") | Out-Null
        }
    }
}

function Open-JsonSprite {
    param (
        [string] $Path
    )
    # Json saving on powershell 5 saves arrays with simple types as complex objects instead of vanilla json arrays
    $obj = Get-Content $Path | ConvertFrom-Json

    $global:Image = @($null) * $obj.Count
    for($i = 0; $i -lt $global:Image.Count; $i++){
        if($obj[$i].value) {
            $global:Image[$i] = $obj[$i].value
        } else {
            $global:Image[$i] = $obj[$i]
        }
    }
}

function Test-CanvasFitsInTerminal {
    param (
        [int] $ImageWidth,
        [int] $ImageHeight
    )
    return ($ImageWidth -lt ($Host.UI.RawUI.WindowSize.Width / 2 - 15) -and $ImageHeight -lt ($Host.UI.RawUI.WindowSize.Height - 7))
}
$prefix = "http://localhost:8383/"
$contentRoot = $PSScriptRoot
try {
    $job = Start-Job -ArgumentList @($prefix, $contentRoot) -ScriptBlock {
        param (
            [string] $prefix,
            [string] $contentRoot
        )

        $http = [System.Net.HttpListener]::new()
        $http.Prefixes.Add($prefix)
        $http.Start()

        $spriteTemplate = @"
    <div class="sprite">
        <h2>__SPRITE_FILENAME__</h2>
        <div class="sprite-content">
        <img src="sprites/__SPRITE_FILENAME__" alt="__SPRITE_FILENAME__" />
        </div>
    </div>

"@

        try {
            while ($http.IsListening) {
                $contextTask = $http.GetContextAsync()
                while (-not $contextTask.AsyncWaitHandle.WaitOne(200)) { }
                $context = $contextTask.GetAwaiter().GetResult()
                
                Write-Host "Starting request $($context.Request.HttpMethod) $($context.Request.RawUrl)"
                
                if ($context.Request.HttpMethod -eq 'GET' -and $context.Request.RawUrl -eq '/') {
                    $sprites = Get-ChildItem "$contentRoot/sprites/*.png"
                    $template = Get-Content -Raw "$contentRoot/sprites/index.html"
                    if(!$sprites) {
                        Write-Warning "No sprites found matching path '$contentRoot/sprites/*.png'"
                    }
                    $spriteContent = ""
                    foreach($sprite in $sprites) {
                        $spriteContent += $spriteTemplate -replace "__SPRITE_FILENAME__", $sprite.Name
                    }
                    $template = $template -replace "__SPRITE_CONTENT__", $spriteContent
                    $buffer = [System.Text.Encoding]::UTF8.GetBytes($template)
                    $context.Response.ContentLength64 = $buffer.Length
                    $context.Response.OutputStream.Write($buffer, 0, $buffer.Length)
                    $context.Response.OutputStream.Close()
                    Write-Host "Rendered index.html"
                    continue
                }

                if ($context.Request.HttpMethod -eq 'GET' -and $context.Request.RawUrl -match '/sprites/[^.]+\.png') {
                    $image = [System.IO.File]::ReadAllBytes("$contentRoot$($context.Request.RawUrl)")
                    $context.Response.ContentType = "image/png"
                    $context.Response.ContentLength64 = $image.Length
                    $context.Response.OutputStream.Write($image, 0, $image.Length)
                    $context.Response.OutputStream.Close()
                    Write-Host "Rendered $($context.Request.RawUrl)"
                    continue
                }

                $notFound = "Not Found"
                $buffer = [System.Text.Encoding]::UTF8.GetBytes($notFound)
                $context.Response.StatusCode = "404"
                $context.Response.ContentLength64 = $buffer.Length
                $context.Response.OutputStream.Write($buffer, 0, $buffer.Length)
                $context.Response.OutputStream.Close()
                Write-Host "Not found: $($context.Request.RawUrl)"
            }
        }
        finally {
            $http.Stop()
        }
    }
    Write-Host -ForegroundColor Green "Web server is running at $prefix"
    Start-Process $prefix
    while($job.State -eq "Running") {
        Start-Sleep -Seconds 1
    }
} finally {
    Write-Host "Job log:"
    $job | Receive-Job
    $job | Stop-Job
    $job | Remove-Job
}
$prefix = "http://localhost:8383/"

$http = [System.Net.HttpListener]::new() 
$http.Prefixes.Add($prefix)
$http.Start()

# Open browser
Start-Process $prefix

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
        # Credit: https://www.reddit.com/r/PowerShell/comments/9n2q03/comment/e7ju5w4/?utm_source=share&utm_medium=web2x&context=3
        while (-not $contextTask.AsyncWaitHandle.WaitOne(200)) { }
        $context = $contextTask.GetAwaiter().GetResult()
        
        if ($context.Request.HttpMethod -eq 'GET' -and $context.Request.RawUrl -eq '/') {
            $sprites = Get-ChildItem "./sprites/*.png"
            $template = Get-Content -Raw "$PSScriptRoot/sprites/index.html"
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
            $image = [System.IO.File]::ReadAllBytes("$PSScriptRoot$($context.Request.RawUrl)")
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
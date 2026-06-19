@echo off
setlocal enabledelayedexpansion

:: 1. Clear conflicting keys
set ANTHROPIC_API_KEY=

:: 2. Put your Cerebras key here
set CEREBRAS_KEY=csk-fnpfh6r2ehwfpw3rnhmnywjhnfde2hnw5cjt92k65yfevnnh

:: 3. Spin up a lightweight local string-replacer using PowerShell in the background
echo 🛰️ Routing traffic...
powershell -NoProfile -Command ^
    "$listener = [System.Net.HttpListener]::new(); $listener.Prefixes.Add('http://localhost:8080/'); $listener.Start(); ^
    while ($listener.IsListening) { ^
        $context = $listener.GetContext(); $req = $context.Request; $res = $context.Response; ^
        if ($req.HttpMethod -eq 'POST') { ^
            $reader = [System.IO.StreamReader]::new($req.InputStream); $body = $reader.ReadToEnd(); ^
            $body = $body -replace 'claude-3-5-sonnet-20241022', 'zai-glm-4.7'; ^
            $body = $body -replace 'claude-3-5-haiku-20241022', 'zai-glm-4.7'; ^
            $bytes = [System.Text.Encoding]::UTF8.GetBytes($body); ^
            $client = [System.Net.Http.HttpClient]::new(); ^
            $client.DefaultRequestHeaders.Add('Authorization', 'Bearer %CEREBRAS_KEY%'); ^
            $content = [System.Net.Http.ByteArrayContent]::new($bytes); ^
            $content.Headers.ContentType = [System.Net.Http.Headers.MediaTypeHeaderValue]::Parse('application/json'); ^
            $response = $client.PostAsync('https://api.cerebras.ai/v1/chat/completions', $content).Result; ^
            $resBytes = $response.Content.ReadAsByteArrayAsync().Result; ^
            $res.StatusCode = [int]$response.StatusCode; ^
            $res.OutputStream.Write($resBytes, 0, $resBytes.Length); ^
        } else { $res.StatusCode = 405; } ^
        $res.Close(); ^
    }" >nul 2>&1 &

:: 4. Give the background worker a quick second to bind to port 8080
timeout /t 2 /nobreak >nul

:: 5. Point Claude Code to our local proxy loop
set ANTHROPIC_BASE_URL=http://localhost:8080

:: 6. Use legitimate Anthropic model names so Claude Code's interface doesn't error out
set ANTHROPIC_AUTH_TOKEN=%CEREBRAS_KEY%
set ANTHROPIC_DEFAULT_HAIKU_MODEL=claude-3-5-sonnet-20241022
set ANTHROPIC_DEFAULT_SONNET_MODEL=claude-3-5-sonnet-20241022
set ANTHROPIC_DEFAULT_OPUS_MODEL=claude-3-5-sonnet-20241022

echo ⚡ Ripping Claude Code with Cerebras GLM-4.7...
claude --dangerously-skip-permissions %*

:: Kill the background router when you exit Claude Code
taskkill /f /fi "IMAGENAME eq powershell.exe" >nul 2>&1
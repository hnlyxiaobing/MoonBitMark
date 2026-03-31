$ErrorActionPreference = 'Stop'

. "$PSScriptRoot\..\TestHelpers.ps1"

$repoRoot = Get-MoonBitMarkRepoRoot -ScriptPath $PSScriptRoot
$binary = Join-Path $repoRoot '_build\native\release\build\cmd\mcp-http-server\mcp-http-server.exe'
Ensure-MoonBitMarkReleaseBinary -RepoRoot $repoRoot -BinaryPath $binary

$tempRoot = Join-Path $repoRoot '_build\test-tmp\mcp-http-security'
New-Item -ItemType Directory -Force -Path $tempRoot | Out-Null
$allowedRoot = Join-Path $tempRoot 'allowed'
New-Item -ItemType Directory -Force -Path $allowedRoot | Out-Null
$textInput = Join-Path $allowedRoot 'security.txt'
1..200 | ForEach-Object {
    "mcp http security line $_"
} | Set-Content -Path $textInput -Encoding utf8
$uploadedText = (1..40 | ForEach-Object { "uploaded http security line $_" }) -join "`n"
$uploadedBase64 = [Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($uploadedText))

function Convert-SummaryTextToMap {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Text
    )

    $result = @{}
    foreach ($line in ($Text -split "`n")) {
        $trimmed = $line.Trim()
        if ($trimmed -eq '') {
            continue
        }
        $parts = $trimmed -split ': ', 2
        if ($parts.Count -ne 2) {
            throw "Invalid summary line: $trimmed"
        }
        $result[$parts[0]] = $parts[1]
    }
    return $result
}

function Start-McpHttpServer {
    param(
        [hashtable]$Environment = @{},
        [string[]]$Arguments = @()
    )

    $port = Get-FreeTcpPort
    $process = Start-NativeProcess -FilePath $binary -Arguments (@('--port', "$port") + $Arguments) -WorkingDirectory $repoRoot -Environment $Environment
    $baseUrl = "http://127.0.0.1:$port"

    try {
        Wait-HttpHealthz -Url "$baseUrl/healthz" -Process $process | Out-Null
    } catch {
        $output = Stop-NativeProcess -Process $process
        throw "HTTP MCP server failed to start.`nSTDOUT:`n$($output.StdOut)`nSTDERR:`n$($output.StdErr)"
    }

    return [pscustomobject]@{
        Port    = $port
        BaseUrl = $baseUrl
        McpUrl  = "$baseUrl/mcp"
        Process = $process
    }
}

function Stop-McpHttpServer {
    param(
        [Parameter(Mandatory = $true)]
        $Server
    )

    $output = Stop-NativeProcess -Process $Server.Process
    if ($output.StdOut.Trim() -ne '') {
        throw "HTTP MCP server wrote unexpected stdout:`n$($output.StdOut)"
    }
    if ($output.StdErr.Trim() -ne '') {
        throw "HTTP MCP server wrote unexpected stderr:`n$($output.StdErr)"
    }
}

function Invoke-McpHttpRequest {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Url,

        [Parameter(Mandatory = $true)]
        [string]$RequestJson
    )

    $response = Invoke-HttpRequest -Method 'POST' -Url $Url -Body $RequestJson -ContentType 'application/json; charset=utf-8'
    return [pscustomobject]@{
        StatusCode = $response.StatusCode
        Body = ($response.Body | ConvertFrom-Json)
    }
}

$rejectPort = Get-FreeTcpPort
$rejectProcess = Start-NativeProcess -FilePath $binary -Arguments @('--host', '0.0.0.0', '--port', "$rejectPort") -WorkingDirectory $repoRoot
Start-Sleep -Milliseconds 800
$rejectOutput = Stop-NativeProcess -Process $rejectProcess
$rejectCombined = ($rejectOutput.StdOut + "`n" + $rejectOutput.StdErr).Trim()
if ($rejectCombined -notmatch 'MOONBITMARK_MCP_HTTP_ALLOW_NONLOCAL') {
    throw "Expected nonlocal bind rejection to mention MOONBITMARK_MCP_HTTP_ALLOW_NONLOCAL.`nActual:`n$rejectCombined"
}

$nonlocalServer = Start-McpHttpServer -Environment @{ MOONBITMARK_MCP_HTTP_ALLOW_NONLOCAL = '1' } -Arguments @('--host', '0.0.0.0')
try {
    $healthResponse = Invoke-HttpRequest -Method 'GET' -Url "$($nonlocalServer.BaseUrl)/healthz" -ContentType 'application/json; charset=utf-8'
    if ($healthResponse.StatusCode -ne 200) {
        throw "Expected 0.0.0.0 bind with env to be reachable, got $($healthResponse.StatusCode)"
    }
} finally {
    Stop-McpHttpServer -Server $nonlocalServer
}

$defaultSecurityServer = Start-McpHttpServer
try {
    $inspectHttpRequest = @{
        jsonrpc = '2.0'
        method = 'tools/call'
        params = @{
            name = 'inspect_document'
            arguments = @{
                uri = 'https://example.com/demo.html'
            }
        }
        id = 1
    } | ConvertTo-Json -Compress -Depth 5
    $inspectHttpResponse = Invoke-McpHttpRequest -Url $defaultSecurityServer.McpUrl -RequestJson $inspectHttpRequest
    if ($inspectHttpResponse.Body.result.isError -ne $true) {
        throw 'HTTP URL inspection should fail when MOONBITMARK_MCP_ALLOW_HTTP is unset.'
    }
    Assert-ContainsText -Text $inspectHttpResponse.Body.result.content[0].text -Expected 'MOONBITMARK_MCP_ALLOW_HTTP' -Context 'HTTP URL boundary'
} finally {
    Stop-McpHttpServer -Server $defaultSecurityServer
}

$boundaryServer = Start-McpHttpServer -Environment @{
    MOONBITMARK_MCP_ALLOWED_ROOTS = (Normalize-MoonBitMarkPath $allowedRoot)
    MOONBITMARK_MCP_ENABLE_OCR = '1'
}
try {
    $outsideRootRequest = @{
        jsonrpc = '2.0'
        method = 'tools/call'
        params = @{
            name = 'inspect_document'
            arguments = @{
                uri = (Normalize-MoonBitMarkPath (Join-Path $repoRoot 'README.md'))
            }
        }
        id = 2
    } | ConvertTo-Json -Compress -Depth 5
    $outsideRootResponse = Invoke-McpHttpRequest -Url $boundaryServer.McpUrl -RequestJson $outsideRootRequest
    if ($outsideRootResponse.Body.result.isError -ne $true) {
        throw 'inspect_document should fail outside MOONBITMARK_MCP_ALLOWED_ROOTS over HTTP.'
    }
    Assert-ContainsText -Text $outsideRootResponse.Body.result.content[0].text -Expected 'MOONBITMARK_MCP_ALLOWED_ROOTS' -Context 'HTTP allowed roots boundary'

    $insideRootRequest = @{
        jsonrpc = '2.0'
        method = 'tools/call'
        params = @{
            name = 'inspect_document'
            arguments = @{
                uri = (Normalize-MoonBitMarkPath $textInput)
            }
        }
        id = 3
    } | ConvertTo-Json -Compress -Depth 5
    $insideRootResponse = Invoke-McpHttpRequest -Url $boundaryServer.McpUrl -RequestJson $insideRootRequest
    if ($insideRootResponse.Body.result.isError -ne $false) {
        throw 'inspect_document should succeed inside MOONBITMARK_MCP_ALLOWED_ROOTS over HTTP.'
    }
    $inspectSummary = Convert-SummaryTextToMap -Text $insideRootResponse.Body.result.content[0].text
    if ($inspectSummary['ocr_enabled_by_env'] -ne 'true') {
        throw 'inspect_document did not surface MOONBITMARK_MCP_ENABLE_OCR over HTTP.'
    }
} finally {
    Stop-McpHttpServer -Server $boundaryServer
}

$clampServer = Start-McpHttpServer -Environment @{
    MOONBITMARK_MCP_ALLOWED_ROOTS = (Normalize-MoonBitMarkPath $allowedRoot)
    MOONBITMARK_MCP_MAX_OUTPUT_CHARS = '80'
}
try {
    $convertRequest = @{
        jsonrpc = '2.0'
        method = 'tools/call'
        params = @{
            name = 'convert_to_markdown'
            arguments = @{
                uri = (Normalize-MoonBitMarkPath $textInput)
                mode = 'full'
            }
        }
        id = 4
    } | ConvertTo-Json -Compress -Depth 5
    $convertResponse = Invoke-McpHttpRequest -Url $clampServer.McpUrl -RequestJson $convertRequest
    if ($convertResponse.Body.result.isError -ne $false) {
        throw 'convert_to_markdown should succeed inside the allowed root over HTTP.'
    }
    $convertSummary = Convert-SummaryTextToMap -Text $convertResponse.Body.result.content[0].text
    if ($convertSummary['effective_max_chars'] -ne '80') {
        throw "effective_max_chars should be clamped to 80 over HTTP, got $($convertSummary['effective_max_chars'])"
    }
    if ($convertSummary['returned_chars'] -ne '80') {
        throw "returned_chars should be clamped to 80 over HTTP, got $($convertSummary['returned_chars'])"
    }

    $uploadRequest = @{
        jsonrpc = '2.0'
        method = 'tools/call'
        params = @{
            name = 'convert_uploaded_document'
            arguments = @{
                filename = 'uploaded-http-security.txt'
                data_base64 = $uploadedBase64
                mode = 'full'
            }
        }
        id = 5
    } | ConvertTo-Json -Compress -Depth 6
    $uploadResponse = Invoke-McpHttpRequest -Url $clampServer.McpUrl -RequestJson $uploadRequest
    if ($uploadResponse.Body.result.isError -ne $false) {
        throw 'convert_uploaded_document should succeed under MOONBITMARK_MCP_MAX_OUTPUT_CHARS over HTTP.'
    }
    $uploadSummary = Convert-SummaryTextToMap -Text $uploadResponse.Body.result.content[0].text
    if ($uploadSummary['effective_max_chars'] -ne '80') {
        throw "uploaded effective_max_chars should be clamped to 80 over HTTP, got $($uploadSummary['effective_max_chars'])"
    }
    if ($uploadSummary['returned_chars'] -ne '80') {
        throw "uploaded returned_chars should be clamped to 80 over HTTP, got $($uploadSummary['returned_chars'])"
    }
} finally {
    Stop-McpHttpServer -Server $clampServer
}

$uploadLimitServer = Start-McpHttpServer -Environment @{
    MOONBITMARK_MCP_MAX_UPLOAD_BYTES = '8'
}
try {
    $uploadLimitRequest = @{
        jsonrpc = '2.0'
        method = 'tools/call'
        params = @{
            name = 'upload_document'
            arguments = @{
                filename = 'too-large-http.txt'
                data_base64 = $uploadedBase64
            }
        }
        id = 6
    } | ConvertTo-Json -Compress -Depth 6
    $uploadLimitResponse = Invoke-McpHttpRequest -Url $uploadLimitServer.McpUrl -RequestJson $uploadLimitRequest
    if ($uploadLimitResponse.Body.result.isError -ne $true) {
        throw 'upload_document should reject payloads over MOONBITMARK_MCP_MAX_UPLOAD_BYTES over HTTP.'
    }
    Assert-ContainsText -Text $uploadLimitResponse.Body.result.content[0].text -Expected 'MOONBITMARK_MCP_MAX_UPLOAD_BYTES' -Context 'HTTP upload size boundary'
} finally {
    Stop-McpHttpServer -Server $uploadLimitServer
}

Write-Host 'MCP HTTP security smoke checks passed, including nonlocal bind rejection, explicit 0.0.0.0 opt-in, and MCP runtime boundary env enforcement over HTTP.'

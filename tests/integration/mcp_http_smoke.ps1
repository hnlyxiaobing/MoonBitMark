$ErrorActionPreference = 'Stop'

. "$PSScriptRoot\..\TestHelpers.ps1"

$repoRoot = Get-MoonBitMarkRepoRoot -ScriptPath $PSScriptRoot
$binary = Join-Path $repoRoot '_build\native\release\build\cmd\mcp-http-server\mcp-http-server.exe'
Ensure-MoonBitMarkReleaseBinary -RepoRoot $repoRoot -BinaryPath $binary

$tempRoot = Join-Path $repoRoot '_build\test-tmp\mcp-http'
New-Item -ItemType Directory -Force -Path $tempRoot | Out-Null
$textInput = Join-Path $tempRoot 'smoke.txt'
1..400 | ForEach-Object {
    "mcp http smoke line $_"
} | Set-Content -Path $textInput -Encoding utf8
$uploadedText = "uploaded http line 1`nuploaded http line 2"
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

function Invoke-McpHttpRawRequest {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Url,

        [Parameter(Mandatory = $true)]
        [string]$RequestJson
    )

    return Invoke-HttpRequest -Method 'POST' -Url $Url -Body $RequestJson -ContentType 'application/json; charset=utf-8'
}

function Invoke-McpHttpRequest {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Url,

        [Parameter(Mandatory = $true)]
        [string]$RequestJson
    )

    $response = Invoke-McpHttpRawRequest -Url $Url -RequestJson $RequestJson
    if ($response.Body.Trim() -eq '') {
        return [pscustomobject]@{
            StatusCode = $response.StatusCode
            Body = $null
        }
    }

    return [pscustomobject]@{
        StatusCode = $response.StatusCode
        Body = ($response.Body | ConvertFrom-Json)
    }
}

$port = Get-FreeTcpPort
$process = Start-NativeProcess -FilePath $binary -Arguments @('--port', "$port") -WorkingDirectory $repoRoot
$mcpUrl = "http://127.0.0.1:$port/mcp"
$healthUrl = "http://127.0.0.1:$port/healthz"

try {
    $healthResponse = Wait-HttpHealthz -Url $healthUrl -Process $process
    if ($healthResponse.StatusCode -ne 200) {
        throw "Unexpected healthz status: $($healthResponse.StatusCode)"
    }
    $healthBody = $healthResponse.Body | ConvertFrom-Json
    if ($healthBody.status -ne 'ok') {
        throw "Unexpected healthz payload: $($healthResponse.Body)"
    }

    $notificationRequest = @{
        jsonrpc = '2.0'
        method = 'notifications/initialized'
        params = @{}
    } | ConvertTo-Json -Compress
    $notificationResponse = Invoke-McpHttpRawRequest -Url $mcpUrl -RequestJson $notificationRequest
    if ($notificationResponse.StatusCode -ne 204) {
        throw "Notification should return 204, got $($notificationResponse.StatusCode)"
    }
    if ($notificationResponse.Body.Trim() -ne '') {
        throw 'Notification response should not include a body.'
    }

    $invalidResponse = Invoke-McpHttpRawRequest -Url $mcpUrl -RequestJson '{invalid-json'
    if ($invalidResponse.StatusCode -ne 400) {
        throw "Invalid JSON should return 400, got $($invalidResponse.StatusCode)"
    }
    $invalidBody = $invalidResponse.Body | ConvertFrom-Json
    if ($invalidBody.error.code -ne -32700) {
        throw "Invalid JSON should return -32700, got $($invalidBody.error.code)"
    }

    $initializeRequest = @{
        jsonrpc = '2.0'
        method = 'initialize'
        params = @{
            protocolVersion = '2024-11-05'
            capabilities = @{}
            clientInfo = @{
                name = 'http-smoke-client'
                version = '1.0.0'
            }
        }
        id = 1
    } | ConvertTo-Json -Compress -Depth 5
    $initializeResponse = Invoke-McpHttpRequest -Url $mcpUrl -RequestJson $initializeRequest
    if ($initializeResponse.StatusCode -ne 200) {
        throw "initialize should return 200, got $($initializeResponse.StatusCode)"
    }
    if ($initializeResponse.Body.result.serverInfo.name -ne 'moonbitmark') {
        throw "Unexpected server name: $($initializeResponse.Body.result.serverInfo.name)"
    }

    $toolsListRequest = @{
        jsonrpc = '2.0'
        method = 'tools/list'
        id = 2
    } | ConvertTo-Json -Compress
    $toolsListResponse = Invoke-McpHttpRequest -Url $mcpUrl -RequestJson $toolsListRequest
    $toolNames = @($toolsListResponse.Body.result.tools | ForEach-Object { $_.name })
    if (@($toolNames | Where-Object { $_ -eq 'inspect_document' }).Count -ne 1) {
        throw 'tools/list did not expose inspect_document over HTTP.'
    }
    if (@($toolNames | Where-Object { $_ -eq 'convert_to_markdown' }).Count -ne 1) {
        throw 'tools/list did not expose convert_to_markdown over HTTP.'
    }
    $storeTool = $toolsListResponse.Body.result.tools | Where-Object { $_.name -eq 'upload_document' } | Select-Object -First 1
    if ($null -eq $storeTool) {
        throw 'tools/list did not expose upload_document over HTTP.'
    }
    $uploadTool = $toolsListResponse.Body.result.tools | Where-Object { $_.name -eq 'convert_uploaded_document' } | Select-Object -First 1
    if ($null -eq $uploadTool) {
        throw 'tools/list did not expose convert_uploaded_document over HTTP.'
    }
    $convertTool = $toolsListResponse.Body.result.tools | Where-Object { $_.name -eq 'convert_to_markdown' } | Select-Object -First 1
    if ($null -eq $convertTool.inputSchema.properties.response_mode) {
        throw 'convert_to_markdown schema did not expose response_mode over HTTP.'
    }
    if ($null -eq $convertTool.inputSchema.properties.resource_uri) {
        throw 'convert_to_markdown schema did not expose resource_uri over HTTP.'
    }
    if ($null -eq $storeTool.inputSchema.properties.filename) {
        throw 'upload_document schema did not expose filename over HTTP.'
    }
    if ($null -eq $storeTool.inputSchema.properties.data_base64) {
        throw 'upload_document schema did not expose data_base64 over HTTP.'
    }
    if ($null -eq $uploadTool.inputSchema.properties.filename) {
        throw 'convert_uploaded_document schema did not expose filename over HTTP.'
    }
    if ($null -eq $uploadTool.inputSchema.properties.data_base64) {
        throw 'convert_uploaded_document schema did not expose data_base64 over HTTP.'
    }
    if ($null -eq $uploadTool.inputSchema.properties.data_bytes) {
        throw 'convert_uploaded_document schema did not expose data_bytes over HTTP.'
    }

    $inspectRequest = @{
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
    $inspectResponse = Invoke-McpHttpRequest -Url $mcpUrl -RequestJson $inspectRequest
    if ($inspectResponse.Body.result.isError -ne $false) {
        throw 'inspect_document unexpectedly failed over HTTP.'
    }
    $inspectSummary = Convert-SummaryTextToMap -Text $inspectResponse.Body.result.content[0].text
    if ($inspectSummary['detected_format'] -ne 'text') {
        throw "inspect_document detected unexpected format: $($inspectSummary['detected_format'])"
    }

    $inspectJsonRequest = @{
        jsonrpc = '2.0'
        method = 'tools/call'
        params = @{
            name = 'inspect_document'
            arguments = @{
                uri = (Normalize-MoonBitMarkPath $textInput)
                response_mode = 'json'
            }
        }
        id = 31
    } | ConvertTo-Json -Compress -Depth 5
    $inspectJsonResponse = Invoke-McpHttpRequest -Url $mcpUrl -RequestJson $inspectJsonRequest
    if ($inspectJsonResponse.Body.result.structuredContent.metadata.detected_format -ne 'text') {
        throw "inspect_document json mode returned unexpected detected_format over HTTP: $($inspectJsonResponse.Body.result.structuredContent.metadata.detected_format)"
    }
    if ($null -eq $inspectJsonResponse.Body.result.structuredContent.stats.file_size_bytes) {
        throw 'inspect_document json mode did not return stats.file_size_bytes over HTTP.'
    }

    $convertRequest = @{
        jsonrpc = '2.0'
        method = 'tools/call'
        params = @{
            name = 'convert_to_markdown'
            arguments = @{
                uri = (Normalize-MoonBitMarkPath $textInput)
            }
        }
        id = 4
    } | ConvertTo-Json -Compress -Depth 5
    $convertResponse = Invoke-McpHttpRequest -Url $mcpUrl -RequestJson $convertRequest
    if ($convertResponse.Body.result.isError -ne $false) {
        throw 'convert_to_markdown unexpectedly failed over HTTP.'
    }
    $convertSummary = Convert-SummaryTextToMap -Text $convertResponse.Body.result.content[0].text
    if ($convertSummary['mode'] -ne 'preview') {
        throw "convert_to_markdown returned unexpected mode: $($convertSummary['mode'])"
    }
    Assert-ContainsText -Text $convertResponse.Body.result.content[1].text -Expected 'mcp http smoke line 1' -Context 'HTTP preview markdown'

    $convertJsonRequest = @{
        jsonrpc = '2.0'
        method = 'tools/call'
        params = @{
            name = 'convert_to_markdown'
            arguments = @{
                uri = (Normalize-MoonBitMarkPath $textInput)
                response_mode = 'json'
            }
        }
        id = 41
    } | ConvertTo-Json -Compress -Depth 5
    $convertJsonResponse = Invoke-McpHttpRequest -Url $mcpUrl -RequestJson $convertJsonRequest
    if ($convertJsonResponse.Body.result.structuredContent.metadata.mode -ne 'preview') {
        throw "convert_to_markdown json mode returned unexpected mode over HTTP: $($convertJsonResponse.Body.result.structuredContent.metadata.mode)"
    }
    if ($convertJsonResponse.Body.result.structuredContent.stats.returned_chars -le 0) {
        throw 'convert_to_markdown json mode returned invalid stats.returned_chars over HTTP.'
    }
    Assert-ContainsText -Text $convertJsonResponse.Body.result.structuredContent.content -Expected 'mcp http smoke line 1' -Context 'HTTP preview json content'

    $storeRequest = @{
        jsonrpc = '2.0'
        method = 'tools/call'
        params = @{
            name = 'upload_document'
            arguments = @{
                filename = 'stored-http.txt'
                data_base64 = $uploadedBase64
                response_mode = 'json'
            }
        }
        id = 411
    } | ConvertTo-Json -Compress -Depth 6
    $storeResponse = Invoke-McpHttpRequest -Url $mcpUrl -RequestJson $storeRequest
    if ($storeResponse.Body.result.isError -ne $false) {
        throw 'upload_document unexpectedly failed over HTTP.'
    }
    $resourceUri = $storeResponse.Body.result.structuredContent.metadata.resource_uri
    if ([string]::IsNullOrWhiteSpace($resourceUri)) {
        throw 'upload_document did not return resource_uri over HTTP.'
    }

    $resourceReadRequest = @{
        jsonrpc = '2.0'
        method = 'resources/read'
        params = @{
            uri = $resourceUri
        }
        id = 412
    } | ConvertTo-Json -Compress -Depth 5
    $resourceReadResponse = Invoke-McpHttpRequest -Url $mcpUrl -RequestJson $resourceReadRequest
    Assert-ContainsText -Text $resourceReadResponse.Body.result.contents[0].text -Expected 'source_filename: stored-http.txt' -Context 'HTTP stored resource metadata'

    $resourceInspectRequest = @{
        jsonrpc = '2.0'
        method = 'tools/call'
        params = @{
            name = 'inspect_document'
            arguments = @{
                resource_uri = $resourceUri
            }
        }
        id = 413
    } | ConvertTo-Json -Compress -Depth 5
    $resourceInspectResponse = Invoke-McpHttpRequest -Url $mcpUrl -RequestJson $resourceInspectRequest
    if ($resourceInspectResponse.Body.result.isError -ne $false) {
        throw 'inspect_document should accept resource_uri over HTTP.'
    }
    if ((Convert-SummaryTextToMap -Text $resourceInspectResponse.Body.result.content[0].text)['input_kind'] -ne 'resource') {
        throw 'inspect_document did not report input_kind=resource over HTTP.'
    }

    $resourceConvertRequest = @{
        jsonrpc = '2.0'
        method = 'tools/call'
        params = @{
            name = 'convert_to_markdown'
            arguments = @{
                resource_uri = $resourceUri
                mode = 'full'
            }
        }
        id = 414
    } | ConvertTo-Json -Compress -Depth 5
    $resourceConvertResponse = Invoke-McpHttpRequest -Url $mcpUrl -RequestJson $resourceConvertRequest
    if ($resourceConvertResponse.Body.result.isError -ne $false) {
        throw 'convert_to_markdown should accept resource_uri over HTTP.'
    }
    Assert-ContainsText -Text $resourceConvertResponse.Body.result.content[1].text -Expected 'uploaded http line 1' -Context 'HTTP resource markdown'

    $uploadRequest = @{
        jsonrpc = '2.0'
        method = 'tools/call'
        params = @{
            name = 'convert_uploaded_document'
            arguments = @{
                filename = 'uploaded-http.txt'
                data_base64 = $uploadedBase64
                mime_type = 'text/plain'
                mode = 'full'
                response_mode = 'json'
            }
        }
        id = 42
    } | ConvertTo-Json -Compress -Depth 6
    $uploadResponse = Invoke-McpHttpRequest -Url $mcpUrl -RequestJson $uploadRequest
    if ($uploadResponse.Body.result.isError -ne $false) {
        throw 'convert_uploaded_document unexpectedly failed over HTTP.'
    }
    if ($uploadResponse.Body.result.structuredContent.metadata.tool -ne 'convert_uploaded_document') {
        throw "convert_uploaded_document returned unexpected tool metadata over HTTP: $($uploadResponse.Body.result.structuredContent.metadata.tool)"
    }
    if ($uploadResponse.Body.result.structuredContent.metadata.source_filename -ne 'uploaded-http.txt') {
        throw "convert_uploaded_document returned unexpected source filename over HTTP: $($uploadResponse.Body.result.structuredContent.metadata.source_filename)"
    }
    if ($uploadResponse.Body.result.structuredContent.metadata.upload_encoding -ne 'base64') {
        throw "convert_uploaded_document returned unexpected upload encoding over HTTP: $($uploadResponse.Body.result.structuredContent.metadata.upload_encoding)"
    }
    if ($uploadResponse.Body.result.structuredContent.stats.uploaded_bytes -le 0) {
        throw 'convert_uploaded_document did not return stats.uploaded_bytes over HTTP.'
    }
    Assert-ContainsText -Text $uploadResponse.Body.result.structuredContent.content -Expected 'uploaded http line 1' -Context 'HTTP uploaded markdown'

    $resourcesListRequest = @{
        jsonrpc = '2.0'
        method = 'resources/list'
        id = 5
    } | ConvertTo-Json -Compress
    $resourcesListResponse = Invoke-McpHttpRequest -Url $mcpUrl -RequestJson $resourcesListRequest
    $resourceUris = @($resourcesListResponse.Body.result.resources | ForEach-Object { $_.uri })
    foreach ($expectedUri in @('moonbitmark://capabilities', 'moonbitmark://mcp-usage')) {
        if (@($resourceUris | Where-Object { $_ -eq $expectedUri }).Count -ne 1) {
            throw "resources/list did not expose expected URI over HTTP: $expectedUri"
        }
    }

    $resourcesReadRequest = @{
        jsonrpc = '2.0'
        method = 'resources/read'
        params = @{
            uri = 'moonbitmark://capabilities'
        }
        id = 6
    } | ConvertTo-Json -Compress -Depth 5
    $resourcesReadResponse = Invoke-McpHttpRequest -Url $mcpUrl -RequestJson $resourcesReadRequest
    Assert-ContainsText -Text $resourcesReadResponse.Body.result.contents[0].text -Expected 'resources/list' -Context 'HTTP capabilities resource'

    $promptsListRequest = @{
        jsonrpc = '2.0'
        method = 'prompts/list'
        id = 7
    } | ConvertTo-Json -Compress
    $promptsListResponse = Invoke-McpHttpRequest -Url $mcpUrl -RequestJson $promptsListRequest
    $promptNames = @($promptsListResponse.Body.result.prompts | ForEach-Object { $_.name })
    if (@($promptNames | Where-Object { $_ -eq 'convert-document' }).Count -ne 1) {
        throw 'prompts/list did not expose convert-document over HTTP.'
    }

    $promptsGetRequest = @{
        jsonrpc = '2.0'
        method = 'prompts/get'
        params = @{
            name = 'convert-document'
            arguments = @{
                uri = (Normalize-MoonBitMarkPath $textInput)
            }
        }
        id = 8
    } | ConvertTo-Json -Compress -Depth 5
    $promptsGetResponse = Invoke-McpHttpRequest -Url $mcpUrl -RequestJson $promptsGetRequest
    if (@($promptsGetResponse.Body.result.messages).Count -ne 1) {
        throw 'prompts/get should return exactly one message over HTTP.'
    }

    Write-Host 'MCP HTTP smoke checks passed, including healthz, notification 204, invalid-request 400, tools/resources/prompts coverage, and preview conversion.'
} finally {
    $serverOutput = Stop-NativeProcess -Process $process
    if ($serverOutput.StdOut.Trim() -ne '') {
        throw "HTTP MCP server wrote unexpected stdout:`n$($serverOutput.StdOut)"
    }
    if ($serverOutput.StdErr.Trim() -ne '') {
        throw "HTTP MCP server wrote unexpected stderr:`n$($serverOutput.StdErr)"
    }
}

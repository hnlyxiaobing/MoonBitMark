$ErrorActionPreference = 'Stop'

. "$PSScriptRoot\..\TestHelpers.ps1"

$repoRoot = Get-MoonBitMarkRepoRoot -ScriptPath $PSScriptRoot
$binary = Join-Path $repoRoot '_build\native\release\build\cmd\mcp-server\mcp-server.exe'
$cmdLauncher = Join-Path $repoRoot 'scripts\mcp\moonbitmark-mcp.cmd'
Ensure-MoonBitMarkReleaseBinary -RepoRoot $repoRoot -BinaryPath $binary

function Invoke-McpRawRequest {
    param(
        [Parameter(Mandatory = $true)]
        [string]$RequestJson
    )

    $result = Invoke-NativeCommand -FilePath 'cmd.exe' -Arguments @('/d', '/c', $cmdLauncher) -WorkingDirectory $repoRoot -StdIn $RequestJson
    if ($result.ExitCode -ne 0) {
        throw "MCP server failed for request: $RequestJson`nSTDERR:`n$($result.StdErr)"
    }
    if ($result.StdErr.Trim() -ne '') {
        throw "MCP server wrote to stderr:`n$($result.StdErr)"
    }
    return $result
}

function Invoke-McpRequest {
    param(
        [Parameter(Mandatory = $true)]
        [string]$RequestJson
    )

    $result = Invoke-McpRawRequest -RequestJson $RequestJson
    return $result.StdOut.Trim() | ConvertFrom-Json
}

$initializeRequest = @{
    jsonrpc = '2.0'
    method = 'initialize'
    params = @{
        protocolVersion = '2024-11-05'
        capabilities = @{}
        clientInfo = @{
            name = 'resources-smoke-client'
            version = '1.0.0'
        }
    }
    id = 1
} | ConvertTo-Json -Compress -Depth 5

$initializeResponse = Invoke-McpRequest -RequestJson $initializeRequest
if ($null -eq $initializeResponse.result.capabilities.resources) {
    throw 'initialize response did not advertise resources capability.'
}
if ($initializeResponse.result.capabilities.resources.listChanged -ne $false) {
    throw 'resources capability reported unexpected listChanged value.'
}
if ($initializeResponse.result.capabilities.resources.subscribe -ne $false) {
    throw 'resources capability reported unexpected subscribe value.'
}

$listRequest = @{
    jsonrpc = '2.0'
    method = 'resources/list'
    id = 2
} | ConvertTo-Json -Compress

$listResponse = Invoke-McpRequest -RequestJson $listRequest
$resourceUris = @($listResponse.result.resources | ForEach-Object { $_.uri })
$expectedUris = @(
    'moonbitmark://capabilities',
    'moonbitmark://supported-formats',
    'moonbitmark://known-issues',
    'moonbitmark://ocr-boundaries',
    'moonbitmark://mcp-usage'
)

foreach ($expectedUri in $expectedUris) {
    if (@($resourceUris | Where-Object { $_ -eq $expectedUri }).Count -ne 1) {
        throw "resources/list did not expose expected URI: $expectedUri"
    }
}

$capabilitiesResource = $listResponse.result.resources | Where-Object { $_.uri -eq 'moonbitmark://capabilities' } | Select-Object -First 1
if ($capabilitiesResource.mimeType -ne 'text/markdown') {
    throw "capabilities resource reported unexpected mime type: $($capabilitiesResource.mimeType)"
}

$readRequest = @{
    jsonrpc = '2.0'
    method = 'resources/read'
    params = @{
        uri = 'moonbitmark://capabilities'
    }
    id = 3
} | ConvertTo-Json -Compress -Depth 5

$readResponse = Invoke-McpRequest -RequestJson $readRequest
if (@($readResponse.result.contents).Count -ne 1) {
    throw 'resources/read should return exactly one content item for the static resource.'
}
$content = $readResponse.result.contents[0]
if ($content.uri -ne 'moonbitmark://capabilities') {
    throw "resources/read returned unexpected URI: $($content.uri)"
}
Assert-ContainsText -Text $content.text -Expected 'resources/list' -Context 'capabilities resource'
Assert-ContainsText -Text $content.text -Expected 'convert_to_markdown' -Context 'capabilities resource'

$usageReadRequest = @{
    jsonrpc = '2.0'
    method = 'resources/read'
    params = @{
        uri = 'moonbitmark://mcp-usage'
    }
    id = 4
} | ConvertTo-Json -Compress -Depth 5

$usageReadResponse = Invoke-McpRequest -RequestJson $usageReadRequest
Assert-ContainsText -Text $usageReadResponse.result.contents[0].text -Expected 'mcp_resources_smoke.ps1' -Context 'mcp usage resource'

$missingReadRequest = @{
    jsonrpc = '2.0'
    method = 'resources/read'
    params = @{
        uri = 'moonbitmark://missing'
    }
    id = 5
} | ConvertTo-Json -Compress -Depth 5

$missingReadResponse = Invoke-McpRequest -RequestJson $missingReadRequest
if ($missingReadResponse.error.code -ne -32002) {
    throw "missing resource should return -32002, got $($missingReadResponse.error.code)"
}
if ($missingReadResponse.error.data.uri -ne 'moonbitmark://missing') {
    throw 'missing resource error data did not echo the URI.'
}

Write-Host 'MCP resources smoke checks passed, including capability advertisement, list/read success paths, and missing-resource handling.'

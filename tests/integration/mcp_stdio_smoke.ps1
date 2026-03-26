$ErrorActionPreference = 'Stop'

. "$PSScriptRoot\..\TestHelpers.ps1"

$repoRoot = Get-MoonBitMarkRepoRoot -ScriptPath $PSScriptRoot
$binary = Join-Path $repoRoot '_build\native\release\build\cmd\mcp-server\mcp-server.exe'
Ensure-MoonBitMarkReleaseBinary -RepoRoot $repoRoot -BinaryPath $binary

$tempRoot = Join-Path $repoRoot '_build\test-tmp\mcp'
New-Item -ItemType Directory -Force -Path $tempRoot | Out-Null

$textInput = Join-Path $tempRoot 'smoke.txt'
@(
    'mcp smoke line 1',
    '',
    'mcp smoke line 2'
) | Set-Content -Path $textInput -Encoding utf8

function Invoke-McpRawRequest {
    param(
        [Parameter(Mandatory = $true)]
        [string]$RequestJson
    )

    $result = Invoke-NativeCommand -FilePath $binary -WorkingDirectory $repoRoot -StdIn $RequestJson
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

$notificationRequest = @{
    jsonrpc = '2.0'
    method = 'notifications/initialized'
    params = @{}
} | ConvertTo-Json -Compress

$notificationResponse = Invoke-McpRawRequest -RequestJson $notificationRequest
if ($notificationResponse.StdOut.Trim() -ne '') {
    throw 'MCP notifications must not emit a stdout response.'
}

$initializeRequest = @{
    jsonrpc = '2.0'
    method = 'initialize'
    params = @{
        protocolVersion = '2024-11-05'
        capabilities = @{}
        clientInfo = @{
            name = 'smoke-client'
            version = '1.0.0'
        }
    }
    id = 1
} | ConvertTo-Json -Compress -Depth 5

$initializeResponse = Invoke-McpRequest -RequestJson $initializeRequest
if ($initializeResponse.result.serverInfo.name -ne 'moonbitmark') {
    throw "Unexpected MCP server name: $($initializeResponse.result.serverInfo.name)"
}

$toolsListRequest = @{
    jsonrpc = '2.0'
    method = 'tools/list'
    id = 2
} | ConvertTo-Json -Compress

$toolsListResponse = Invoke-McpRequest -RequestJson $toolsListRequest
if ($toolsListResponse.result.tools[0].name -ne 'convert_to_markdown') {
    throw 'tools/list did not expose convert_to_markdown.'
}

$toolsCallRequest = @{
    jsonrpc = '2.0'
    method = 'tools/call'
    params = @{
        name = 'convert_to_markdown'
        arguments = @{
            uri = (Normalize-MoonBitMarkPath $textInput)
        }
    }
    id = 3
} | ConvertTo-Json -Compress -Depth 5

$toolsCallResponse = Invoke-McpRequest -RequestJson $toolsCallRequest
if ($toolsCallResponse.result.isError -ne $false) {
    throw 'tools/call unexpectedly returned an error result.'
}
Assert-ContainsText -Text $toolsCallResponse.result.content[0].text -Expected 'mcp smoke line 1' -Context 'tools/call markdown'

Write-Host 'MCP stdio smoke checks passed.'

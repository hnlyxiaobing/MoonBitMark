$ErrorActionPreference = 'Stop'

. "$PSScriptRoot\..\TestHelpers.ps1"

$repoRoot = Get-MoonBitMarkRepoRoot -ScriptPath $PSScriptRoot
$binary = Join-Path $repoRoot '_build\native\release\build\cmd\mcp-server\mcp-server.exe'
$cmdLauncher = Join-Path $repoRoot 'scripts\mcp\moonbitmark-mcp.cmd'
$psLauncher = Join-Path $repoRoot 'scripts\mcp\moonbitmark-mcp.ps1'
Ensure-MoonBitMarkReleaseBinary -RepoRoot $repoRoot -BinaryPath $binary

$tempRoot = Join-Path $repoRoot '_build\test-tmp\mcp'
New-Item -ItemType Directory -Force -Path $tempRoot | Out-Null

$textInput = Join-Path $tempRoot 'smoke.txt'
1..800 | ForEach-Object {
    "mcp smoke line $_"
} | Set-Content -Path $textInput -Encoding utf8

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

function Invoke-McpRawRequest {
    param(
        [Parameter(Mandatory = $true)]
        [string]$FilePath,

        [string[]]$Arguments = @(),

        [hashtable]$Environment = @{},

        [Parameter(Mandatory = $true)]
        [string]$RequestJson
    )

    $result = Invoke-NativeCommand -FilePath $FilePath -Arguments $Arguments -WorkingDirectory $repoRoot -Environment $Environment -StdIn $RequestJson
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
        [string]$FilePath,

        [string[]]$Arguments = @(),

        [hashtable]$Environment = @{},

        [Parameter(Mandatory = $true)]
        [string]$RequestJson
    )

    $result = Invoke-McpRawRequest -FilePath $FilePath -Arguments $Arguments -Environment $Environment -RequestJson $RequestJson
    return $result.StdOut.Trim() | ConvertFrom-Json
}

$cmdLauncherArgs = @('/d', '/c', $cmdLauncher)
$psLauncherArgs = @(
    '-NoLogo',
    '-NoProfile',
    '-ExecutionPolicy',
    'Bypass',
    '-File',
    $psLauncher
)

$notificationRequest = @{
    jsonrpc = '2.0'
    method = 'notifications/initialized'
    params = @{}
} | ConvertTo-Json -Compress

$notificationResponse = Invoke-McpRawRequest -FilePath 'cmd.exe' -Arguments $cmdLauncherArgs -RequestJson $notificationRequest
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

$releaseOnlyPath = "$env:SystemRoot\System32;$env:SystemRoot"
$initializeResponse = Invoke-McpRequest -FilePath 'cmd.exe' -Arguments $cmdLauncherArgs -Environment @{ PATH = $releaseOnlyPath } -RequestJson $initializeRequest
if ($initializeResponse.result.serverInfo.name -ne 'moonbitmark') {
    throw "Unexpected MCP server name: $($initializeResponse.result.serverInfo.name)"
}
if (-not $initializeResponse.result.instructions.ToLowerInvariant().Contains('inspect')) {
    throw 'initialize response did not expose agent-facing instructions.'
}

$psInitializeResponse = Invoke-McpRequest -FilePath 'powershell.exe' -Arguments $psLauncherArgs -RequestJson $initializeRequest
if ($psInitializeResponse.result.serverInfo.name -ne 'moonbitmark') {
    throw "PowerShell launcher returned unexpected server name: $($psInitializeResponse.result.serverInfo.name)"
}

$fallbackInitializeResponse = Invoke-McpRequest -FilePath 'cmd.exe' -Arguments $cmdLauncherArgs -Environment @{ MOONBITMARK_MCP_SKIP_RELEASE_BINARY = '1' } -RequestJson $initializeRequest
if ($fallbackInitializeResponse.result.serverInfo.name -ne 'moonbitmark') {
    throw "Fallback launcher returned unexpected server name: $($fallbackInitializeResponse.result.serverInfo.name)"
}

$toolsListRequest = @{
    jsonrpc = '2.0'
    method = 'tools/list'
    id = 2
} | ConvertTo-Json -Compress

$toolsListResponse = Invoke-McpRequest -FilePath 'cmd.exe' -Arguments $cmdLauncherArgs -RequestJson $toolsListRequest
$toolNames = @($toolsListResponse.result.tools | ForEach-Object { $_.name })
if (@($toolNames | Where-Object { $_ -eq 'inspect_document' }).Count -ne 1) {
    throw 'tools/list did not expose inspect_document.'
}
if (@($toolNames | Where-Object { $_ -eq 'convert_to_markdown' }).Count -ne 1) {
    throw 'tools/list did not expose convert_to_markdown.'
}
$convertTool = $toolsListResponse.result.tools | Where-Object { $_.name -eq 'convert_to_markdown' } | Select-Object -First 1
if (-not $convertTool.description.Contains('preview')) {
    throw 'convert_to_markdown description did not mention preview mode.'
}
if ($null -eq $convertTool.inputSchema.properties.mode) {
    throw 'convert_to_markdown schema did not expose mode.'
}
if ($null -eq $convertTool.inputSchema.properties.max_chars) {
    throw 'convert_to_markdown schema did not expose max_chars.'
}
if ($null -eq $convertTool.inputSchema.properties.format_hint) {
    throw 'convert_to_markdown schema did not expose format_hint.'
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

$inspectResponse = Invoke-McpRequest -FilePath 'cmd.exe' -Arguments $cmdLauncherArgs -RequestJson $inspectRequest
if ($inspectResponse.result.isError -ne $false) {
    throw 'inspect_document unexpectedly returned an error result.'
}
$inspectSummary = Convert-SummaryTextToMap -Text $inspectResponse.result.content[0].text
if ($inspectSummary['detected_format'] -ne 'text') {
    throw "inspect_document detected unexpected format: $($inspectSummary['detected_format'])"
}
if ($inspectSummary['preview_recommended'] -ne 'true') {
    throw 'inspect_document did not recommend preview for the large smoke fixture.'
}

$previewCallRequest = @{
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

$previewCallResponse = Invoke-McpRequest -FilePath 'cmd.exe' -Arguments $cmdLauncherArgs -RequestJson $previewCallRequest
if ($previewCallResponse.result.isError -ne $false) {
    throw 'preview convert_to_markdown unexpectedly returned an error result.'
}
$previewSummary = Convert-SummaryTextToMap -Text $previewCallResponse.result.content[0].text
if ($previewSummary['mode'] -ne 'preview') {
    throw "convert_to_markdown defaulted to unexpected mode: $($previewSummary['mode'])"
}
if ($previewSummary['truncated'] -ne 'true') {
    throw 'preview convert_to_markdown did not truncate the large fixture.'
}
Assert-ContainsText -Text $previewCallResponse.result.content[1].text -Expected 'mcp smoke line 1' -Context 'preview markdown'

$fullCallRequest = @{
    jsonrpc = '2.0'
    method = 'tools/call'
    params = @{
        name = 'convert_to_markdown'
        arguments = @{
            uri = (Normalize-MoonBitMarkPath $textInput)
            mode = 'full'
            max_chars = 6000
            format_hint = 'text'
        }
    }
    id = 5
} | ConvertTo-Json -Compress -Depth 5

$fullCallResponse = Invoke-McpRequest -FilePath 'cmd.exe' -Arguments $cmdLauncherArgs -RequestJson $fullCallRequest
if ($fullCallResponse.result.isError -ne $false) {
    throw 'full convert_to_markdown unexpectedly returned an error result.'
}
$fullSummary = Convert-SummaryTextToMap -Text $fullCallResponse.result.content[0].text
if ($fullSummary['mode'] -ne 'full') {
    throw "full convert_to_markdown returned unexpected mode: $($fullSummary['mode'])"
}
if ($fullSummary['format_hint_applied'] -ne 'true') {
    throw 'full convert_to_markdown did not record the format hint.'
}
if ([int]$fullSummary['returned_chars'] -le [int]$previewSummary['returned_chars']) {
    throw 'full convert_to_markdown did not return more text than preview mode.'
}

$invalidModeRequest = @{
    jsonrpc = '2.0'
    method = 'tools/call'
    params = @{
        name = 'convert_to_markdown'
        arguments = @{
            uri = (Normalize-MoonBitMarkPath $textInput)
            mode = 'invalid'
        }
    }
    id = 6
} | ConvertTo-Json -Compress -Depth 5

$invalidModeResponse = Invoke-McpRequest -FilePath 'cmd.exe' -Arguments $cmdLauncherArgs -RequestJson $invalidModeRequest
if ($invalidModeResponse.result.isError -ne $true) {
    throw 'invalid mode should have returned an MCP tool error result.'
}
Assert-ContainsText -Text $invalidModeResponse.result.content[0].text -Expected "'mode' must be 'preview' or 'full'" -Context 'invalid mode error'

Write-Host 'MCP stdio smoke checks passed, including launcher paths, inspect_document, preview/full conversion, and a negative mode path.'

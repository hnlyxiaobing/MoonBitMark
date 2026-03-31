$ErrorActionPreference = 'Stop'

. "$PSScriptRoot\..\TestHelpers.ps1"

$repoRoot = Get-MoonBitMarkRepoRoot -ScriptPath $PSScriptRoot
$binary = Join-Path $repoRoot '_build\native\release\build\cmd\mcp-server\mcp-server.exe'
$cmdLauncher = Join-Path $repoRoot 'scripts\mcp\moonbitmark-mcp.cmd'
Ensure-MoonBitMarkReleaseBinary -RepoRoot $repoRoot -BinaryPath $binary

$tempRoot = Join-Path $repoRoot '_build\test-tmp\mcp-security'
New-Item -ItemType Directory -Force -Path $tempRoot | Out-Null
$allowedRoot = Join-Path $tempRoot 'allowed'
New-Item -ItemType Directory -Force -Path $allowedRoot | Out-Null
$textInput = Join-Path $allowedRoot 'security.txt'
1..200 | ForEach-Object {
    "security smoke line $_"
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

function Invoke-McpRequest {
    param(
        [Parameter(Mandatory = $true)]
        [string]$RequestJson,

        [hashtable]$Environment = @{}
    )

    $result = Invoke-NativeCommand -FilePath 'cmd.exe' -Arguments @('/d', '/c', $cmdLauncher) -WorkingDirectory $repoRoot -Environment $Environment -StdIn $RequestJson
    if ($result.ExitCode -ne 0) {
        throw "MCP server failed for request: $RequestJson`nSTDERR:`n$($result.StdErr)"
    }
    if ($result.StdErr.Trim() -ne '') {
        throw "MCP server wrote to stderr:`n$($result.StdErr)"
    }
    return $result.StdOut.Trim() | ConvertFrom-Json
}

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

$inspectHttpResponse = Invoke-McpRequest -RequestJson $inspectHttpRequest
if ($inspectHttpResponse.result.isError -ne $true) {
    throw 'HTTP inspect should fail when MOONBITMARK_MCP_ALLOW_HTTP is unset.'
}
Assert-ContainsText -Text $inspectHttpResponse.result.content[0].text -Expected 'MOONBITMARK_MCP_ALLOW_HTTP' -Context 'http boundary'

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

$outsideRootResponse = Invoke-McpRequest -RequestJson $outsideRootRequest -Environment @{
    MOONBITMARK_MCP_ALLOWED_ROOTS = (Normalize-MoonBitMarkPath $allowedRoot)
}
if ($outsideRootResponse.result.isError -ne $true) {
    throw 'inspect_document should fail outside MOONBITMARK_MCP_ALLOWED_ROOTS.'
}
Assert-ContainsText -Text $outsideRootResponse.result.content[0].text -Expected 'MOONBITMARK_MCP_ALLOWED_ROOTS' -Context 'allowed roots boundary'

$insideRootInspectRequest = @{
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

$insideRootInspectResponse = Invoke-McpRequest -RequestJson $insideRootInspectRequest -Environment @{
    MOONBITMARK_MCP_ALLOWED_ROOTS = (Normalize-MoonBitMarkPath $allowedRoot)
    MOONBITMARK_MCP_ENABLE_OCR = '1'
}
if ($insideRootInspectResponse.result.isError -ne $false) {
    throw 'inspect_document should succeed inside MOONBITMARK_MCP_ALLOWED_ROOTS.'
}
$inspectSummary = Convert-SummaryTextToMap -Text $insideRootInspectResponse.result.content[0].text
if ($inspectSummary['ocr_enabled_by_env'] -ne 'true') {
    throw 'inspect_document did not surface MOONBITMARK_MCP_ENABLE_OCR in the summary.'
}

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

$convertResponse = Invoke-McpRequest -RequestJson $convertRequest -Environment @{
    MOONBITMARK_MCP_ALLOWED_ROOTS = (Normalize-MoonBitMarkPath $allowedRoot)
    MOONBITMARK_MCP_MAX_OUTPUT_CHARS = '80'
}
if ($convertResponse.result.isError -ne $false) {
    throw 'convert_to_markdown should succeed inside the allowed root.'
}
$convertSummary = Convert-SummaryTextToMap -Text $convertResponse.result.content[0].text
if ($convertSummary['effective_max_chars'] -ne '80') {
    throw "effective_max_chars should be clamped to 80, got $($convertSummary['effective_max_chars'])"
}
if ($convertSummary['returned_chars'] -ne '80') {
    throw "returned_chars should be clamped to 80, got $($convertSummary['returned_chars'])"
}
if ($convertSummary['truncated'] -ne 'true') {
    throw 'convert_to_markdown should report truncation under MOONBITMARK_MCP_MAX_OUTPUT_CHARS.'
}

Write-Host 'MCP security smoke checks passed, including HTTP denial, allowed-roots enforcement, OCR env surfacing, and output-cap clamping.'

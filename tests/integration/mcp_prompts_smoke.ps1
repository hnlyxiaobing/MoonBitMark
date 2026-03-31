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
            name = 'prompts-smoke-client'
            version = '1.0.0'
        }
    }
    id = 1
} | ConvertTo-Json -Compress -Depth 5

$initializeResponse = Invoke-McpRequest -RequestJson $initializeRequest
if ($null -eq $initializeResponse.result.capabilities.prompts) {
    throw 'initialize response did not advertise prompts capability.'
}
if ($initializeResponse.result.capabilities.prompts.listChanged -ne $false) {
    throw 'prompts capability reported unexpected listChanged value.'
}

$listRequest = @{
    jsonrpc = '2.0'
    method = 'prompts/list'
    id = 2
} | ConvertTo-Json -Compress

$listResponse = Invoke-McpRequest -RequestJson $listRequest
$promptNames = @($listResponse.result.prompts | ForEach-Object { $_.name })
foreach ($expectedName in @('convert-document', 'diagnose-conversion-failure')) {
    if (@($promptNames | Where-Object { $_ -eq $expectedName }).Count -ne 1) {
        throw "prompts/list did not expose expected prompt: $expectedName"
    }
}

$convertPrompt = $listResponse.result.prompts | Where-Object { $_.name -eq 'convert-document' } | Select-Object -First 1
if ($convertPrompt.arguments.Count -lt 1) {
    throw 'convert-document prompt did not expose arguments.'
}

$getConvertRequest = @{
    jsonrpc = '2.0'
    method = 'prompts/get'
    params = @{
        name = 'convert-document'
        arguments = @{
            uri = 'docs/sample.pdf'
            mode = 'preview'
        }
    }
    id = 3
} | ConvertTo-Json -Compress -Depth 6

$getConvertResponse = Invoke-McpRequest -RequestJson $getConvertRequest
if (@($getConvertResponse.result.messages).Count -ne 1) {
    throw 'convert-document prompt should return exactly one message.'
}
Assert-ContainsText -Text $getConvertResponse.result.messages[0].content.text -Expected 'inspect_document' -Context 'convert-document prompt'
Assert-ContainsText -Text $getConvertResponse.result.messages[0].content.text -Expected 'mode=preview' -Context 'convert-document prompt'

$getDiagnoseRequest = @{
    jsonrpc = '2.0'
    method = 'prompts/get'
    params = @{
        name = 'diagnose-conversion-failure'
        arguments = @{
            uri = 'docs/broken.pdf'
            failure_summary = 'preview returned an empty result'
        }
    }
    id = 4
} | ConvertTo-Json -Compress -Depth 6

$getDiagnoseResponse = Invoke-McpRequest -RequestJson $getDiagnoseRequest
Assert-ContainsText -Text $getDiagnoseResponse.result.messages[0].content.text -Expected 'moonbitmark://known-issues' -Context 'diagnose prompt'
Assert-ContainsText -Text $getDiagnoseResponse.result.messages[0].content.text -Expected 'preview mode' -Context 'diagnose prompt'

$missingPromptRequest = @{
    jsonrpc = '2.0'
    method = 'prompts/get'
    params = @{
        name = 'missing-prompt'
    }
    id = 5
} | ConvertTo-Json -Compress -Depth 5

$missingPromptResponse = Invoke-McpRequest -RequestJson $missingPromptRequest
if ($missingPromptResponse.error.code -ne -32602) {
    throw "missing prompt should return -32602, got $($missingPromptResponse.error.code)"
}

$missingArgumentRequest = @{
    jsonrpc = '2.0'
    method = 'prompts/get'
    params = @{
        name = 'diagnose-conversion-failure'
        arguments = @{
            uri = 'docs/broken.pdf'
        }
    }
    id = 6
} | ConvertTo-Json -Compress -Depth 5

$missingArgumentResponse = Invoke-McpRequest -RequestJson $missingArgumentRequest
if ($missingArgumentResponse.error.code -ne -32602) {
    throw "missing required prompt argument should return -32602, got $($missingArgumentResponse.error.code)"
}
Assert-ContainsText -Text $missingArgumentResponse.error.message -Expected 'failure_summary' -Context 'missing prompt argument error'

Write-Host 'MCP prompts smoke checks passed, including capability advertisement, list/get success paths, and negative prompt paths.'

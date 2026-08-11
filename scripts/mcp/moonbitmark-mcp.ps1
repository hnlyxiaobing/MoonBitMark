param(
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$ForwardArgs
)

$ErrorActionPreference = 'Stop'

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot = (Resolve-Path (Join-Path $scriptDir '..\..')).Path
. (Join-Path $repoRoot 'tests\TestHelpers.ps1')
$releaseBinary = Get-MoonBitMarkBuildArtifact -RepoRoot $repoRoot -ExecutableName 'mcp-server.exe'
$skipReleaseBinary = $env:MOONBITMARK_MCP_SKIP_RELEASE_BINARY -eq '1'

Push-Location $repoRoot
try {
    if (-not $skipReleaseBinary -and (Test-Path $releaseBinary)) {
        & $releaseBinary @ForwardArgs
    }
    else {
        & moon run --target native --release -q cmd/mcp-server @ForwardArgs
    }

    exit $LASTEXITCODE
}
finally {
    Pop-Location
}

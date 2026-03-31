param(
    [switch]$SkipTests,
    [switch]$SkipBuild,
    [switch]$IncludeMcp
)

$ErrorActionPreference = 'Stop'

. "$PSScriptRoot\..\tests\TestHelpers.ps1"

$repoRoot = Get-MoonBitMarkRepoRoot -ScriptPath $PSScriptRoot
$binary = Join-Path $repoRoot '_build\native\release\build\cmd\main\main.exe'
$outputRoot = Join-Path $repoRoot '_build\judge-quickstart'
$htmlInput = Join-Path $repoRoot 'tests\conversion_eval\fixtures\inputs\html\simple_table.html'
$pdfInput = Join-Path $repoRoot 'tests\conversion_eval\fixtures\inputs\pdf\multi_page.pdf'
$markdownOutput = Join-Path $outputRoot 'html_simple_table.md'
$diagOutput = Join-Path $outputRoot 'pdf_multi_page_diag.json'
$astOutput = Join-Path $outputRoot 'html_simple_table_ast.json'

function Ensure-JudgeQuickstartBinary {
    param(
        [Parameter(Mandatory = $true)]
        [string]$RepoRoot,

        [Parameter(Mandatory = $true)]
        [string]$BinaryPath,

        [Parameter(Mandatory = $true)]
        [bool]$AllowBuild
    )

    if (Test-Path $BinaryPath) {
        return
    }

    if (-not $AllowBuild) {
        throw "Missing release binary: $BinaryPath. Re-run without -SkipBuild to let the script build it."
    }

    Push-Location $RepoRoot
    try {
        cmd.exe /d /c scripts\build.bat | Out-Host
    } finally {
        Pop-Location
    }

    if (-not (Test-Path $BinaryPath)) {
        throw "Missing release binary after build: $BinaryPath"
    }
}

function Write-Step {
    param([string]$Title)
    Write-Host ''
    Write-Host "== $Title =="
}

Ensure-JudgeQuickstartBinary -RepoRoot $repoRoot -BinaryPath $binary -AllowBuild (-not $SkipBuild)
New-Item -ItemType Directory -Force -Path $outputRoot | Out-Null

if (-not $SkipTests) {
    Write-Step '1. moon test'
    Push-Location $repoRoot
    try {
        moon test | Out-Host
    } finally {
        Pop-Location
    }
}

Write-Step '2. HTML sample -> Markdown'
$htmlResult = Invoke-NativeCommand -FilePath $binary -Arguments @(
    (Normalize-MoonBitMarkPath $htmlInput)
) -WorkingDirectory $repoRoot
if ($htmlResult.ExitCode -ne 0) {
    throw "HTML sample conversion failed: $($htmlResult.StdErr)"
}
$htmlMarkdown = $htmlResult.StdOut.Trim()
$htmlMarkdown | Set-Content -Path $markdownOutput -Encoding utf8
Write-Host "Saved markdown output: $markdownOutput"
Write-Host ($htmlMarkdown -split "`r?`n" | Select-Object -First 8 | Out-String)

Write-Step '3. PDF diag-json'
$diagResult = Invoke-NativeCommand -FilePath $binary -Arguments @(
    '--diag-json',
    (Normalize-MoonBitMarkPath $pdfInput)
) -WorkingDirectory $repoRoot
if ($diagResult.ExitCode -ne 0) {
    throw "PDF diag-json failed: $($diagResult.StdErr)"
}
$diagJson = $diagResult.StdOut.Trim() | ConvertFrom-Json
$diagResult.StdOut.Trim() | Set-Content -Path $diagOutput -Encoding utf8
Write-Host "Saved diagnostics JSON: $diagOutput"
Write-Host "title: $($diagJson.title)"
Write-Host "warnings: $($diagJson.warnings.Count)"
Write-Host "diagnostics: $($diagJson.diagnostics.Count)"
Write-Host "stats.char_count: $($diagJson.stats.char_count)"
Write-Host "stats.block_count: $($diagJson.stats.block_count)"

Write-Step '4. HTML dump-ast'
$astResult = Invoke-NativeCommand -FilePath $binary -Arguments @(
    '--dump-ast',
    (Normalize-MoonBitMarkPath $htmlInput)
) -WorkingDirectory $repoRoot
if ($astResult.ExitCode -ne 0) {
    throw "HTML dump-ast failed: $($astResult.StdErr)"
}
$astJson = $astResult.StdOut.Trim() | ConvertFrom-Json
$astResult.StdOut.Trim() | Set-Content -Path $astOutput -Encoding utf8
Write-Host "Saved AST JSON: $astOutput"
Write-Host "title: $($astJson.title)"
Write-Host "blocks: $($astJson.blocks.Count)"

if ($IncludeMcp) {
    Write-Step '5. MCP smoke'
    Push-Location $repoRoot
    try {
        powershell -ExecutionPolicy Bypass -File tests\integration\mcp_stdio_smoke.ps1 | Out-Host
    } finally {
        Pop-Location
    }
}

Write-Step 'Summary'
Write-Host "Repo root: $repoRoot"
Write-Host "Release binary: $binary"
Write-Host "Artifacts: $outputRoot"
Write-Host 'Judge quickstart completed.'

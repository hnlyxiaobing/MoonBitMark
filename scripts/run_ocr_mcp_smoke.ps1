$ErrorActionPreference = 'Stop'

. "$PSScriptRoot\..\tests\TestHelpers.ps1"

$repoRoot = Get-MoonBitMarkRepoRoot -ScriptPath $PSScriptRoot

function Invoke-SmokeScript {
    param(
        [Parameter(Mandatory = $true)]
        [string]$RelativePath
    )

    Write-Host ''
    Write-Host "== $RelativePath =="
    Push-Location $repoRoot
    try {
        powershell -ExecutionPolicy Bypass -File $RelativePath | Out-Host
    } finally {
        Pop-Location
    }
}

Write-Host 'Running OCR + MCP smoke regression suite...'
Invoke-SmokeScript -RelativePath 'tests\ocr\pdf_ocr_force_smoke.ps1'
Invoke-SmokeScript -RelativePath 'tests\integration\mcp_stdio_smoke.ps1'
Write-Host ''
Write-Host 'OCR + MCP smoke regression suite passed.'

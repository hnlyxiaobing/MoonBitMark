$ErrorActionPreference = 'Stop'

. "$PSScriptRoot\..\TestHelpers.ps1"

$repoRoot = Get-MoonBitMarkRepoRoot -ScriptPath $PSScriptRoot
$binary = Join-Path $repoRoot '_build\native\release\build\cmd\main\main.exe'
Ensure-MoonBitMarkReleaseBinary -RepoRoot $repoRoot -BinaryPath $binary

$imageInput = Join-Path $repoRoot 'tests\conversion_eval\fixtures\inputs\image\example.jpg'

$result = Invoke-NativeCommand -FilePath $binary -Arguments @(
    '--ocr', 'force',
    '--ocr-backend', 'mock',
    '--ocr-lang', 'eng',
    '--diag-json',
    (Normalize-MoonBitMarkPath $imageInput)
) -WorkingDirectory $repoRoot

if ($result.ExitCode -ne 0) {
    throw "OCR force smoke failed: $($result.StdErr)"
}

$json = $result.StdOut.Trim() | ConvertFrom-Json
if ($json.metadata.ocr_attempted -ne 'true') {
    throw 'OCR force smoke did not attempt OCR.'
}
if ($json.metadata.ocr_available -ne 'true') {
    throw 'OCR force smoke did not report an available backend.'
}
if ($json.metadata.ocr_provider -ne 'mock') {
    throw "Unexpected OCR provider: $($json.metadata.ocr_provider)"
}
if ($json.warnings.Count -ne 0) {
    throw "OCR force smoke emitted warnings: $($json.warnings -join '; ')"
}

Write-Host 'OCR force smoke checks passed.'

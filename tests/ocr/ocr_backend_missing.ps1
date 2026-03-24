$ErrorActionPreference = 'Stop'

. "$PSScriptRoot\..\TestHelpers.ps1"

$repoRoot = Get-MoonBitMarkRepoRoot -ScriptPath $PSScriptRoot
$binary = Join-Path $repoRoot '_build\native\release\build\cmd\main\main.exe'
Ensure-MoonBitMarkReleaseBinary -RepoRoot $repoRoot -BinaryPath $binary

$imageInput = Join-Path $repoRoot 'tests\conversion_eval\fixtures\inputs\image\example.jpg'
$pythonPath = (Get-Command python).Source
$pythonDir = Split-Path -Parent $pythonPath
$minimalPath = @(
    $pythonDir,
    "$env:SystemRoot\System32",
    "$env:SystemRoot",
    "$env:SystemRoot\System32\WindowsPowerShell\v1.0"
) -join ';'

$result = Invoke-NativeCommand -FilePath $binary -Arguments @(
    '--ocr', 'force',
    '--ocr-backend', 'tesseract',
    '--diag-json',
    (Normalize-MoonBitMarkPath $imageInput)
) -WorkingDirectory $repoRoot -Environment @{ PATH = $minimalPath }

if ($result.ExitCode -ne 0) {
    throw "OCR backend missing check failed: $($result.StdErr)"
}

$json = $result.StdOut.Trim() | ConvertFrom-Json
if ($json.metadata.ocr_available -ne 'false') {
    throw 'OCR backend missing check unexpectedly reported available OCR.'
}
$joinedWarnings = $json.warnings -join "`n"
if (-not ($joinedWarnings.Contains('tesseract executable was not found on PATH.') -or $joinedWarnings.Contains('OCR requested but no available backend was found.'))) {
    throw "Unexpected OCR backend missing warnings:`n$joinedWarnings"
}

Write-Host 'OCR backend missing checks passed.'

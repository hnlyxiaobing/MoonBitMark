$ErrorActionPreference = 'Stop'

. "$PSScriptRoot\..\TestHelpers.ps1"

$repoRoot = Get-MoonBitMarkRepoRoot -ScriptPath $PSScriptRoot
$binary = Join-Path $repoRoot '_build\native\release\build\cmd\main\main.exe'
Ensure-MoonBitMarkReleaseBinary -RepoRoot $repoRoot -BinaryPath $binary

$tempRoot = Join-Path $repoRoot '_build\test-tmp\ocr-timeout'
$fakeBin = Join-Path $tempRoot 'bin'
New-Item -ItemType Directory -Force -Path $fakeBin | Out-Null

$fakeTesseract = Join-Path $fakeBin 'tesseract.cmd'
$powershellExe = "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe"
@(
    '@echo off',
    """$powershellExe"" -NoLogo -NoProfile -Command ""Start-Sleep -Milliseconds 1200""",
    'exit /b 0'
) | Set-Content -Path $fakeTesseract -Encoding ascii

$pythonPath = (Get-Command python).Source
$pythonDir = Split-Path -Parent $pythonPath
$pathOverride = @(
    $fakeBin,
    $pythonDir,
    "$env:SystemRoot\System32",
    "$env:SystemRoot",
    "$env:SystemRoot\System32\WindowsPowerShell\v1.0"
) -join ';'

$imageInput = Join-Path $repoRoot 'tests\conversion_eval\fixtures\inputs\image\example.jpg'
$result = Invoke-NativeCommand -FilePath $binary -Arguments @(
    '--ocr', 'force',
    '--ocr-backend', 'tesseract',
    '--ocr-timeout', '100',
    '--diag-json',
    (Normalize-MoonBitMarkPath $imageInput)
) -WorkingDirectory $repoRoot -Environment @{ PATH = $pathOverride }

if ($result.ExitCode -ne 0) {
    throw "OCR timeout smoke failed: $($result.StdErr)"
}

$json = $result.StdOut.Trim() | ConvertFrom-Json
if ($json.metadata.ocr_available -ne 'false') {
    throw 'OCR timeout smoke unexpectedly reported available OCR.'
}
$joinedWarnings = $json.warnings -join "`n"
Assert-ContainsText -Text $joinedWarnings -Expected 'OCR backend timed out.' -Context 'OCR timeout warning'

Write-Host 'OCR timeout smoke checks passed.'

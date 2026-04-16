$ErrorActionPreference = 'Stop'

. "$PSScriptRoot\..\TestHelpers.ps1"

$repoRoot = Get-MoonBitMarkRepoRoot -ScriptPath $PSScriptRoot
$binary = Join-Path $repoRoot '_build\native\release\build\cmd\main\main.exe'
Ensure-MoonBitMarkReleaseBinary -RepoRoot $repoRoot -BinaryPath $binary

$pdfInput = Join-Path $repoRoot 'tests\conversion_eval\fixtures\inputs\pdf\scanned_multi_page_mock.pdf'

$markdownResult = Invoke-NativeCommand -FilePath $binary -Arguments @(
    '--ocr', 'force',
    '--ocr-backend', 'mock',
    (Normalize-MoonBitMarkPath $pdfInput)
) -WorkingDirectory $repoRoot

if ($markdownResult.ExitCode -ne 0) {
    throw "PDF OCR force smoke failed: $($markdownResult.StdErr)"
}

Assert-ContainsText -Text $markdownResult.StdOut -Expected 'scanned multi page mock page 1' -Context 'PDF OCR page 1 markdown'
Assert-ContainsText -Text $markdownResult.StdOut -Expected 'scanned multi page mock page 2' -Context 'PDF OCR page 2 markdown'

$jsonResult = Invoke-NativeCommand -FilePath $binary -Arguments @(
    '--ocr', 'force',
    '--ocr-backend', 'mock',
    '--diag-json',
    (Normalize-MoonBitMarkPath $pdfInput)
) -WorkingDirectory $repoRoot

if ($jsonResult.ExitCode -ne 0) {
    throw "PDF OCR diag-json smoke failed: $($jsonResult.StdErr)"
}

$json = $jsonResult.StdOut.Trim() | ConvertFrom-Json
if ($json.metadata.ocr_available -ne 'true') {
    throw 'PDF OCR smoke did not report an available backend.'
}
if ($json.metadata.ocr_fallback_used -ne 'true') {
    throw 'PDF OCR smoke did not report OCR fallback usage.'
}
if ($json.metadata.route_recovery_pages -ne '2') {
    throw "Unexpected PDF recovery page count: $($json.metadata.route_recovery_pages)"
}
if ($json.metadata.route_recovery_page_numbers -ne '1,2') {
    throw "Unexpected PDF recovery page numbers: $($json.metadata.route_recovery_page_numbers)"
}
if (-not $json.metadata.route_recovery_reasons.Contains('page 1')) {
    throw "PDF OCR smoke did not report recovery reasons: $($json.metadata.route_recovery_reasons)"
}
if ($json.metadata.pdf_text_fallback_used -ne 'false') {
    throw 'PDF OCR smoke unexpectedly reported text fallback usage.'
}
$joinedWarnings = $json.warnings -join "`n"
if ($joinedWarnings.Contains('fallback provider: mbtpdf')) {
    throw "PDF OCR smoke still reported OCR recovery as text fallback:`n$joinedWarnings"
}
Assert-ContainsText -Text $joinedWarnings -Expected 'PDF OCR recovery supplemented low-text pages.' -Context 'PDF OCR warning'

Write-Host 'PDF OCR force smoke checks passed.'

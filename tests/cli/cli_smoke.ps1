$ErrorActionPreference = 'Stop'

. "$PSScriptRoot\..\TestHelpers.ps1"

$repoRoot = Get-MoonBitMarkRepoRoot -ScriptPath $PSScriptRoot
$binary = Join-Path $repoRoot '_build\native\release\build\cmd\main\main.exe'
Ensure-MoonBitMarkReleaseBinary -RepoRoot $repoRoot -BinaryPath $binary

$tempRoot = Join-Path $repoRoot '_build\test-tmp\cli-smoke'
New-Item -ItemType Directory -Force -Path $tempRoot | Out-Null

$textInput = Join-Path $tempRoot 'sample.txt'
$htmlInput = Join-Path $tempRoot 'sample.html'
$imageInput = Join-Path $repoRoot 'tests\conversion_eval\fixtures\inputs\image\example.jpg'
$outputMarkdown = Join-Path $tempRoot 'sample.md'
$imageMarkdown = Join-Path $tempRoot 'image.md'
$assetDir = Join-Path $tempRoot 'assets'

@(
    'alpha line',
    '',
    'beta line'
) | Set-Content -Path $textInput -Encoding utf8

@(
    '<html><head><title>Smoke Title</title></head>',
    '<body><h1>Heading</h1><p>Paragraph</p></body></html>'
) | Set-Content -Path $htmlInput -Encoding utf8

$help = Invoke-NativeCommand -FilePath $binary -Arguments @('--help') -WorkingDirectory $repoRoot
if ($help.ExitCode -ne 0) {
    throw "CLI --help failed: $($help.StdErr)"
}
Assert-ContainsText -Text $help.StdOut -Expected 'Usage:' -Context '--help output'

$frontmatter = Invoke-NativeCommand -FilePath $binary -Arguments @('--frontmatter', (Normalize-MoonBitMarkPath $textInput)) -WorkingDirectory $repoRoot
if ($frontmatter.ExitCode -ne 0) {
    throw "frontmatter conversion failed: $($frontmatter.StdErr)"
}
Assert-ContainsText -Text $frontmatter.StdOut -Expected '---' -Context '--frontmatter output'

$plainText = Invoke-NativeCommand -FilePath $binary -Arguments @('--plain-text', (Normalize-MoonBitMarkPath $textInput)) -WorkingDirectory $repoRoot
if ($plainText.ExitCode -ne 0) {
    throw "plain-text conversion failed: $($plainText.StdErr)"
}
Assert-ContainsText -Text $plainText.StdOut -Expected 'alpha line' -Context '--plain-text output'

$diagNoMetadata = Invoke-NativeCommand -FilePath $binary -Arguments @('--no-metadata', '--diag-json', (Normalize-MoonBitMarkPath $textInput)) -WorkingDirectory $repoRoot
if ($diagNoMetadata.ExitCode -ne 0) {
    throw "diag-json conversion failed: $($diagNoMetadata.StdErr)"
}
$diagNoMetadataJson = $diagNoMetadata.StdOut.Trim() | ConvertFrom-Json
if (@($diagNoMetadataJson.metadata.PSObject.Properties).Count -ne 0) {
    throw '--no-metadata did not clear metadata in diag-json output.'
}
$detectJson = Invoke-NativeCommand -FilePath $binary -Arguments @('--detect-only', '--diag-json', (Normalize-MoonBitMarkPath $textInput)) -WorkingDirectory $repoRoot
if ($detectJson.ExitCode -ne 0) {
    throw "detect-only conversion failed: $($detectJson.StdErr)"
}
$detectJsonObject = $detectJson.StdOut.Trim() | ConvertFrom-Json
if ($detectJsonObject.converter -ne 'text') {
    throw "Unexpected detect-only converter: $($detectJsonObject.converter)"
}

$dumpAst = Invoke-NativeCommand -FilePath $binary -Arguments @('--dump-ast', (Normalize-MoonBitMarkPath $htmlInput)) -WorkingDirectory $repoRoot
if ($dumpAst.ExitCode -ne 0) {
    throw "dump-ast conversion failed: $($dumpAst.StdErr)"
}
$dumpAstJson = $dumpAst.StdOut.Trim() | ConvertFrom-Json
if ($dumpAstJson.title -ne 'Smoke Title') {
    throw "Unexpected dump-ast title: $($dumpAstJson.title)"
}
if ($dumpAstJson.blocks.Count -lt 3) {
    throw "Unexpected dump-ast block count: $($dumpAstJson.blocks.Count)"
}
if ($dumpAstJson.blocks[0].type -ne 'paragraph' -or $dumpAstJson.blocks[0].inlines[0].content -ne 'Smoke Title') {
    throw '--dump-ast did not emit the expected title paragraph block.'
}
if ($dumpAstJson.blocks[1].type -ne 'heading' -or $dumpAstJson.blocks[1].level -ne 1) {
    throw '--dump-ast did not emit the expected heading block schema.'
}
if ($dumpAstJson.blocks[1].inlines[0].content -ne 'Heading') {
    throw "Unexpected dump-ast heading content: $($dumpAstJson.blocks[1].inlines[0].content)"
}
if ($dumpAstJson.blocks[2].type -ne 'paragraph' -or $dumpAstJson.blocks[2].inlines[0].content -ne 'Paragraph') {
    throw '--dump-ast did not emit the expected paragraph block schema.'
}

$outputRun = Invoke-NativeCommand -FilePath $binary -Arguments @('--debug', (Normalize-MoonBitMarkPath $textInput), (Normalize-MoonBitMarkPath $outputMarkdown)) -WorkingDirectory $repoRoot
if ($outputRun.ExitCode -ne 0) {
    throw "output-file conversion failed: $($outputRun.StdErr)"
}
if (-not (Test-Path $outputMarkdown)) {
    throw "Missing output markdown file: $outputMarkdown"
}
Assert-ContainsText -Text $outputRun.StdOut -Expected 'Converted:' -Context 'output-file status'
Assert-ContainsText -Text $outputRun.StdOut -Expected 'ConvertResult Debug Report' -Context '--debug output'

$assetRun = Invoke-NativeCommand -FilePath $binary -Arguments @('--asset-dir', (Normalize-MoonBitMarkPath $assetDir), (Normalize-MoonBitMarkPath $imageInput), (Normalize-MoonBitMarkPath $imageMarkdown)) -WorkingDirectory $repoRoot
if ($assetRun.ExitCode -ne 0) {
    throw "asset-dir conversion failed: $($assetRun.StdErr)"
}
if ((Get-ChildItem -File $assetDir | Measure-Object).Count -lt 1) {
    throw '--asset-dir did not emit any asset files.'
}

$ocrRun = Invoke-NativeCommand -FilePath $binary -Arguments @(
    '--ocr', 'force',
    '--ocr-lang', 'chi_sim',
    '--ocr-images',
    '--ocr-backend', 'mock',
    '--ocr-timeout', '2500',
    '--diag-json',
    (Normalize-MoonBitMarkPath $imageInput)
) -WorkingDirectory $repoRoot
if ($ocrRun.ExitCode -ne 0) {
    throw "OCR smoke conversion failed: $($ocrRun.StdErr)"
}
$ocrJson = $ocrRun.StdOut.Trim() | ConvertFrom-Json
if ($ocrJson.metadata.ocr_mode -ne 'force') {
    throw "Unexpected OCR mode: $($ocrJson.metadata.ocr_mode)"
}
if ($ocrJson.metadata.ocr_backend -ne 'mock') {
    throw "Unexpected OCR backend: $($ocrJson.metadata.ocr_backend)"
}
if ($ocrJson.metadata.ocr_lang -ne 'chi_sim') {
    throw "Unexpected OCR language: $($ocrJson.metadata.ocr_lang)"
}
if ($ocrJson.metadata.ocr_images -ne 'true') {
    throw '--ocr-images flag was not reflected in metadata.'
}
if ($ocrJson.metadata.ocr_timeout -ne '2500') {
    throw "Unexpected OCR timeout: $($ocrJson.metadata.ocr_timeout)"
}
if ($ocrJson.metadata.ocr_provider -ne 'mock') {
    throw "Unexpected OCR provider: $($ocrJson.metadata.ocr_provider)"
}

Write-Host 'CLI smoke checks passed.'

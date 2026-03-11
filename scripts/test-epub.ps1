# MoonBitMark - EPUB Format Test Script

param(
    [string]$InputFile = "$PSScriptRoot\..\tests\test_data\test.epub",
    [string]$OutputDir = "$PSScriptRoot\..\tests\output"
)

if (!(Test-Path $OutputDir)) {
    New-Item -ItemType Directory -Path $OutputDir | Out-Null
}

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  MoonBitMark EPUB Test" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

if (!(Test-Path $InputFile)) {
    Write-Host "ERROR: Input file not found: $InputFile" -ForegroundColor Red
    Write-Host "Please run scripts/create_test_epub.py first to create test EPUB files." -ForegroundColor Yellow
    exit 1
}

$outputFile = Join-Path $OutputDir "test.epub.md"
Write-Host "Input:  $InputFile" -ForegroundColor Gray
Write-Host "Output: $outputFile" -ForegroundColor Gray
Write-Host ""

$startTime = Get-Date

# Run moon directly
Write-Host "Running conversion..." -ForegroundColor Cyan
$result = & moon run "$PSScriptRoot\..\cmd\main" $InputFile $outputFile 2>&1

$duration = ((Get-Date) - $startTime).TotalSeconds

if (Test-Path $outputFile) {
    $lines = (Get-Content $outputFile | Measure-Object -Line).Lines
    $size = (Get-Item $outputFile).Length
    $content = Get-Content $outputFile -Raw
    
    Write-Host "✓ Conversion successful!" -ForegroundColor Green
    Write-Host "  Time: $([math]::Round($duration, 2))s" -ForegroundColor Green
    Write-Host "  Lines: $lines" -ForegroundColor Green
    Write-Host "  Size: $([math]::Round($size/1024, 2)) KB" -ForegroundColor Green
    Write-Host ""
    Write-Host "First 10 lines of output:" -ForegroundColor Cyan
    Write-Host "-------------------------" -ForegroundColor Cyan
    if ($lines -gt 0) {
        Get-Content $outputFile | Select-Object -First 10 | ForEach-Object {
            Write-Host "  $_" -ForegroundColor Gray
        }
        if ($lines -gt 10) {
            Write-Host "  ... (and $($lines - 10) more lines)" -ForegroundColor Gray
        }
    }
    
    # Check for expected content
    $hasTitle = $content -match "# Test EPUB for MoonBitMark"
    $hasChapter1 = $content -match "Chapter 1: Introduction"
    $hasChapter2 = $content -match "Chapter 2: Advanced Features"
    
    Write-Host ""
    Write-Host "Content validation:" -ForegroundColor Cyan
    Write-Host "  ✓ Title extracted: $hasTitle" -ForegroundColor $(if ($hasTitle) { "Green" } else { "Red" })
    Write-Host "  ✓ Chapter 1 found: $hasChapter1" -ForegroundColor $(if ($hasChapter1) { "Green" } else { "Red" })
    Write-Host "  ✓ Chapter 2 found: $hasChapter2" -ForegroundColor $(if ($hasChapter2) { "Green" } else { "Red" })
    
    if ($hasTitle -and $hasChapter1 -and $hasChapter2) {
        Write-Host ""
        Write-Host "✅ All tests passed!" -ForegroundColor Green
    } else {
        Write-Host ""
        Write-Host "⚠ Some content may not have been extracted correctly." -ForegroundColor Yellow
    }
    
    exit 0
} else {
    Write-Host "✗ Conversion failed!" -ForegroundColor Red
    if ($result) { 
        Write-Host "Error output:" -ForegroundColor Red
        Write-Host $result -ForegroundColor Red
    }
    exit 1
}
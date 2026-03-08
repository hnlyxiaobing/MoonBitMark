# MoonBitMark - Individual Format Test Script

param(
    [string]$Format = "all",
    [string]$InputDir = "$PSScriptRoot\..\tests\test_data",
    [string]$OutputDir = "$PSScriptRoot\..\tests\output"
)

if (!(Test-Path $OutputDir)) {
    New-Item -ItemType Directory -Path $OutputDir | Out-Null
}

function Test-Format {
    param([string]$Name, [string]$Input, [string]$Output)
    
    Write-Host "[$Name] Testing..." -ForegroundColor Cyan
    
    if (!(Test-Path $Input)) {
        Write-Host "  SKIP: Input file not found" -ForegroundColor Yellow
        return $false
    }
    
    $startTime = Get-Date
    $outputPath = Join-Path $OutputDir $Output
    
    # Run moon directly
    $result = & moon run "$PSScriptRoot\..\src\cmd\main" $Name $Input $outputPath 2>&1
    
    $duration = (Get-Date - $startTime).TotalSeconds
    
    if (Test-Path $outputPath) {
        $lines = (Get-Content $outputPath | Measure-Object -Line).Lines
        $size = (Get-Item $outputPath).Length
        Write-Host "  Output: $Output" -ForegroundColor Green
        Write-Host "  Time: $([math]::Round($duration, 2))s" -ForegroundColor Green
        Write-Host "  Lines: $lines" -ForegroundColor Green
        Write-Host "  Size: $([math]::Round($size/1024, 2)) KB" -ForegroundColor Green
        Write-Host "  Status: PASS" -ForegroundColor Green
        return $true
    } else {
        Write-Host "  Status: FAIL" -ForegroundColor Red
        if ($result) { Write-Host "  Error: $result" -ForegroundColor Red }
        return $false
    }
}

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  MoonBitMark Test Suite" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

$passed = 0
$total = 0

if ($Format -eq "all" -or $Format -eq "txt") {
    $total++
    if (Test-Format -Name "txt" -Input "$InputDir\test.txt" -Output "test.md") { $passed++ }
}

if ($Format -eq "all" -or $Format -eq "csv") {
    $total++
    if (Test-Format -Name "csv" -Input "$InputDir\test.csv" -Output "test.csv.md") { $passed++ }
}

if ($Format -eq "all" -or $Format -eq "json") {
    $total++
    if (Test-Format -Name "json" -Input "$InputDir\test.json" -Output "test.json.md") { $passed++ }
}

if ($Format -eq "all" -or $Format -eq "html") {
    $total++
    if (Test-Format -Name "html" -Input "$InputDir\test.html" -Output "test.html.md") { $passed++ }
    $total++
    if (Test-Format -Name "html" -Input "$InputDir\test_complex_table.html" -Output "test_complex_table.md") { $passed++ }
    $total++
    if (Test-Format -Name "html" -Input "$InputDir\test_unicode.html" -Output "test_unicode.md") { $passed++ }
}

if ($Format -eq "all" -or $Format -eq "pdf") {
    $total++
    if (Test-Path "$InputDir\test.pdf") {
        if (Test-Format -Name "pdf" -Input "$InputDir\test.pdf" -Output "test.pdf.md") { $passed++ }
    } else {
        Write-Host "[PDF] SKIP: test.pdf not found" -ForegroundColor Yellow
    }
}

if ($Format -eq "all" -or $Format -eq "docx") {
    $total++
    if (Test-Path "$InputDir\test.docx") {
        if (Test-Format -Name "docx" -Input "$InputDir\test.docx" -Output "test.docx.md") { $passed++ }
    } else {
        Write-Host "[DOCX] SKIP: test.docx not found (requires libzip/expat)" -ForegroundColor Yellow
    }
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Results: $passed / $total passed" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

# MoonBitMark - Comprehensive Test Script

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  MoonBitMark v0.3.0 - Test Suite" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

$testDir = "D:\MySoftware\MoonBitMark\tests\test_data"
$outputDir = "D:\MySoftware\MoonBitMark\tests\output"
$reportDir = "D:\MySoftware\MoonBitMark\tests\test_report"

if (!(Test-Path $outputDir)) {
    New-Item -ItemType Directory -Path $outputDir | Out-Null
}

$totalTests = 0
$passedTests = 0
$failedTests = 0
$results = @()

function Run-Test {
    param(
        [string]$Name,
        [string]$InputFile,
        [string]$OutputFile,
        [string]$Description
    )
    
    $script:totalTests = $script:totalTests + 1
    Write-Host "[$($script:totalTests)] $Name" -ForegroundColor Yellow
    Write-Host "    Desc: $Description" -ForegroundColor Gray
    Write-Host "    Input: $InputFile" -ForegroundColor Gray
    
    $inputPath = Join-Path $testDir $InputFile
    if (!(Test-Path $inputPath)) {
        Write-Host "    Status: SKIP (file not found)" -ForegroundColor Red
        $script:failedTests = $script:failedTests + 1
        $results += [PSCustomObject]@{Name=$Name; Status="Skipped"; Reason="File not found"}
        return
    }
    
    $startTime = Get-Date
    $outputPath = Join-Path $outputDir $OutputFile
    
    & "D:\MySoftware\MoonBitMark\scripts\run-msvc.bat" run cmd/main $inputPath $outputPath 2>&1 | Out-Null
    
    $endTime = Get-Date
    $duration = ($endTime - $startTime).TotalSeconds
    
    if (Test-Path $outputPath) {
        $content = Get-Content $outputPath -Raw
        $lineCount = ($content -split "`n").Count
        $fileSize = (Get-Item $outputPath).Length
        
        Write-Host "    Output: $OutputFile" -ForegroundColor Green
        Write-Host "    Time: $([math]::Round($duration, 2))s" -ForegroundColor Green
        Write-Host "    Lines: $lineCount" -ForegroundColor Green
        Write-Host "    Size: $([math]::Round($fileSize/1024, 2)) KB" -ForegroundColor Green
        Write-Host "    Status: PASS" -ForegroundColor Green
        
        $script:passedTests = $script:passedTests + 1
        $results += [PSCustomObject]@{Name=$Name; Status="Passed"; Duration=[math]::Round($duration,2); Lines=$lineCount; Size=[math]::Round($fileSize/1024,2)}
    } else {
        Write-Host "    Status: FAIL" -ForegroundColor Red
        $script:failedTests = $script:failedTests + 1
        $results += [PSCustomObject]@{Name=$Name; Status="Failed"; Reason="Output not created"}
    }
    Write-Host ""
}

Write-Host "Running conversion tests..." -ForegroundColor Cyan
Write-Host ""

Run-Test -Name "TXT" -InputFile "test.txt" -OutputFile "test.md" -Description "Plain text conversion"
Run-Test -Name "CSV" -InputFile "test.csv" -OutputFile "test.csv.md" -Description "CSV to Markdown table"
Run-Test -Name "JSON" -InputFile "test.json" -OutputFile "test.json.md" -Description "JSON to code block"
Run-Test -Name "HTML-Basic" -InputFile "test.html" -OutputFile "test.html.md" -Description "HTML elements conversion"
Run-Test -Name "HTML-Table" -InputFile "test_complex_table.html" -OutputFile "test_complex_table.md" -Description "Complex table conversion"
Run-Test -Name "HTML-Unicode" -InputFile "test_unicode.html" -OutputFile "test_unicode.md" -Description "Unicode/multilingual"

if (Test-Path (Join-Path $testDir "test.pdf")) {
    Run-Test -Name "PDF" -InputFile "test.pdf" -OutputFile "test.pdf.md" -Description "PDF conversion"
} else {
    Write-Host "[PDF] SKIP - test file not found" -ForegroundColor Gray
    Write-Host ""
}

if (Test-Path (Join-Path $testDir "test.docx")) {
    Run-Test -Name "DOCX" -InputFile "test.docx" -OutputFile "test.docx.md" -Description "Word document conversion"
} else {
    Write-Host "[DOCX] SKIP - test file not found (requires libzip/expat)" -ForegroundColor Gray
    Write-Host ""
}

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Test Complete!" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Summary:" -ForegroundColor Cyan
Write-Host "  Total: $totalTests" -ForegroundColor White
Write-Host "  Passed: $passedTests" -ForegroundColor Green
Write-Host "  Failed: $failedTests" -ForegroundColor Red
Write-Host ""

Write-Host "Generating report..." -ForegroundColor Cyan
$reportTime = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
$reportFile = Join-Path $reportDir "test_report_$(Get-Date -Format 'yyyyMMdd_HHmmss').md"

if (!(Test-Path $reportDir)) {
    New-Item -ItemType Directory -Path $reportDir | Out-Null
}

$passRate = if ($totalTests -gt 0) { [math]::Round($passedTests / $totalTests * 100, 2) } else { 0 }

$reportContent = @"
# MoonBitMark Test Report

**Test Time:** $reportTime  
**Version:** v0.3.0  
**Environment:** Windows

---

## Test Statistics

| Metric | Value |
|--------|-------|
| Total Tests | $totalTests |
| Passed | $passedTests |
| Failed | $failedTests |
| Pass Rate | $passRate% |

---

## Detailed Results

| Test Name | Status | Time (s) | Lines | Size (KB) |
|-----------|--------|----------|-------|-----------|
"@

foreach ($r in $results) {
    $status = if ($r.Status -eq "Passed") { "PASS" } elseif ($r.Status -eq "Failed") { "FAIL" } else { "SKIP" }
    $dur = if ($r.Duration) { $r.Duration } else { "-" }
    $ln = if ($r.Lines) { $r.Lines } else { "-" }
    $sz = if ($r.Size) { $r.Size } else { "-" }
    $reportContent += "| $($r.Name) | $status | $dur | $ln | $sz |`n"
}

$reportContent += @"

---

## Output Files

Location: $outputDir

---

## Test Coverage

- TXT - Plain text conversion
- CSV - Table conversion
- JSON - Code block conversion
- HTML - Full HTML element support
- HTML Complex Table - Table structure preservation
- HTML Unicode - Multilingual character support
- PDF - Requires test file
- DOCX - Requires test file + libzip/expat

---

**Generated:** $reportTime
"@

$reportContent | Out-File -FilePath $reportFile -Encoding UTF8

Write-Host "Report saved: $reportFile" -ForegroundColor Green
Write-Host ""
Write-Host "Output dir: $outputDir" -ForegroundColor Cyan

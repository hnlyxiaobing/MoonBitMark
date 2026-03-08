# MoonBitMark PDF 测试脚本

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  MoonBitMark v0.2.0 PDF 测试" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

$testDir = "D:\MySoftware\MoonBitMark\tests\test_data"
$outputDir = "D:\MySoftware\MoonBitMark\tests\output"

# 创建输出目录
if (!(Test-Path $outputDir)) {
    New-Item -ItemType Directory -Path $outputDir | Out-Null
}

# 测试文件列表
$testFiles = @(
    @{Name="test.pdf"; Type="英文技术文档"},
    @{Name="test_unicode.pdf"; Type="Unicode 测试"},
    @{Name="test_japanese.pdf"; Type="日文文档"}
)

Write-Host "测试文件：" -NoNewline
Write-Host "$($testFiles.Count) 个" -ForegroundColor Green
Write-Host ""

# 逐个测试
foreach ($test in $testFiles) {
    $inputFile = Join-Path $testDir $test.Name
    $outputFile = Join-Path $outputDir ($test.Name -replace '\.pdf$', '.md')
    
    Write-Host "[$($test.Type)]" -ForegroundColor Yellow
    Write-Host "  输入：$($test.Name)"
    
    if (!(Test-Path $inputFile)) {
        Write-Host "  状态：跳过 (文件不存在)" -ForegroundColor Red
        continue
    }
    
    # 计时转换
    $startTime = Get-Date
    & "D:\MySoftware\MoonBitMark\run-msvc.bat" run cmd/main $inputFile $outputFile 2>&1 | Out-Null
    $endTime = Get-Date
    
    $duration = ($endTime - $startTime).TotalSeconds
    
    if (Test-Path $outputFile) {
        $lineCount = (Get-Content $outputFile | Measure-Object -Line).Lines
        $fileSize = (Get-Item $outputFile).Length
        
        Write-Host "  输出：$(Split-Path $outputFile -Leaf)" -ForegroundColor Green
        Write-Host "  耗时：$([math]::Round($duration, 2)) 秒" -ForegroundColor Green
        Write-Host "  行数：$lineCount 行" -ForegroundColor Green
        Write-Host "  大小：$([math]::Round($fileSize/1024, 2)) KB" -ForegroundColor Green
    } else {
        Write-Host "  状态：失败" -ForegroundColor Red
    }
    
    Write-Host ""
}

# 显示测试结果
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  测试完成！" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "输出目录：$outputDir" -ForegroundColor Cyan
Write-Host ""

# 显示第一个测试文件的前 20 行
$firstOutput = Join-Path $outputDir "test.md"
if (Test-Path $firstOutput) {
    Write-Host "输出示例（前 20 行）：" -ForegroundColor Cyan
    Write-Host "----------------------------------------" -ForegroundColor Gray
    Get-Content $firstOutput | Select-Object -First 20 | ForEach-Object {
        Write-Host $_ -ForegroundColor Gray
    }
    Write-Host "----------------------------------------" -ForegroundColor Gray
}

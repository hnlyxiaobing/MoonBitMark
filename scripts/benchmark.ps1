param(
    [Parameter(Mandatory = $true)]
    [string]$InputPath,
    [int]$Iterations = 5,
    [string]$BinaryPath = "_build/native/release/build/cmd/main/main.exe",
    [string]$OutputPath = "$env:TEMP\moonbitmark-benchmark-output.md"
)

$ErrorActionPreference = "Stop"

if (-not (Test-Path $BinaryPath)) {
    throw "Binary not found: $BinaryPath. Build it first with scripts/build.bat."
}
if (-not (Test-Path $InputPath)) {
    throw "Input not found: $InputPath"
}
if ($Iterations -le 0) {
    throw "Iterations must be > 0"
}

$durations = @()

for ($i = 1; $i -le $Iterations; $i++) {
    if (Test-Path $OutputPath) {
        Remove-Item $OutputPath -Force
    }

    $elapsed = Measure-Command {
        & $BinaryPath $InputPath $OutputPath | Out-Null
    }

    $durations += [Math]::Round($elapsed.TotalMilliseconds, 2)
}

$avg = [Math]::Round((($durations | Measure-Object -Average).Average), 2)
$min = [Math]::Round((($durations | Measure-Object -Minimum).Minimum), 2)
$max = [Math]::Round((($durations | Measure-Object -Maximum).Maximum), 2)

Write-Host "MoonBitMark Benchmark"
Write-Host "Input      : $InputPath"
Write-Host "Binary     : $BinaryPath"
Write-Host "Iterations : $Iterations"
Write-Host "Durations  : $($durations -join ', ') ms"
Write-Host "Average    : $avg ms"
Write-Host "Min / Max  : $min ms / $max ms"

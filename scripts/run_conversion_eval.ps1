param(
  [string]$BenchmarkRoot = "",
  [string]$Runner = "",
  [string]$PythonExe = "python",
  [switch]$CompareBaselines,
  [switch]$RefreshReferences,
  [switch]$AllowSkipped,
  [switch]$AllowStale
)

$repoRoot = Split-Path -Parent $PSScriptRoot
$scriptPath = Join-Path $repoRoot "tests\conversion_eval\scripts\run_eval.py"

$args = @(
  $scriptPath,
  "all"
)

if ($BenchmarkRoot -ne "") {
  $args += @("--benchmark-root", $BenchmarkRoot)
}

if ($Runner -ne "") {
  $args += @("--runner", $Runner)
}

if ($CompareBaselines) {
  $args += "--compare-baselines"
}

if ($RefreshReferences) {
  $args += "--refresh-references"
}

if ($AllowSkipped) {
  $args += "--allow-skipped"
}

if ($AllowStale) {
  $args += "--allow-stale"
}

$env:PYTHONUTF8 = "1"
$env:PYTHONIOENCODING = "utf-8"
& $PythonExe @args
# Propagate the harness exit code: without an explicit exit, powershell -File
# swallows $LASTEXITCODE and the CI gate can never go red.
exit $LASTEXITCODE

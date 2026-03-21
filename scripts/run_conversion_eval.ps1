param(
  [string]$BenchmarkRoot = "D:\MySoftware\MoonBit\python-text-extraction-libs-benchmarks",
  [string]$Runner = "",
  [switch]$CompareBaselines,
  [switch]$RefreshReferences
)

$repoRoot = Split-Path -Parent $PSScriptRoot
$scriptPath = Join-Path $repoRoot "tests\conversion_eval\scripts\run_eval.py"

$args = @(
  $scriptPath,
  "all",
  "--benchmark-root",
  $BenchmarkRoot
)

if ($Runner -ne "") {
  $args += @("--runner", $Runner)
}

if ($CompareBaselines) {
  $args += "--compare-baselines"
}

if ($RefreshReferences) {
  $args += "--refresh-references"
}

python @args

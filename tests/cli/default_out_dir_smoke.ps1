$ErrorActionPreference = 'Stop'

. "$PSScriptRoot\..\TestHelpers.ps1"

$repoRoot = Get-MoonBitMarkRepoRoot -ScriptPath $PSScriptRoot
$binary = Get-OrBuild-MoonBitMarkBinary -RepoRoot $repoRoot -ExecutableName 'main.exe'
$tempRoot = Join-Path $repoRoot '_build\test-tmp\default-out-dir'
if (Test-Path $tempRoot) {
    Remove-Item -Recurse -Force $tempRoot
}
New-Item -ItemType Directory -Force -Path $tempRoot | Out-Null

$htmlInput = Join-Path $tempRoot 'sample.html'
@(
    '<html><head><title>Out Dir Smoke</title></head>',
    '<body><h1>Heading</h1><p>Paragraph</p></body></html>'
) | Set-Content -Path $htmlInput -Encoding utf8
$htmlArg = Normalize-MoonBitMarkPath $htmlInput

# Fake homes so the real user config never leaks into the assertions.
$fakeHomeConfig = Join-Path $tempRoot 'home-with-config'
$fakeHomeEmpty = Join-Path $tempRoot 'home-empty'
$defaultOut = Join-Path $tempRoot 'default-out'
$envOut = Join-Path $tempRoot 'env-out'
$explicitOut = Join-Path $tempRoot 'explicit.md'
$nestedOut = Join-Path $tempRoot 'nested\a\b\c'
New-Item -ItemType Directory -Force -Path (Join-Path $fakeHomeConfig '.moonbitmark') | Out-Null
New-Item -ItemType Directory -Force -Path $fakeHomeEmpty | Out-Null
$configJson = [ordered]@{ out_dir = (Normalize-MoonBitMarkPath $defaultOut) } | ConvertTo-Json
[System.IO.File]::WriteAllText(
    (Join-Path $fakeHomeConfig '.moonbitmark\config.json'),
    $configJson,
    (New-Object System.Text.UTF8Encoding($false))
)

# 1. Config-file tier: fake USERPROFILE supplies out_dir; empty env falls through.
$configRun = Invoke-NativeCommand -FilePath $binary -Arguments @($htmlArg) `
    -WorkingDirectory $repoRoot `
    -Environment @{ USERPROFILE = $fakeHomeConfig; HOME = $fakeHomeConfig; MOONBITMARK_OUT_DIR = '' }
if ($configRun.ExitCode -ne 0) {
    throw "config-tier conversion failed: $($configRun.StdErr)"
}
$configOutFile = Join-Path $defaultOut 'sample.md'
if (-not (Test-Path $configOutFile)) {
    throw "config tier did not write $configOutFile. StdOut: $($configRun.StdOut)"
}
Assert-ContainsText -Text (Get-Content $configOutFile -Raw) -Expected 'Heading' -Context 'config-tier markdown'
Assert-ContainsText -Text $configRun.StdOut -Expected 'Converted:' -Context 'config-tier status line'

# 2. Env var tier wins over the config file.
$envRun = Invoke-NativeCommand -FilePath $binary -Arguments @($htmlArg) `
    -WorkingDirectory $repoRoot `
    -Environment @{ USERPROFILE = $fakeHomeConfig; HOME = $fakeHomeConfig; MOONBITMARK_OUT_DIR = (Normalize-MoonBitMarkPath $envOut) }
if ($envRun.ExitCode -ne 0) {
    throw "env-tier conversion failed: $($envRun.StdErr)"
}
$envOutFile = Join-Path $envOut 'sample.md'
if (-not (Test-Path $envOutFile)) {
    throw "env tier did not write $envOutFile. StdOut: $($envRun.StdOut)"
}

# 3. Explicit output file wins over both tiers.
$explicitRun = Invoke-NativeCommand -FilePath $binary -Arguments @($htmlArg, (Normalize-MoonBitMarkPath $explicitOut)) `
    -WorkingDirectory $repoRoot `
    -Environment @{ USERPROFILE = $fakeHomeConfig; HOME = $fakeHomeConfig; MOONBITMARK_OUT_DIR = (Normalize-MoonBitMarkPath $envOut) }
if ($explicitRun.ExitCode -ne 0) {
    throw "explicit-output conversion failed: $($explicitRun.StdErr)"
}
if (-not (Test-Path $explicitOut)) {
    throw "explicit output was not written: $explicitOut"
}

# 4. Missing output directories are created automatically.
$nestedRun = Invoke-NativeCommand -FilePath $binary -Arguments @($htmlArg) `
    -WorkingDirectory $repoRoot `
    -Environment @{ USERPROFILE = $fakeHomeEmpty; HOME = $fakeHomeEmpty; MOONBITMARK_OUT_DIR = (Normalize-MoonBitMarkPath $nestedOut) }
if ($nestedRun.ExitCode -ne 0) {
    throw "nested-dir conversion failed: $($nestedRun.StdErr)"
}
$nestedOutFile = Join-Path $nestedOut 'sample.md'
if (-not (Test-Path $nestedOutFile)) {
    throw "nested default output dir was not created: $nestedOutFile"
}

# 5. Debug modes stay on stdout even with a default output directory.
$diagRun = Invoke-NativeCommand -FilePath $binary -Arguments @('--diag-json', $htmlArg) `
    -WorkingDirectory $repoRoot `
    -Environment @{ USERPROFILE = $fakeHomeConfig; HOME = $fakeHomeConfig; MOONBITMARK_OUT_DIR = (Normalize-MoonBitMarkPath $envOut) }
if ($diagRun.ExitCode -ne 0) {
    throw "diag-json conversion failed: $($diagRun.StdErr)"
}
$null = $diagRun.StdOut.Trim() | ConvertFrom-Json

# 6. Without env or config the historical stdout behavior is unchanged.
$stdoutRoot = Join-Path $tempRoot 'stdout-out'
$stdoutRun = Invoke-NativeCommand -FilePath $binary -Arguments @($htmlArg) `
    -WorkingDirectory $repoRoot `
    -Environment @{ USERPROFILE = $fakeHomeEmpty; HOME = $fakeHomeEmpty; MOONBITMARK_OUT_DIR = '' }
if ($stdoutRun.ExitCode -ne 0) {
    throw "stdout conversion failed: $($stdoutRun.StdErr)"
}
Assert-ContainsText -Text $stdoutRun.StdOut -Expected 'Heading' -Context 'stdout markdown'
if (Test-Path $stdoutRoot) {
    throw "stdout run unexpectedly created files under $stdoutRoot"
}

Write-Host 'Default output directory smoke checks passed.'

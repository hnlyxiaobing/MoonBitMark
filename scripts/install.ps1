<#
.SYNOPSIS
Install MoonBitMark as a `moonbitmark` command on the user PATH.

.DESCRIPTION
- Builds the release binary when missing (or when -Rebuild is given)
- Copies it to <InstallRoot>\bin\moonbitmark.exe
- Copies scripts\ocr and scripts\pdf under <InstallRoot>\scripts so the
  OCR/PDF bridges resolve from the installed location
- Adds the bin directory to the user PATH (new terminals pick it up)
- Sets MOONBITMARK_OCR_BRIDGE / MOONBITMARK_PDF_BRIDGE to the installed
  bridge scripts so bare-name PATH invocation always finds them
- Optionally writes <USERPROFILE>\.moonbitmark\config.json with out_dir
  when -OutDir is given

.PARAMETER OutDir
Default markdown output directory written into the user config file.

.PARAMETER InstallRoot
Override the install root (default: %LOCALAPPDATA%\MoonBitMark).

.PARAMETER Rebuild
Force a release rebuild even when a binary already exists.

.PARAMETER SkipPath
Do not modify the user PATH environment variable.
#>
[CmdletBinding()]
param(
    [string]$OutDir = '',
    [string]$InstallRoot = (Join-Path $env:LOCALAPPDATA 'MoonBitMark'),
    [switch]$Rebuild,
    [switch]$SkipPath
)

$ErrorActionPreference = 'Stop'

. (Join-Path $PSScriptRoot '..\tests\TestHelpers.ps1')

$repoRoot = Get-MoonBitMarkRepoRoot -ScriptPath $PSScriptRoot

if ($Rebuild) {
    Write-Host "Building release binary..."
    Push-Location $repoRoot
    try {
        moon build --target native --release | Out-Host
    } finally {
        Pop-Location
    }
    $binary = Get-MoonBitMarkBuildArtifact -RepoRoot $repoRoot -ExecutableName 'main.exe'
    if ([string]::IsNullOrEmpty($binary)) {
        throw 'Release build did not produce main.exe.'
    }
} else {
    $binary = Get-OrBuild-MoonBitMarkBinary -RepoRoot $repoRoot -ExecutableName 'main.exe'
}

$binDir = Join-Path $InstallRoot 'bin'
$bridgeRoot = Join-Path $InstallRoot 'scripts'
New-Item -ItemType Directory -Force -Path $binDir | Out-Null
New-Item -ItemType Directory -Force -Path $bridgeRoot | Out-Null

$installedExe = Join-Path $binDir 'moonbitmark.exe'
Copy-Item -Path $binary -Destination $installedExe -Force
Write-Host "Installed CLI: $installedExe"

foreach ($bridge in @('ocr', 'pdf')) {
    $source = Join-Path $repoRoot "scripts\$bridge"
    if (-not (Test-Path $source)) {
        throw "Missing bridge script directory: $source"
    }
    $destination = Join-Path $bridgeRoot $bridge
    if (Test-Path $destination) {
        Remove-Item -Recurse -Force $destination
    }
    Copy-Item -Path $source -Destination $bridgeRoot -Recurse -Force
    Write-Host "Installed $bridge bridge: $destination"
}

$ocrBridge = Join-Path $bridgeRoot 'ocr\bridge.py'
$pdfBridge = Join-Path $bridgeRoot 'pdf\bridge.py'
[Environment]::SetEnvironmentVariable('MOONBITMARK_OCR_BRIDGE', $ocrBridge, 'User')
[Environment]::SetEnvironmentVariable('MOONBITMARK_PDF_BRIDGE', $pdfBridge, 'User')
Write-Host 'Set user env MOONBITMARK_OCR_BRIDGE / MOONBITMARK_PDF_BRIDGE.'

if (-not $SkipPath) {
    $userPath = [Environment]::GetEnvironmentVariable('Path', 'User')
    if ($null -eq $userPath) {
        $userPath = ''
    }
    $entries = @($userPath -split ';' | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
    $binFull = [System.IO.Path]::GetFullPath($binDir).TrimEnd('\')
    $alreadyPresent = $entries | Where-Object { $_.TrimEnd('\') -ieq $binFull }
    if ($alreadyPresent) {
        Write-Host "User PATH already contains: $binFull"
    } else {
        $newPath = (@($entries) + $binFull) -join ';'
        [Environment]::SetEnvironmentVariable('Path', $newPath, 'User')
        Write-Host "Added to user PATH: $binFull"
    }
}

if (-not [string]::IsNullOrWhiteSpace($OutDir)) {
    $configDir = Join-Path $env:USERPROFILE '.moonbitmark'
    New-Item -ItemType Directory -Force -Path $configDir | Out-Null
    $configPath = Join-Path $configDir 'config.json'
    $fullOutDir = [System.IO.Path]::GetFullPath($OutDir).Replace('\', '/')
    $configJson = [ordered]@{ out_dir = $fullOutDir } | ConvertTo-Json
    [System.IO.File]::WriteAllText(
        $configPath,
        $configJson,
        (New-Object System.Text.UTF8Encoding($false))
    )
    Write-Host "Wrote default output directory to $configPath : $fullOutDir"
}

Write-Host ''
Write-Host 'Install complete.'
Write-Host 'Open a NEW terminal so PATH and environment changes take effect, then run:'
Write-Host '    moonbitmark --help'

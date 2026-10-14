<#
.SYNOPSIS
Remove a MoonBitMark installation created by scripts/install.ps1.

.DESCRIPTION
- Removes the bin directory from the user PATH
- Unsets MOONBITMARK_OCR_BRIDGE / MOONBITMARK_PDF_BRIDGE when they point
  inside the install root
- Deletes the install root directory
- Optionally deletes <USERPROFILE>\.moonbitmark with -RemoveConfig

.PARAMETER InstallRoot
Override the install root (default: %LOCALAPPDATA%\MoonBitMark).

.PARAMETER RemoveConfig
Also delete <USERPROFILE>\.moonbitmark (config.json).
#>
[CmdletBinding()]
param(
    [string]$InstallRoot = (Join-Path $env:LOCALAPPDATA 'MoonBitMark'),
    [switch]$RemoveConfig
)

$ErrorActionPreference = 'Stop'

$installFull = $InstallRoot.TrimEnd('\')

$userPath = [Environment]::GetEnvironmentVariable('Path', 'User')
if ($null -ne $userPath) {
    $entries = @($userPath -split ';' | Where-Object {
        -not [string]::IsNullOrWhiteSpace($_) -and $_.TrimEnd('\') -ine $installFull
    })
    $newPath = $entries -join ';'
    if ($newPath -ne $userPath) {
        [Environment]::SetEnvironmentVariable('Path', $newPath, 'User')
        Write-Host "Removed from user PATH (if present): $installFull"
    }
}

foreach ($name in @('MOONBITMARK_OCR_BRIDGE', 'MOONBITMARK_PDF_BRIDGE')) {
    $value = [Environment]::GetEnvironmentVariable($name, 'User')
    if (-not [string]::IsNullOrWhiteSpace($value)) {
        $insideInstall = $value.Replace('/', '\').StartsWith("$installFull\", [System.StringComparison]::OrdinalIgnoreCase)
        if ($insideInstall) {
            [Environment]::SetEnvironmentVariable($name, $null, 'User')
            Write-Host "Unset user env $name (was: $value)"
        } else {
            Write-Host "Kept $name because it points outside the install root: $value"
        }
    }
}

if (Test-Path $installFull) {
    Remove-Item -Recurse -Force $installFull
    Write-Host "Deleted install root: $installFull"
} else {
    Write-Host "Install root not found (already removed?): $installFull"
}

if ($RemoveConfig) {
    $configDir = Join-Path $env:USERPROFILE '.moonbitmark'
    if (Test-Path $configDir) {
        Remove-Item -Recurse -Force $configDir
        Write-Host "Deleted config directory: $configDir"
    }
}

Write-Host ''
Write-Host 'Uninstall complete. Open a NEW terminal for PATH changes to take effect.'

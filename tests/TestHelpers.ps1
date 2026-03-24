$ErrorActionPreference = 'Stop'

function Get-MoonBitMarkRepoRoot {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ScriptPath
    )

    $current = (Resolve-Path $ScriptPath).Path
    while ($null -ne $current) {
        if (Test-Path (Join-Path $current 'moon.mod.json')) {
            return $current
        }
        $parent = Split-Path -Parent $current
        if ($parent -eq $current) {
            break
        }
        $current = $parent
    }

    throw "Unable to locate repo root from: $ScriptPath"
}

function Ensure-MoonBitMarkReleaseBinary {
    param(
        [Parameter(Mandatory = $true)]
        [string]$RepoRoot,

        [Parameter(Mandatory = $true)]
        [string]$BinaryPath
    )

    if (-not (Test-Path $BinaryPath)) {
        Push-Location $RepoRoot
        try {
            moon build --target native --release | Out-Host
        } finally {
            Pop-Location
        }
    }

    if (-not (Test-Path $BinaryPath)) {
        throw "Missing release binary: $BinaryPath"
    }
}

function Invoke-NativeCommand {
    param(
        [Parameter(Mandatory = $true)]
        [string]$FilePath,

        [string[]]$Arguments = @(),

        [string]$WorkingDirectory = (Get-Location).Path,

        [hashtable]$Environment = @{},

        [string]$StdIn = ''
    )

    $psi = [System.Diagnostics.ProcessStartInfo]::new($FilePath)
    if ($Arguments.Count -gt 0) {
        $escapedArguments = foreach ($argument in $Arguments) {
            '"' + $argument.Replace('"', '\"') + '"'
        }
        $psi.Arguments = [string]::Join(' ', $escapedArguments)
    }
    $psi.WorkingDirectory = $WorkingDirectory
    $psi.RedirectStandardInput = $true
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    $psi.UseShellExecute = $false

    foreach ($entry in [System.Environment]::GetEnvironmentVariables().GetEnumerator()) {
        $psi.Environment[$entry.Key] = [string]$entry.Value
    }
    foreach ($key in $Environment.Keys) {
        $psi.Environment[$key] = [string]$Environment[$key]
    }

    $process = [System.Diagnostics.Process]::Start($psi)
    try {
        if ($StdIn -ne '') {
            $process.StandardInput.WriteLine($StdIn)
        }
        $process.StandardInput.Close()
        $stdout = $process.StandardOutput.ReadToEnd()
        $stderr = $process.StandardError.ReadToEnd()
        $process.WaitForExit()
        $exitCode = $process.ExitCode
    } finally {
        $process.Dispose()
    }

    return [pscustomobject]@{
        ExitCode = $exitCode
        StdOut   = $stdout
        StdErr   = $stderr
    }
}

function Normalize-MoonBitMarkPath {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    return $Path.Replace('\', '/')
}

function Assert-ContainsText {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Text,

        [Parameter(Mandatory = $true)]
        [string]$Expected,

        [Parameter(Mandatory = $true)]
        [string]$Context
    )

    if (-not $Text.Contains($Expected)) {
        throw "$Context did not contain expected text: $Expected`nActual:`n$Text"
    }
}

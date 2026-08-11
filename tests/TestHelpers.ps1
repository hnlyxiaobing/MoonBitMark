$ErrorActionPreference = 'Stop'

function Get-MoonBitMarkRepoRoot {
    param(
        [Parameter(Mandatory = $false)]
        [AllowEmptyString()]
        [string]$ScriptPath = ""
    )

    if ([string]::IsNullOrEmpty($ScriptPath)) {
        $current = (Get-Location).Path
    } else {
        $current = (Resolve-Path $ScriptPath).Path
    }
    while ($null -ne $current -and $current -ne '') {
        # MoonBit projects use either moon.mod.json (legacy) or moon.mod (current).
        if (Test-Path (Join-Path $current 'moon.mod.json')) {
            return $current
        }
        if (Test-Path (Join-Path $current 'moon.mod')) {
            return $current
        }
        $parent = Split-Path -Parent $current
        # Split-Path -Parent returns an empty string at a drive root (e.g. 'D:\'
        # -> ''), which must be treated as "no more parents" instead of letting
        # the loop continue with an empty path and failing later on Join-Path.
        if ([string]::IsNullOrEmpty($parent) -or $parent -eq $current) {
            break
        }
        $current = $parent
    }

    throw "Unable to locate repo root from: $ScriptPath"
}

function Get-MoonBitMarkBuildArtifact {
    param(
        [Parameter(Mandatory = $true)]
        [string]$RepoRoot,

        [Parameter(Mandatory = $true)]
        [string]$ExecutableName
    )

    $releaseBuildRoot = Join-Path $RepoRoot '_build\native\release\build'
    if (-not (Test-Path $releaseBuildRoot)) {
        return $null
    }
    # MoonBit places release artifacts under
    # _build/native/release/build/<module>/cmd/<package>/<name>.exe. The module
    # prefix (e.g. moonbitlang/moonbitmark) is toolchain-dependent, so locate
    # the executable by name under the cmd/ tree instead of hard-coding it.
    $match = Get-ChildItem -Path $releaseBuildRoot -Recurse -File -Filter $ExecutableName -ErrorAction SilentlyContinue |
        Where-Object { $_.FullName -match '\\cmd\\[^\\/]+\\[^\\/]+\.exe$' } |
        Select-Object -First 1
    if ($null -eq $match) {
        return $null
    }
    return $match.FullName
}

function Get-OrBuild-MoonBitMarkBinary {
    param(
        [Parameter(Mandatory = $true)]
        [string]$RepoRoot,

        [Parameter(Mandatory = $true)]
        [string]$ExecutableName
    )

    $found = Get-MoonBitMarkBuildArtifact -RepoRoot $RepoRoot -ExecutableName $ExecutableName
    if (-not [string]::IsNullOrEmpty($found)) {
        return $found
    }

    Push-Location $RepoRoot
    try {
        moon build --target native --release | Out-Host
    } finally {
        Pop-Location
    }

    $found = Get-MoonBitMarkBuildArtifact -RepoRoot $RepoRoot -ExecutableName $ExecutableName
    if ([string]::IsNullOrEmpty($found)) {
        throw "Unable to locate release binary '$ExecutableName' under $(Join-Path $RepoRoot '_build\native\release\build')"
    }
    return $found
}

function Ensure-MoonBitMarkReleaseBinary {
    param(
        [Parameter(Mandatory = $true)]
        [string]$RepoRoot,

        [Parameter(Mandatory = $true)]
        [string]$BinaryPath
    )

    $executableName = Split-Path -Leaf $BinaryPath
    $resolved = Get-MoonBitMarkBuildArtifact -RepoRoot $RepoRoot -ExecutableName $executableName
    $needsBuild = [string]::IsNullOrEmpty($resolved)
    if (-not $needsBuild) {
        $binaryTime = (Get-Item $resolved).LastWriteTimeUtc
        $sourceRoots = @(
            (Join-Path $RepoRoot 'src'),
            (Join-Path $RepoRoot 'cmd'),
            (Join-Path $RepoRoot 'scripts')
        )
        $latestSource = Get-ChildItem -Path $sourceRoots -Recurse -File -ErrorAction SilentlyContinue |
            Sort-Object LastWriteTimeUtc -Descending |
            Select-Object -First 1
        if ($null -ne $latestSource -and $latestSource.LastWriteTimeUtc -gt $binaryTime) {
            $needsBuild = $true
        }
    }

    if ($needsBuild) {
        Push-Location $RepoRoot
        try {
            moon build --target native --release | Out-Host
        } finally {
            Pop-Location
        }
    }

    $resolved = Get-MoonBitMarkBuildArtifact -RepoRoot $RepoRoot -ExecutableName $executableName
    if ([string]::IsNullOrEmpty($resolved)) {
        throw "Missing release binary: $BinaryPath"
    }
    return $resolved
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

function Start-NativeProcess {
    param(
        [Parameter(Mandatory = $true)]
        [string]$FilePath,

        [string[]]$Arguments = @(),

        [string]$WorkingDirectory = (Get-Location).Path,

        [hashtable]$Environment = @{}
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
    $process.StandardInput.Close()
    return $process
}

function Stop-NativeProcess {
    param(
        [Parameter(Mandatory = $true)]
        [System.Diagnostics.Process]$Process,

        [int]$WaitMs = 5000
    )

    try {
        if (-not $Process.HasExited) {
            $Process.Kill()
            [void]$Process.WaitForExit($WaitMs)
        }
        $stdout = $Process.StandardOutput.ReadToEnd()
        $stderr = $Process.StandardError.ReadToEnd()
        if (-not $Process.HasExited) {
            $Process.WaitForExit()
        }
        $exitCode = $Process.ExitCode
    } finally {
        $Process.Dispose()
    }

    return [pscustomobject]@{
        ExitCode = $exitCode
        StdOut   = $stdout
        StdErr   = $stderr
    }
}

function Get-FreeTcpPort {
    $listener = [System.Net.Sockets.TcpListener]::new([System.Net.IPAddress]::Loopback, 0)
    $listener.Start()
    try {
        return ([System.Net.IPEndPoint]$listener.LocalEndpoint).Port
    } finally {
        $listener.Stop()
    }
}

function Invoke-HttpRequest {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Method,

        [Parameter(Mandatory = $true)]
        [string]$Url,

        [string]$Body = '',

        [string]$ContentType = 'application/json; charset=utf-8',

        [hashtable]$Headers = @{},

        [int]$TimeoutMs = 5000
    )

    $request = [System.Net.HttpWebRequest]::Create($Url)
    $request.Method = $Method
    $request.Timeout = $TimeoutMs
    $request.ReadWriteTimeout = $TimeoutMs
    $request.AutomaticDecompression = [System.Net.DecompressionMethods]::GZip -bor [System.Net.DecompressionMethods]::Deflate

    foreach ($key in $Headers.Keys) {
        if ($key -ieq 'Content-Type') {
            $request.ContentType = [string]$Headers[$key]
        } else {
            $request.Headers[$key] = [string]$Headers[$key]
        }
    }

    if ($Body -ne '') {
        $bytes = [System.Text.Encoding]::UTF8.GetBytes($Body)
        if (-not $request.ContentType) {
            $request.ContentType = $ContentType
        }
        $request.ContentLength = $bytes.Length
        $stream = $request.GetRequestStream()
        try {
            $stream.Write($bytes, 0, $bytes.Length)
        } finally {
            $stream.Dispose()
        }
    }

    try {
        $response = [System.Net.HttpWebResponse]$request.GetResponse()
    } catch [System.Net.WebException] {
        if ($null -eq $_.Exception.Response) {
            throw
        }
        $response = [System.Net.HttpWebResponse]$_.Exception.Response
    }

    try {
        $stream = $response.GetResponseStream()
        if ($null -eq $stream) {
            $bodyText = ''
        } else {
            $reader = [System.IO.StreamReader]::new($stream)
            try {
                $bodyText = $reader.ReadToEnd()
            } finally {
                $reader.Dispose()
            }
        }

        return [pscustomobject]@{
            StatusCode = [int]$response.StatusCode
            StatusText = $response.StatusDescription
            Body       = $bodyText
            Headers    = $response.Headers
        }
    } finally {
        $response.Dispose()
    }
}

function Wait-HttpHealthz {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Url,

        [System.Diagnostics.Process]$Process,

        [int]$TimeoutSeconds = 15
    )

    $deadline = (Get-Date).AddSeconds($TimeoutSeconds)
    while ((Get-Date) -lt $deadline) {
        if ($null -ne $Process -and $Process.HasExited) {
            throw "Process exited before health check became ready."
        }
        try {
            $response = Invoke-HttpRequest -Method 'GET' -Url $Url -ContentType 'application/json; charset=utf-8' -TimeoutMs 1000
            if ($response.StatusCode -eq 200) {
                return $response
            }
        } catch {
        }
        Start-Sleep -Milliseconds 200
    }

    throw "Timed out waiting for HTTP endpoint: $Url"
}

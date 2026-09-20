[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$MessageFile,

    [string]$Remote = "origin",

    [string]$Branch,

    [switch]$DryRun,

    [switch]$NoPush
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

# Native git commands write progress and cosmetic notices to stderr even when
# they succeed, for example:
#     warning: LF will be replaced by CRLF in src/foo.mbt
# Under $ErrorActionPreference = "Stop" those stderr records are promoted to
# terminating errors, which used to abort this script between `git add -A` and
# `git commit`. Native calls therefore run with a local "Continue" preference
# and are judged by $LASTEXITCODE only.
function Invoke-Git {
    param(
        [Parameter(Mandatory = $true)]
        [string[]]$GitArgs
    )

    $previousPreference = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    try {
        $output = & git @GitArgs 2>&1
        $exitCode = $LASTEXITCODE
    }
    finally {
        $ErrorActionPreference = $previousPreference
    }

    if ($exitCode -ne 0) {
        $rendered = $GitArgs -join " "
        throw "git $rendered failed (exit $exitCode).`n$output"
    }
    return $output
}

if (-not (Test-Path -LiteralPath $MessageFile)) {
    throw "Commit message file not found: $MessageFile"
}

$repoRoot = (Invoke-Git -GitArgs @("rev-parse", "--show-toplevel") | Out-String).Trim()
if (-not $repoRoot) {
    throw "Unable to determine git repository root."
}

Push-Location $repoRoot
try {
    $preStatus = (Invoke-Git -GitArgs @("status", "--short", "--untracked-files=all") | Out-String).Trim()
    if (-not $preStatus) {
        throw "Working tree is clean. Nothing to commit."
    }

    $targetBranch = $Branch
    if (-not $targetBranch) {
        $targetBranch = (Invoke-Git -GitArgs @("rev-parse", "--abbrev-ref", "HEAD") | Out-String).Trim()
    }
    if (-not $targetBranch -or $targetBranch -eq "HEAD") {
        throw "Detached HEAD is not supported by this helper. Specify -Branch explicitly."
    }

    $message = Get-Content -LiteralPath $MessageFile -Raw

    if ($DryRun) {
        $previewFiles = (Invoke-Git -GitArgs @("status", "--short", "--untracked-files=all") | Out-String).Trim()

        Write-Host "Repository: $repoRoot"
        Write-Host "Branch: $targetBranch"
        Write-Host "Remote: $Remote"
        Write-Host "Files:"
        Write-Host $previewFiles
        Write-Host ""
        Write-Host "Commit message:"
        Write-Host $message
        return
    }

    Invoke-Git -GitArgs @("add", "-A") | Out-Null

    $stagedFiles = (Invoke-Git -GitArgs @("diff", "--cached", "--name-status", "--find-renames") | Out-String).Trim()
    if (-not $stagedFiles) {
        throw "No staged changes were found after git add -A."
    }

    $commitOutput = Invoke-Git -GitArgs @("commit", "-F", $MessageFile)
    $commitSha = (Invoke-Git -GitArgs @("rev-parse", "--short", "HEAD") | Out-String).Trim()

    if ($NoPush) {
        Write-Host $commitOutput
        Write-Host "Committed $commitSha on $targetBranch without pushing."
        return
    }

    $pushOutput = Invoke-Git -GitArgs @("push", $Remote, $targetBranch)
    Write-Host $commitOutput
    Write-Host $pushOutput
    Write-Host "Committed and pushed $commitSha to $Remote/$targetBranch."
}
finally {
    Pop-Location
}

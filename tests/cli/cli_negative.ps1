$ErrorActionPreference = 'Stop'

. "$PSScriptRoot\..\TestHelpers.ps1"

$repoRoot = Get-MoonBitMarkRepoRoot -ScriptPath $PSScriptRoot
$binary = Join-Path $repoRoot '_build\native\release\build\cmd\main\main.exe'
Ensure-MoonBitMarkReleaseBinary -RepoRoot $repoRoot -BinaryPath $binary

$tempRoot = Join-Path $repoRoot '_build\test-tmp\cli-negative'
New-Item -ItemType Directory -Force -Path $tempRoot | Out-Null

$textInput = Join-Path $tempRoot 'sample.txt'
$unsupportedInput = Join-Path $tempRoot 'sample.bin'
$missingInput = Join-Path $tempRoot 'missing.txt'

'negative test input' | Set-Content -Path $textInput -Encoding utf8
'unsupported extension' | Set-Content -Path $unsupportedInput -Encoding utf8

function Invoke-ExpectFailure {
    param(
        [Parameter(Mandatory = $true)]
        [string[]]$Arguments,

        [Parameter(Mandatory = $true)]
        [string]$Keyword
    )

    $result = Invoke-NativeCommand -FilePath $binary -Arguments $Arguments -WorkingDirectory $repoRoot
    if ($result.ExitCode -eq 0) {
        throw "Command unexpectedly succeeded: $($Arguments -join ' ')"
    }
    $combined = ($result.StdOut + "`n" + $result.StdErr)
    Assert-ContainsText -Text $combined -Expected $Keyword -Context ($Arguments -join ' ')
}

Invoke-ExpectFailure -Arguments @('--unknown-option') -Keyword 'Unknown option'
Invoke-ExpectFailure -Arguments @('--ocr') -Keyword 'Missing mode after --ocr'
Invoke-ExpectFailure -Arguments @('--detect-only', '--dump-ast', (Normalize-MoonBitMarkPath $textInput)) -Keyword '--detect-only cannot be combined with --dump-ast'
Invoke-ExpectFailure -Arguments @('--frontmatter') -Keyword 'Missing input path or URL'
Invoke-ExpectFailure -Arguments @((Normalize-MoonBitMarkPath $missingInput)) -Keyword 'cannot find the file specified'
Invoke-ExpectFailure -Arguments @((Normalize-MoonBitMarkPath $unsupportedInput)) -Keyword 'Unsupported input'
Invoke-ExpectFailure -Arguments @((Normalize-MoonBitMarkPath $textInput), (Normalize-MoonBitMarkPath $textInput)) -Keyword 'Output path conflicts with input path'

Write-Host 'CLI negative checks passed.'

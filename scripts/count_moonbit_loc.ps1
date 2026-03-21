param(
    [string]$Root = ".",
    [switch]$IncludeMbti,
    [switch]$AsJson,
    [string[]]$ExcludeDirs = @(".git", ".mooncakes", "_build", ".codex", ".gitworktree")
)

$ErrorActionPreference = "Stop"

function Get-LineCount {
    param(
        [string]$Path
    )

    (Get-Content -Path $Path).Count
}

function Get-RelativePath {
    param(
        [string]$Base,
        [string]$Path
    )

    $baseUri = [System.Uri]((Resolve-Path $Base).Path + [System.IO.Path]::DirectorySeparatorChar)
    $pathUri = [System.Uri](Resolve-Path $Path).Path
    $baseUri.MakeRelativeUri($pathUri).ToString().Replace('/', [System.IO.Path]::DirectorySeparatorChar)
}

function Should-ExcludePath {
    param(
        [string]$Path,
        [string[]]$Names
    )

    $segments = $Path -split '[\\/]'
    foreach ($name in $Names) {
        if ($segments -contains $name) {
            return $true
        }
    }
    $false
}

$resolvedRoot = (Resolve-Path $Root).Path
$mbtFiles = @(
    Get-ChildItem -Path $resolvedRoot -Recurse -File -Include *.mbt |
        Where-Object { -not (Should-ExcludePath -Path $_.FullName -Names $ExcludeDirs) }
)
$mbtiFiles = @(
    Get-ChildItem -Path $resolvedRoot -Recurse -File -Include *.mbti |
        Where-Object { -not (Should-ExcludePath -Path $_.FullName -Names $ExcludeDirs) }
)

$sourceLines = 0
$testLines = 0
$sourceFiles = 0
$testFiles = 0

foreach ($file in $mbtFiles) {
    $lineCount = Get-LineCount -Path $file.FullName
    if ($file.Name -match '(_test|_wbtest)\.mbt$') {
        $testLines += $lineCount
        $testFiles += 1
    } else {
        $sourceLines += $lineCount
        $sourceFiles += 1
    }
}

$mbtiLines = 0
$mbtiCount = 0
if ($IncludeMbti) {
    foreach ($file in $mbtiFiles) {
        $mbtiLines += Get-LineCount -Path $file.FullName
        $mbtiCount += 1
    }
}

$result = [ordered]@{
    root = $resolvedRoot
    excluded_dirs = $ExcludeDirs
    source_files = $sourceFiles
    source_lines = $sourceLines
    test_files = $testFiles
    test_lines = $testLines
    total_mbt_files = $sourceFiles + $testFiles
    total_mbt_lines = $sourceLines + $testLines
}

if ($IncludeMbti) {
    $result["mbti_files"] = $mbtiCount
    $result["mbti_lines"] = $mbtiLines
}

if ($AsJson) {
    $result | ConvertTo-Json
    exit 0
}

Write-Output "MoonBit LOC"
Write-Output "root           : $($result.root)"
Write-Output "source files   : $($result.source_files)"
Write-Output "source lines   : $($result.source_lines)"
Write-Output "test files     : $($result.test_files)"
Write-Output "test lines     : $($result.test_lines)"
Write-Output "total .mbt     : $($result.total_mbt_files) files, $($result.total_mbt_lines) lines"

if ($IncludeMbti) {
    Write-Output ".mbti          : $($result.mbti_files) files, $($result.mbti_lines) lines"
}

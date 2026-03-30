# MoonBitMark 链接脚本 - 手动生成 main.exe
$ErrorActionPreference = "Stop"

$msvc = "C:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools\VC\Tools\MSVC\14.44.35207\bin\Hostx64\x64"
$winsdk = "C:\Program Files (x86)\Windows Kits\10\bin\10.0.22621.0\x64"
$ucrt_lib = "C:\Program Files (x86)\Windows Kits\10\lib\10.0.22621.0\ucrt\x64"
$um_lib = "C:\Program Files (x86)\Windows Kits\10\lib\10.0.22621.0\um\x64"
$msvc_lib = "C:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools\VC\lib\x64"
$buildDir = "D:\MySoftware\MoonBitMark\_build\native\release\build"
$outExe = "$buildDir\cmd\main\main.exe"

Write-Host "[1] Setting environment..."
$env:PATH = "$msvc;$winsdk;$env:PATH"
$env:LIB = "$msvc_lib;$um_lib;$ucrt_lib"

# Verify tools
Write-Host "[2] Verifying tools..."
& "$msvc\cl.exe" /? | Select-Object -First 1
& "$msvc\link.exe" /? | Select-Object -First 1

# Find all .obj files (exclude mooncakes stub/platform-specific ones we'll handle via libs)
Write-Host "[3] Collecting object files..."
$objFiles = @()

# Main program and runtime
Get-ChildItem "$buildDir\*.obj" | ForEach-Object { $objFiles += $_.FullName }
Write-Host "  Core objs: $($objFiles.Count)"

# Async package objs
Get-ChildItem "$buildDir\.mooncakes" -Filter "*.obj" -Recurse | ForEach-Object { $objFiles += $_.FullName }
Write-Host "  Async objs: $($objFiles.Count) total"

# Find all .lib files from mooncakes
$libFiles = @()
Get-ChildItem "$buildDir\.mooncakes" -Filter "*.lib" -Recurse | ForEach-Object { $libFiles += $_.FullName }
Write-Host "  Async libs: $($libFiles.Count)"

Write-Host "[4] Linking main.exe..."
$argFile = "$env:TEMP\link_args_$PID.txt"

# Write response file
@"
/NOLOGO
/SUBSYSTEM:CONSOLE
/OUT:"$outExe"
/LIBPATH:"$buildDir"
/LIBPATH:"$msvc_lib"
/LIBPATH:"$ucrt_lib"
/LIBPATH:"$um_lib"
$($objFiles | ForEach-Object { "`"$_`"" })
$($libFiles | ForEach-Object { "`"$_`"" })
kernel32.lib
user32.lib
msvcrt.lib
ws2_32.lib
winhttp.lib
crypt32.lib
bcrypt.lib
"@ | Out-File -FilePath $argFile -Encoding ASCII

Write-Host "[5] Calling linker..."
$objArg = ($objFiles | ForEach-Object { "`"$_`"" }) -join " "
$libArg = ($libFiles | ForEach-Object { "`"$_`"" }) -join " "

$cmd = "link.exe /NOLOGO /SUBSYSTEM:CONSOLE /OUT:`"$outExe`" /LIBPATH:`"$buildDir`" /LIBPATH:`"$msvc_lib`" /LIBPATH:`"$ucrt_lib`" /LIBPATH:`"$um_lib`" $objArg $libArg kernel32.lib user32.lib msvcrt.lib ws2_32.lib winhttp.lib crypt32.lib bcrypt.lib"
Write-Host "Command: $cmd"

Invoke-Expression $cmd
$exitCode = $LASTEXITCODE
Remove-Item $argFile -ErrorAction SilentlyContinue

if ($exitCode -eq 0) {
    Write-Host ""
    Write-Host "[OK] main.exe created: $outExe"
    Write-Host "Size: $((Get-Item $outExe).Length / 1MB) MB"
} else {
    Write-Host "[ERROR] Link failed with exit code: $exitCode"
}
exit $exitCode

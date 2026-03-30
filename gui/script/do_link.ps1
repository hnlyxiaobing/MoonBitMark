# MoonBitMark MSVC Link Script
$MSVC_BIN = "C:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools\VC\Tools\MSVC\14.44.35207\bin\Hostx64\x64"
$MSVC_LIB = "C:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools\VC\Tools\MSVC\14.44.35207\lib\x64"
$UCRT_LIB = "C:\Program Files (x86)\Windows Kits\10\lib\10.0.26100.0\ucrt\x64"
$UM_LIB   = "C:\Program Files (x86)\Windows Kits\10\lib\10.0.26100.0\um\x64"
$BUILD_DIR = "D:\MySoftware\MoonBitMark\_build\native\release\build"

$env:PATH = "$MSVC_BIN;$env:PATH"
$env:LIB = "$MSVC_LIB;$UCRT_LIB;$UM_LIB;$BUILD_DIR"

Write-Host "MSVC_BIN: $MSVC_BIN"
Write-Host "BUILD_DIR: $BUILD_DIR"

# 收集 main 相关的 obj 文件（排除 demo 和 mcp-server）
$objs = Get-ChildItem -Path $BUILD_DIR -Filter "*.obj" -Recurse |
    Where-Object { $_.FullName -notmatch "[\\/]cmd[\\/]demo" -and $_.FullName -notmatch "[\\/]cmd[\\/]mcp-server" }

Write-Host "Found $($objs.Count) .obj files"

# 收集 .lib 文件
$libs = Get-ChildItem -Path $BUILD_DIR -Filter "*.lib" -Recurse

Write-Host "Found $($libs.Count) .lib files"

# 构建链接命令
$link_exe = Join-Path $MSVC_BIN "link.exe"
$out_exe  = Join-Path $BUILD_DIR "cmd\main\MoonBitMark.exe"

$args = @(
    "/NOLOGO",
    "/SUBSYSTEM:CONSOLE",
    "/OUT:$out_exe",
    "/LIBPATH:$MSVC_LIB",
    "/LIBPATH:$UCRT_LIB",
    "/LIBPATH:$UM_LIB",
    "/LIBPATH:$BUILD_DIR"
)

# 添加 obj 文件
foreach ($obj in $objs) {
    $args += $obj.FullName
}

# 添加 lib 文件
foreach ($lib in $libs) {
    $args += $lib.FullName
}

# 添加系统库
$args += @(
    "kernel32.lib", "user32.lib", "msvcrt.lib",
    "ws2_32.lib", "winhttp.lib", "crypt32.lib",
    "bcrypt.lib", "advapi32.lib"
)

Write-Host "Running link..."
Write-Host "Output: $out_exe"

# 执行链接
$process = Start-Process -FilePath $link_exe -ArgumentList $args -NoNewWindow -Wait -PassThru -RedirectStandardOutput "D:\MySoftware\MoonBitMark\_build\link_stdout.txt" -RedirectStandardError "D:\MySoftware\MoonBitMark\_build\link_stderr.txt"

Write-Host "Exit code: $($process.ExitCode)"

if (Test-Path "D:\MySoftware\MoonBitMark\_build\link_stdout.txt") {
    Write-Host "=== STDOUT ==="
    Get-Content "D:\MySoftware\MoonBitMark\_build\link_stdout.txt"
}
if (Test-Path "D:\MySoftware\MoonBitMark\_build\link_stderr.txt") {
    Write-Host "=== STDERR ==="
    Get-Content "D:\MySoftware\MoonBitMark\_build\link_stderr.txt"
}

if ($process.ExitCode -eq 0 -and (Test-Path $out_exe)) {
    $final_exe = Join-Path $BUILD_DIR "cmd\main\main.exe"
    Copy-Item $out_exe $final_exe -Force
    $size = (Get-Item $final_exe).Length / 1MB
    Write-Host "SUCCESS! main.exe ($([math]::Round($size, 1)) MB)"
} else {
    Write-Host "FAILED!"
    exit 1
}

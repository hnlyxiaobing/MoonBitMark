@echo off
setlocal enabledelayedexpansion

set "MSVC_BIN=C:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools\VC\Tools\MSVC\14.44.35207\bin\Hostx64\x64"
set "MSVC_LIB=C:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools\VC\Tools\MSVC\14.44.35207\lib\x64"
set "UCRT_LIB=C:\Program Files (x86)\Windows Kits\10\lib\10.0.26100.0\ucrt\x64"
set "UM_LIB=C:\Program Files (x86)\Windows Kits\10\lib\10.0.26100.0\um\x64"
set "BUILD_DIR=D:\MySoftware\MoonBitMark\_build\native\release\build"
set "OUTPUT_DIR=D:\MySoftware\MoonBitMark\_build\output"

echo === Starting MSVC Link ===
echo MSVC_BIN: %MSVC_BIN%

REM 检查 link.exe
if not exist "%MSVC_BIN%\link.exe" (
    echo ERROR: link.exe not found!
    exit /b 1
)

REM 收集 main 相关的 obj 文件
echo Collecting main-related .obj files...

set OBJS=
for /r "%BUILD_DIR%" %%f in (*.obj) do (
    echo %%f | findstr /i "\cmd\demo" >nul
    if errorlevel 1 (
        echo %%f | findstr /i "\cmd\mcp-server" >nul
        if errorlevel 1 (
            set "OBJS=!OBJS! "%%f""
        )
    )
)

echo Found !OBJS!

REM 收集 lib 文件
set LIBS=
for /r "%BUILD_DIR%" %%f in (*.lib) do (
    echo %%f | findstr /i "\cmd\demo" >nul
    if errorlevel 1 (
        echo %%f | findstr /i "\cmd\mcp-server" >nul
        if errorlevel 1 (
            set "LIBS=!LIBS! "%%f""
        )
    )
)

REM 创建输出目录
if not exist "%OUTPUT_DIR%" mkdir "%OUTPUT_DIR%"

REM 执行链接 - 使用单独的输出目录避免文件名冲突
echo.
echo Running link.exe...

"%MSVC_BIN%\link.exe" /NOLOGO /SUBSYSTEM:CONSOLE /OUT:"%OUTPUT_DIR%\MoonBitMark.exe" /LIBPATH:"%MSVC_LIB%" /LIBPATH:"%UCRT_LIB%" /LIBPATH:"%UM_LIB%" /LIBPATH:"%BUILD_DIR%" %OBJS% %LIBS% kernel32.lib user32.lib msvcrt.lib ws2_32.lib winhttp.lib crypt32.lib bcrypt.lib advapi32.lib

if errorlevel 1 (
    echo.
    echo LINK FAILED!
    exit /b 1
)

REM 复制到 main.exe
copy /Y "%OUTPUT_DIR%\MoonBitMark.exe" "%BUILD_DIR%\cmd\main\main.exe"

echo.
echo SUCCESS!
dir "%BUILD_DIR%\cmd\main\main.exe"

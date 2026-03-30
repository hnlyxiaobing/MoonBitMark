@echo off
REM MoonBitMark Link Script - 手动链接生成 main.exe
setlocal enabledelayedexpansion

REM === MSVC 环境 ===
set "MSVC_DIR=C:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools"
set "MSVC_BIN=%MSVC_DIR%\VC\Tools\MSVC\14.44.35207\bin\Hostx64\x64"
set "UCRT_LIB=C:\Program Files (x86)\Windows Kits\10\lib\10.0.22621.0\ucrt\x64"
set "UM_LIB=C:\Program Files (x86)\Windows Kits\10\lib\10.0.22621.0\um\x64"
set "MSVC_LIB=%MSVC_DIR%\VC\lib\x64"

set "PATH=%MSVC_BIN%;%PATH%"
set "LIB=%MSVC_LIB%;%UCRT_LIB%;%UM_LIB%;%LIB%"

cd /d "%~dp0.."
set "BUILD_DIR=%CD%\_build\native\release\build"
set "OUT_EXE=%BUILD_DIR%\cmd\main\main.exe"

echo [1] Verifying linker...
link.exe /?

echo.
echo [2] Collecting files...
set "OBJ_LIST="
set "LIB_LIST="

REM Collect top-level .obj
for /r "%BUILD_DIR%\*.obj" %%f in (*.obj) do (
    echo   OBJ: %%f
    set "OBJ_LIST=!OBJ_LIST! "%%f""
)

REM Collect mooncakes .obj
for /r "%BUILD_DIR%\.mooncakes" %%f in (*.obj) do (
    echo   ASYNC OBJ: %%f
    set "OBJ_LIST=!OBJ_LIST! "%%f""
)

REM Collect mooncakes .lib
for /r "%BUILD_DIR%\.mooncakes" %%f in (*.lib) do (
    echo   ASYNC LIB: %%f
    set "LIB_LIST=!LIB_LIST! "%%f""
)

echo.
echo [3] Linking main.exe...
link.exe /NOLOGO /SUBSYSTEM:CONSOLE /OUT:"%OUT_EXE%" ^
    /LIBPATH:"%BUILD_DIR%" ^
    /LIBPATH:"%MSVC_LIB%" ^
    /LIBPATH:"%UCRT_LIB%" ^
    /LIBPATH:"%UM_LIB%" ^
    %OBJ_LIST% %LIB_LIST% ^
    kernel32.lib user32.lib msvcrt.lib ws2_32.lib winhttp.lib crypt32.lib bcrypt.lib advapi32.lib

if errorlevel 1 (
    echo.
    echo [ERROR] Linking failed!
    exit /b 1
)

echo.
echo [OK] main.exe created: %OUT_EXE%
dir "%OUT_EXE%"

endlocal

@echo off
REM MoonBitMark Build Script - Fixed PATH version
REM Usage: build-msvc.bat [--debug]

setlocal

REM === Fix MSVC PATH ===
set "MSVC_DIR=C:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools\VC"
set "MSVC_VERSION=14.44.35207"
set "MSVC_TOOLS=%MSVC_DIR%\Tools\MSVC\%MSVC_VERSION%\bin\Hostx64\x64"
set "WINSDK_DIR=C:\Program Files (x86)\Windows Kits\10\bin\10.0.22621.0\x64"

REM Add to PATH
set "PATH=%MSVC_TOOLS%;%WINSDK_DIR%;%PATH%"

REM Set LIB and INCLUDE for MSVC
set "LIB=%MSVC_DIR%\lib\x64;%WINSDK_DIR%\lib\10.0.22621.0\um\x64;%WINSDK_DIR%\lib\10.0.22621.0\ucrt\x64;%LIB%"
set "INCLUDE=%MSVC_DIR%\include;%INCLUDE%"

echo [INFO] MSVC tools path: %MSVC_TOOLS%
where cl.exe
where link.exe

cd /d "%~dp0.."

if "%1"=="--debug" (
    echo Building debug version...
    moon build --target native
) else (
    echo Building release version...
    moon build --target native --release
)

if %ERRORLEVEL% EQU 0 (
    echo.
    echo Build successful!
    echo Output: _build\native\release\build\cmd\main\main.exe
) else (
    echo.
    echo Build failed. Please check the errors above.
)

endlocal

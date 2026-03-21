@echo off
REM MoonBitMark Build Script
REM Usage: build.bat [--debug]

setlocal

call "C:\PROGRA~2\Microsoft Visual Studio\2022\BuildTools\VC\Auxiliary\Build\vcvars64.bat" >nul 2>&1
if errorlevel 1 (
    echo Failed to load MSVC build environment.
    exit /b 1
)

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
) else (
    echo.
    echo Build failed. Please check the errors above.
)

endlocal

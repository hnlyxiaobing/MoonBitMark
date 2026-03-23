@echo off
REM MoonBitMark Test Script
REM Usage: test.bat [--update]

setlocal

if "%MOONBITMARK_VCVARS64%"=="" (
    set "MOONBITMARK_VCVARS64=C:\PROGRA~2\Microsoft Visual Studio\2022\BuildTools\VC\Auxiliary\Build\vcvars64.bat"
)

call "%MOONBITMARK_VCVARS64%" >nul 2>&1
if errorlevel 1 (
    echo Failed to load MSVC build environment from "%MOONBITMARK_VCVARS64%".
    exit /b 1
)

cd /d "%~dp0.."

if "%1"=="--update" (
    echo Running tests with snapshot update...
    moon test --update
) else (
    echo Running tests...
    moon test
)

endlocal

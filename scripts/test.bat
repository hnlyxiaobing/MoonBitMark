@echo off
REM MoonBitMark Test Script
REM Usage: test.bat [--update]

setlocal

call "C:\PROGRA~2\Microsoft Visual Studio\2022\BuildTools\VC\Auxiliary\Build\vcvars64.bat" >nul 2>&1
if errorlevel 1 (
    echo Failed to load MSVC build environment.
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

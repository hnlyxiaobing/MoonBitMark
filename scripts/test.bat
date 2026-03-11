@echo off
REM MoonBitMark Test Script
REM Usage: test.bat [--update]

setlocal

REM Set MSVC environment
call "C:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools\VC\Auxiliary\Build\vcvars64.bat" >nul 2>&1

cd /d "%~dp0.."

if "%1"=="--update" (
    echo Running tests with snapshot update...
    moon test --update
) else (
    echo Running tests...
    moon test
)

endlocal

@echo off
REM MoonBitMark Test Script
REM Usage: test.bat [--update]

setlocal
set "USER_VCPKG_ROOT=%VCPKG_ROOT%"
set "USER_VCPKG_TRIPLET=%VCPKG_TRIPLET%"

call "C:\PROGRA~2\Microsoft Visual Studio\2022\BuildTools\VC\Auxiliary\Build\vcvars64.bat" >nul 2>&1
if errorlevel 1 (
    echo Failed to load MSVC build environment.
    exit /b 1
)

if not "%USER_VCPKG_ROOT%"=="" set "VCPKG_ROOT=%USER_VCPKG_ROOT%"
if not "%USER_VCPKG_TRIPLET%"=="" set "VCPKG_TRIPLET=%USER_VCPKG_TRIPLET%"

if "%VCPKG_ROOT%"=="" (
    echo VCPKG_ROOT is not set.
    echo Example: set VCPKG_ROOT=C:\vcpkg
    exit /b 1
)

if "%VCPKG_TRIPLET%"=="" (
    set "VCPKG_TRIPLET=x64-windows"
)

set "VCPKG_INCLUDE=%VCPKG_ROOT%\installed\%VCPKG_TRIPLET%\include"
set "VCPKG_LIB=%VCPKG_ROOT%\installed\%VCPKG_TRIPLET%\lib"

if not exist "%VCPKG_LIB%\zip.lib" (
    echo Missing zip.lib under %VCPKG_LIB%
    exit /b 1
)
if not exist "%VCPKG_LIB%\libexpat.lib" (
    echo Missing libexpat.lib under %VCPKG_LIB%
    exit /b 1
)

set "INCLUDE=%VCPKG_INCLUDE%;%INCLUDE%"
set "LIB=%VCPKG_LIB%;%LIB%"

cd /d "%~dp0.."

if "%1"=="--update" (
    echo Running tests with snapshot update...
    moon test --update
) else (
    echo Running tests...
    moon test
)

endlocal

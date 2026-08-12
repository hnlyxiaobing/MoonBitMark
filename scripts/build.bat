@echo off
REM MoonBitMark Build Script
REM Usage: build.bat [--debug]
REM
REM Requires MSVC (cl.exe). The vcvars64.bat environment script is located by:
REM   1. MOONBITMARK_VCVARS64 environment variable (explicit override)
REM   2. vswhere (latest installation with the C++ workload)
REM   3. common install paths (VS 2022 / VS 18, BuildTools..Enterprise)
REM
REM NOTE: %ProgramFiles(x86)% contains parentheses, which break cmd code
REM blocks when expanded inside them; delayed expansion (!VAR!) avoids that.

setlocal EnableDelayedExpansion

set "VCVARS64=%MOONBITMARK_VCVARS64%"
set "PF64=%ProgramFiles%"
set "PF86=%ProgramFiles(x86)%"
set "VSWHERE=%PF86%\Microsoft Visual Studio\Installer\vswhere.exe"

if not defined VCVARS64 (
    if exist "!VSWHERE!" (
        for /f "usebackq delims=" %%i in (`"!VSWHERE!" -latest -products * -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath`) do (
            if exist "%%i\VC\Auxiliary\Build\vcvars64.bat" set "VCVARS64=%%i\VC\Auxiliary\Build\vcvars64.bat"
        )
    )
)

if not defined VCVARS64 (
    for %%R in ("!PF64!" "!PF86!") do (
        for %%V in (2022 18) do (
            for %%E in (BuildTools Community Professional Enterprise) do (
                if not defined VCVARS64 (
                    if exist "%%~R\Microsoft Visual Studio\%%V\%%E\VC\Auxiliary\Build\vcvars64.bat" (
                        set "VCVARS64=%%~R\Microsoft Visual Studio\%%V\%%E\VC\Auxiliary\Build\vcvars64.bat"
                    )
                )
            )
        )
    )
)

if not defined VCVARS64 (
    echo ERROR: Could not locate vcvars64.bat ^(MSVC build environment^).
    echo.
    echo Install the Visual Studio Build Tools with the "Desktop development
    echo with C++" workload from:
    echo     https://visualstudio.microsoft.com/downloads/
    echo or point MOONBITMARK_VCVARS64 at an existing vcvars64.bat, e.g.:
    echo     set MOONBITMARK_VCVARS64=C:\path\to\VC\Auxiliary\Build\vcvars64.bat
    exit /b 1
)

if not exist "!VCVARS64!" (
    echo ERROR: vcvars64.bat not found:
    echo     !VCVARS64!
    echo Fix MOONBITMARK_VCVARS64 or unset it to use auto-detection.
    exit /b 1
)

call "!VCVARS64!" >nul 2>&1
if errorlevel 1 (
    echo ERROR: Failed to load the MSVC build environment from:
    echo     !VCVARS64!
    exit /b 1
)

where cl.exe >nul 2>&1
if errorlevel 1 (
    echo ERROR: cl.exe is not on PATH after loading:
    echo     !VCVARS64!
    echo The MSVC C++ toolchain appears to be missing. Install the Visual
    echo Studio Build Tools with the "Desktop development with C++" workload:
    echo     https://visualstudio.microsoft.com/downloads/
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

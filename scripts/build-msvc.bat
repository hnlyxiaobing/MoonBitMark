@echo off
echo Building MoonBitMark with MSVC...
call "C:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools\VC\Auxiliary\Build\vcvars64.bat" >nul 2>&1
cd /d %~dp0
moon clean
moon build --target native
if %ERRORLEVEL% EQU 0 (
    echo.
    echo ✓ Build successful!
) else (
    echo.
    echo ✗ Build failed. Please check the errors above.
)

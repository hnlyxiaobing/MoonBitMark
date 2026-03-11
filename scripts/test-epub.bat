@echo off
echo Running EPUB test...
echo.

REM Check if test EPUB file exists
if not exist "%~dp0..\tests\test_data\test.epub" (
    echo ERROR: test.epub not found.
    echo Please run scripts/create_test_epub.py first to create test EPUB files.
    pause
    exit /b 1
)

REM Run the conversion
echo Converting test.epub to Markdown...
moon run "%~dp0..\cmd\main" "%~dp0..\tests\test_data\test.epub" "%~dp0..\tests\output\test.epub.md"

if %ERRORLEVEL% equ 0 (
    echo.
    echo Conversion successful!
    echo Output saved to: %~dp0..\tests\output\test.epub.md
    echo.
    echo First 10 lines of output:
    echo -------------------------
    if exist "%~dp0..\tests\output\test.epub.md" (
        setlocal enabledelayedexpansion
        set /a count=0
        for /f "tokens=*" %%i in (%~dp0..\tests\output\test.epub.md) do (
            echo   %%i
            set /a count+=1
            if !count! equ 10 goto :show_count
        )
        :show_count
        if !count! equ 10 (
            echo   ... (more lines follow)
        )
    )
) else (
    echo.
    echo Conversion failed with error code: %ERRORLEVEL%
)

pause
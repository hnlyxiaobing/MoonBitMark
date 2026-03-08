@echo off
REM MoonBitMark - DOCX Test Runner (Release build)

set VS_PATH=C:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools
set MSVC_VERSION=14.44.35207
set WINDOWS_SDK=10.0.26100.0

set INCLUDE=%VS_PATH%\VC\Tools\MSVC\%MSVC_VERSION%\include;%VS_PATH%\VC\Tools\MSVC\%MSVC_VERSION%\atlmfc\include;%VS_PATH%\VC\Auxiliary\VS\include;C:\Program Files (x86)\Windows Kits\10\Include\%WINDOWS_SDK%\um;C:\Program Files (x86)\Windows Kits\10\Include\%WINDOWS_SDK%\ucrt;C:\Program Files (x86)\Windows Kits\10\Include\%WINDOWS_SDK%\shared;C:\vcpkg\installed\x64-windows\include

set LIB=%VS_PATH%\VC\Tools\MSVC\%MSVC_VERSION%\lib\x64;%VS_PATH%\VC\Tools\MSVC\%MSVC_VERSION%\atlmfc\lib\x64;%VS_PATH%\VC\Auxiliary\VS\lib\x64;C:\Program Files (x86)\Windows Kits\10\Lib\%WINDOWS_SDK%\um\x64;C:\Program Files (x86)\Windows Kits\10\Lib\%WINDOWS_SDK%\ucrt\x64;C:\vcpkg\installed\x64-windows\lib

call "%VS_PATH%\VC\Auxiliary\Build\vcvars64.bat" >nul 2>&1

cd /d %~dp0
cd ..

echo Building MoonBitMark (Release)...
moon clean
moon build --target native --release

if %ERRORLEVEL% EQU 0 (
    echo.
    echo Build successful!
    
    REM Copy DLLs
    echo Copying DLLs...
    copy /Y "C:\vcpkg\installed\x64-windows\bin\zip.dll" "_build\native\release\build\cmd\main\"
    copy /Y "C:\vcpkg\installed\x64-windows\bin\libexpat.dll" "_build\native\release\build\cmd\main\"
    copy /Y "C:\vcpkg\installed\x64-windows\bin\zlib1.dll" "_build\native\release\build\cmd\main\"
    copy /Y "C:\vcpkg\installed\x64-windows\bin\bz2.dll" "_build\native\release\build\cmd\main\"
    
    echo.
    echo Running DOCX test...
    _build\native\release\build\cmd\main\main.exe tests/test_data/test.docx tests/output/test.docx.md
    
    if exist "tests\output\test.docx.md" (
        echo.
        echo SUCCESS! DOCX conversion completed!
        echo Output: tests/output/test.docx.md
        dir tests\output\test.docx.md
    ) else (
        echo.
        echo FAILED! Output file not created.
    )
) else (
    echo.
    echo Build failed.
)

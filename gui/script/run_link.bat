@echo off
setlocal enabledelayedexpansion

REM === MSVC 配置 ===
set "MSVC_DIR=C:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools"
set "MSVC_BIN=%MSVC_DIR%\VC\Tools\MSVC\14.44.35207\bin\Hostx64\x64"
set "MSVC_LIB=%MSVC_DIR%\VC\Tools\MSVC\14.44.35207\lib\x64"
set "UCRT_LIB=%MSVC_DIR%\..\..\Windows Kits\10\lib\10.0.26100.0\ucrt\x64"
set "UM_LIB=%MSVC_DIR%\..\..\Windows Kits\10\lib\10.0.26100.0\um\x64"
set "BUILD_DIR=D:\MySoftware\MoonBitMark\_build\native\release\build"

echo MSVC_BIN: %MSVC_BIN%
echo BUILD_DIR: %BUILD_DIR%

REM 检查 link.exe
if not exist "%MSVC_BIN%\link.exe" (
    echo ERROR: link.exe not found at %MSVC_BIN%
    exit /b 1
)

REM 设置环境
set "PATH=%MSVC_BIN%;%PATH%"
set "LIB=%MSVC_LIB%;%UCRT_LIB%;%UM_LIB%;%BUILD_DIR%"

REM 收集 main 相关的 obj 文件
echo Collecting .obj files...
set OBJ_LIST=
for /r "%BUILD_DIR%" %%f in (*.obj) do (
    echo %%f | findstr /i "cmd\demo" >nul
    if errorlevel 1 (
        echo %%f | findstr /i "cmd\mcp-server" >nul
        if errorlevel 1 (
            set OBJ_LIST=!OBJ_LIST! "%%f"
        )
    )
)

REM 收集 .lib 文件
set LIB_LIST=
for /r "%BUILD_DIR%" %%f in (*.lib) do (
    set LIB_LIST=!LIB_LIST! "%%f"
)

echo Running link...
"%MSVC_BIN%\link.exe" /NOLOGO /SUBSYSTEM:CONSOLE ^
    /OUT:"%BUILD_DIR%\cmd\main\MoonBitMark.exe" ^
    /LIBPATH:"%MSVC_LIB%" ^
    /LIBPATH:"%UCRT_LIB%" ^
    /LIBPATH:"%UM_LIB%" ^
    /LIBPATH:"%BUILD_DIR%" ^
    %OBJ_LIST% ^
    %LIB_LIST% ^
    kernel32.lib user32.lib msvcrt.lib ws2_32.lib winhttp.lib crypt32.lib bcrypt.lib advapi32.lib

if errorlevel 1 (
    echo LINK FAILED!
    exit /b 1
)

REM 复制到 main.exe
if exist "%BUILD_DIR%\cmd\main\MoonBitMark.exe" (
    copy /Y "%BUILD_DIR%\cmd\main\MoonBitMark.exe" "%BUILD_DIR%\cmd\main\main.exe"
    echo SUCCESS!
    dir "%BUILD_DIR%\cmd\main\main.exe"
) else (
    echo ERROR: MoonBitMark.exe not created
    exit /b 1
)

endlocal

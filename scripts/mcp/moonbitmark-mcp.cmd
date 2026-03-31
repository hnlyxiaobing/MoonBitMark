@echo off
setlocal

powershell -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0moonbitmark-mcp.ps1" %*
exit /b %ERRORLEVEL%

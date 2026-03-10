@echo off
D:\MySoftware\MoonBitMark\_build\native\debug\build\cmd\main\main.exe D:\MySoftware\MoonBitMark\tests\test_data\simple.pptx D:\MySoftware\MoonBitMark\tests\output\simple.md
type D:\MySoftware\MoonBitMark\tests\output\simple.md
echo.
echo Exit code: %ERRORLEVEL%

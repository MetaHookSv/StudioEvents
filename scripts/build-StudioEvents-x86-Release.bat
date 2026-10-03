@echo off
setlocal
set "Configuration=Release"
call "%~dp0build-StudioEvents-x86.bat" %*
exit /b %errorlevel%

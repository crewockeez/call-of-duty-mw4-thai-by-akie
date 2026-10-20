@echo off
setlocal
title MW4 Thai Campaign - Uninstall
if not exist "%~dp0tools\installer.ps1" (
  echo Extract the entire ZIP before running uninstall.bat.
  pause
  exit /b 1
)
powershell.exe -NoLogo -NoProfile -STA -ExecutionPolicy Bypass -File "%~dp0tools\installer.ps1" -Mode uninstall
set "mw4_exit=%errorlevel%"
if not "%mw4_exit%"=="0" pause
exit /b %mw4_exit%

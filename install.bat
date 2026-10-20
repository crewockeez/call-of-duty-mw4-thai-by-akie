@echo off
setlocal
title MW4 Thai Campaign - Install
if not exist "%~dp0tools\installer.ps1" (
  echo Extract the entire ZIP before running install.bat.
  pause
  exit /b 1
)
powershell.exe -NoLogo -NoProfile -STA -ExecutionPolicy Bypass -File "%~dp0tools\prepare_runtime.ps1"
if errorlevel 1 (
  pause
  exit /b 1
)
powershell.exe -NoLogo -NoProfile -STA -ExecutionPolicy Bypass -File "%~dp0tools\installer.ps1" -Mode install
set "mw4_exit=%errorlevel%"
if not "%mw4_exit%"=="0" pause
exit /b %mw4_exit%

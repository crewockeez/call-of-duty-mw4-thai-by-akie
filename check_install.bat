@echo off
setlocal
title MW4 Thai - Check installation
powershell.exe -NoLogo -NoProfile -STA -ExecutionPolicy Bypass -File "%~dp0tools\diagnose.ps1"
set "mw4_exit=%errorlevel%"
if not "%mw4_exit%"=="0" pause
exit /b %mw4_exit%

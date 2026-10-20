@echo off
setlocal
title AKIE - Prepare local runtime
powershell.exe -NoLogo -NoProfile -STA -ExecutionPolicy Bypass -File "%~dp0tools\prepare_runtime.ps1"
set "akie_exit=%errorlevel%"
if not "%akie_exit%"=="0" pause
exit /b %akie_exit%

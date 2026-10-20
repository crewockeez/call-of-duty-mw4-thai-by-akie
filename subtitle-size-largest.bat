@echo off
setlocal
title MW4 Thai - Subtitle size
powershell.exe -NoLogo -NoProfile -STA -ExecutionPolicy Bypass -File "%~dp0tools\installer.ps1" -Mode resize -SubtitleSize largest
set "mw4_exit=%errorlevel%"
if not "%mw4_exit%"=="0" pause
exit /b %mw4_exit%

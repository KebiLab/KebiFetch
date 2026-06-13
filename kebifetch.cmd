@echo off
REM KebiFetch wrapper for Windows
REM Поместите kebifetch.cmd и kebifetch.ps1 в одну папку в PATH
setlocal
set "SCRIPT_DIR=%~dp0"
powershell -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT_DIR%kebifetch.ps1" %*
endlocal

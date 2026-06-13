@echo off
REM KebiFetch wrapper for Windows
REM Поместите kebifetch.cmd и kebifetch.ps1 в одну папку в PATH
setlocal
set "SCRIPT_DIR=%~dp0"

REM Включаем UTF-8 и поддержку виртуального терминала (ANSI-цветов) для cmd
chcp 65001 >nul 2>&1

powershell -NoProfile -ExecutionPolicy Bypass -Command "$host.UI.RawUI.WindowTitle = 'kebifetch'; $env:KebiRoot = '%SCRIPT_DIR%'; & '%SCRIPT_DIR%kebifetch.ps1' %*"
endlocal

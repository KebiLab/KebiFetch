@echo off
REM KebiFetch wrapper for Windows
REM Поместите kebifetch.cmd и kebifetch.ps1 в одну папку в PATH
chcp 65001 >nul 2>&1
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0kebifetch.ps1" %*

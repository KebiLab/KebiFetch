# KebiFetch installer
# Запуск (PowerShell от имени пользователя):
#   iwr -useb https://raw.githubusercontent.com/KebiLab/KebiFetch/main/install.ps1 | iex
# или локально:
#   .\install.ps1

[CmdletBinding()]
param(
    [string]$InstallDir = "$env:LOCALAPPDATA\KebiFetch",
    [switch]$System     # ставить в Program Files (нужен admin)
)

$ErrorActionPreference = 'Stop'

if ($System) {
    $InstallDir = "$env:ProgramFiles\KebiFetch"
    if (-not (Test-Path $InstallDir)) {
        New-Item -ItemType Directory -Path $InstallDir -Force | Out-Null
    }
} else {
    if (-not (Test-Path $InstallDir)) {
        New-Item -ItemType Directory -Path $InstallDir -Force | Out-Null
    }
}

Write-Host "==> Installing KebiFetch to $InstallDir" -ForegroundColor Cyan

# Копируем файлы из текущей папки (если запущен локально) или качаем с GitHub
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$sourceDir = $null

if (Test-Path (Join-Path $scriptDir 'kebifetch.ps1')) {
    $sourceDir = $scriptDir
    Write-Host "    Using local files from $sourceDir"
} else {
    $repo = 'https://github.com/KebiLab/KebiFetch/archive/refs/heads/main.zip'
    $tmp = Join-Path $env:TEMP "kebifetch-install-$([Guid]::NewGuid().ToString('N'))"
    New-Item -ItemType Directory -Path $tmp | Out-Null
    Write-Host "    Downloading from GitHub..."
    Invoke-WebRequest -Uri $repo -OutFile (Join-Path $tmp 'repo.zip') -UseBasicParsing
    Expand-Archive -Path (Join-Path $tmp 'repo.zip') -DestinationPath $tmp -Force
    $sourceDir = Get-ChildItem -Path $tmp -Directory | Where-Object { $_.Name -like 'KebiFetch-*' } | Select-Object -First 1 -ExpandProperty FullName
}

if (-not $sourceDir -or -not (Test-Path (Join-Path $sourceDir 'kebifetch.ps1'))) {
    throw "Could not find kebifetch.ps1 in source"
}

Copy-Item -Path (Join-Path $sourceDir 'kebifetch.ps1') -Destination $InstallDir -Force
Copy-Item -Path (Join-Path $sourceDir 'kebifetch.cmd') -Destination $InstallDir -Force

# Добавляем папку в пользовательский PATH (если ещё не там)
$currentPath = [Environment]::GetEnvironmentVariable('Path', 'User')
$paths = $currentPath -split ';' | Where-Object { $_ }
if ($paths -notcontains $InstallDir) {
    [Environment]::SetEnvironmentVariable('Path', "$currentPath;$InstallDir", 'User')
    $env:Path = "$env:Path;$InstallDir"
    Write-Host "    Added $InstallDir to user PATH" -ForegroundColor Green
} else {
    Write-Host "    $InstallDir is already in PATH" -ForegroundColor Green
}

# Снимаем ExecutionPolicy для локальных скриптов пользователя, если стоит Restricted
try {
    $ep = Get-ExecutionPolicy -Scope CurrentUser
    if ($ep -eq 'Restricted' -or $ep -eq 'AllSigned') {
        Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned -Force
        Write-Host "    Set user ExecutionPolicy to RemoteSigned" -ForegroundColor Yellow
    }
} catch {}

Write-Host ""
Write-Host "==> Done. Open a NEW terminal and run: kebifetch" -ForegroundColor Cyan

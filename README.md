# KebiFetch

Кроссплатформенный аналог `neofetch`, изначально для Windows (PowerShell).

## Быстрый старт (Windows)

```powershell
# Из текущей папки
.\kebifetch.ps1
```

Чтобы запускать как `kebifetch` из любого места:

1. Скопируйте `kebifetch.ps1` и `kebifetch.cmd` в любую папку, которая есть в `PATH`
   (например `C:\Users\<You>\bin\`).
2. Из PowerShell:
   ```powershell
   kebifetch
   ```

> Если PowerShell блокирует запуск — выполните один раз:
> `Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned`

## Флаги

| Флаг         | Описание                              |
|--------------|---------------------------------------|
| `-NoColor`   | Без цветов                            |
| `-NoLogo`    | Без ASCII-логотипа                    |
| `-Fields`    | Показывать только указанные поля      |
| `-Padding`   | Отступ между логотипом и текстом (по умолчанию 2) |

Примеры:

```powershell
kebifetch -NoLogo
kebifetch -NoColor
kebifetch -Fields OS,CPU,Memory,IP
```

## Что показывается

`OS`, `Host`, `Kernel`, `Uptime`, `Shell`, `Resolution`, `DE/WM`, `Theme`,
`Terminal`, `CPU`, `GPU`, `Memory`, `Disks`, `BIOS`, `IP`.

## Linux / macOS (в планах)

Скрипт написан на PowerShell Core (`pwsh`), поэтому работает на
Linux/macOS почти без изменений — только WMI-запросы (`Get-CimInstance`)
нужно заменить на `/proc`, `sysctl`, `lshw` и т.п. Структура `Get-Info`
изолирована и подготовлена к этому.

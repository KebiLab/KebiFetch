# KebiFetch - кроссплатформенный аналог neofetch
# Windows / Linux / macOS (через PowerShell Core)

[CmdletBinding()]
param(
    [switch]$NoLogo,
    [switch]$NoColor,
    [string[]]$Fields,
    [int]$Padding = 2
)

# ---- Цвета ----------------------------------------------------------------
# Пытаемся включить поддержку виртуального терминала (ANSI) на Windows.
# Если SetConsoleMode не сработал (классический cmd.exe / conhost v1 без UTF-8),
# переключаемся на $Host.UI.RawUI с 16-цветной палитрой — она работает ВСЕГДА.
$UseVT = $false
$UseHostColor = $false
if (-not $NoColor -and -not [Console]::IsOutputRedirected) {
    if ($IsWindows -or ($env:OS -eq 'Windows_NT')) {
        try {
            $signature = @"
[DllImport("kernel32.dll", SetLastError=true)]
public static extern bool SetConsoleMode(IntPtr hConsoleHandle, uint dwMode);
[DllImport("kernel32.dll", SetLastError=true)]
public static extern bool GetConsoleMode(IntPtr hConsoleHandle, out uint lpMode);
[DllImport("kernel32.dll", SetLastError=true)]
public static extern IntPtr GetStdHandle(int nStdHandle);
"@
            if (-not ('Kebi.KebiConsole' -as [type])) {
                Add-Type -MemberDefinition $signature -Name 'KebiConsole' -Namespace 'Kebi'
            }
            $handle = [Kebi.KebiConsole]::GetStdHandle(-11) # STD_OUTPUT_HANDLE
            $mode = 0
            if ([Kebi.KebiConsole]::GetConsoleMode($handle, [ref]$mode)) {
                $ENABLE_VIRTUAL_TERMINAL_PROCESSING = 0x0004
                [void][Kebi.KebiConsole]::SetConsoleMode($handle, $mode -bor $ENABLE_VIRTUAL_TERMINAL_PROCESSING)
                $mode2 = 0
                [void][Kebi.KebiConsole]::GetConsoleMode($handle, [ref]$mode2)
                if (($mode2 -band $ENABLE_VIRTUAL_TERMINAL_PROCESSING) -ne 0) {
                    $UseVT = $true
                }
            }
            [Console]::OutputEncoding = [System.Text.Encoding]::UTF8
        } catch {}
    } else {
        $UseVT = $true
    }
    # Fallback: $Host.UI.RawUI умеет 16 цветов на любом терминале Windows
    if (-not $UseVT -and ($IsWindows -or ($env:OS -eq 'Windows_NT'))) {
        $UseHostColor = $Host -and $Host.UI -and $Host.UI.RawUI
    }
}
$UseColor = $UseVT -or $UseHostColor
if ($UseColor) {
    $C = @{
        Reset   = "`e[0m"
        Dim     = "`e[2m"
        White   = "`e[37m"
        Cyan    = "`e[36m"
        BCyan   = "`e[1;36m"
        BGreen  = "`e[1;32m"
    }
    # Имена цветов для $Host.UI.RawUI.ForegroundColor (работает без VT)
    $HC = @{
        Reset   = ''
        Dim     = 'Gray'
        White   = 'White'
        Cyan    = 'Cyan'
        BCyan   = 'Cyan'
        BGreen  = 'Green'
    }
    $LogoColors = @("`e[1;32m", "`e[1;36m", "`e[1;34m", "`e[1;35m")
    $LogoHostColors = @('Green', 'Cyan', 'Blue', 'Magenta')
} else {
    $C = @{} ; foreach ($k in 'Reset','Dim','White','Cyan','BCyan','BGreen') { $C[$k] = '' }
    $HC = @{} ; foreach ($k in 'Reset','Dim','White','Cyan','BCyan','BGreen') { $HC[$k] = $null }
    $LogoColors = @('','','','')
    $LogoHostColors = @($null, $null, $null, $null)
}

# Возвращает [pscustomobject]@{ Text; Color } где Color — ANSI-строка или $null
function Paint($text, $key) {
    if (-not $UseColor) { return [pscustomobject]@{ Text = $text; Ansi = $null; HostName = $null } }
    if ($UseVT) {
        $ansi = $C[$key]
        $out = if ($ansi) { "$ansi$text$($C.Reset)" } else { $text }
        return [pscustomobject]@{ Text = $out; Ansi = $ansi; HostName = $null }
    } else {
        $name = $HC[$key]
        return [pscustomobject]@{ Text = $text; Ansi = $null; HostName = $name }
    }
}

# Возвращает окрашенный символ для лого (по индексу столбца)
function PaintLogoChar($ch, $colIdx) {
    if (-not $UseColor) { return $ch }
    if ($UseVT) {
        $c = $LogoColors[$colIdx]
        return if ($c) { "$c$ch$($C.Reset)" } else { $ch }
    } else {
        # для host-color символы пишем по одному — соберём массивом
        return $ch  # обработаем отдельно
    }
}

# ---- ASCII-логотип KEBI ---------------------------------------------------
$Logo = @(
    '  _  _____ ___ ____ ___  _   _ '
    ' | |/ /_ _| __ )_  / _ \| \ | |'
    ' | ` / | ||  _ \ | | | |  \| |'
    ' | . \ | || |_) || | |_| |\  |'
    ' |_|\_\___|____/ |_|\___/|_| \_|'
)

function Get-PaintedLogo {
    # Возвращает массив строк, каждая строка — массив @{ Ch; Ansi; HostName }
    $rows = @()
    for ($i = 0; $i -lt $Logo.Count; $i++) {
        $row = $Logo[$i]
        $cells = @()
        for ($j = 0; $j -lt $row.Length; $j++) {
            $ratio = if ($row.Length -gt 0) { $j / [double]$row.Length } else { 0 }
            $idx = [int][Math]::Floor($ratio * $LogoColors.Count)
            if ($idx -ge $LogoColors.Count) { $idx = $LogoColors.Count - 1 }
            if ($idx -lt 0) { $idx = 0 }
            $ch = $row[$j]
            if (-not $UseColor) {
                $cells += [pscustomobject]@{ Ch = $ch; Ansi = $null; HostName = $null }
            } elseif ($UseVT) {
                $ansi = $LogoColors[$idx]
                $cells += [pscustomobject]@{ Ch = $ch; Ansi = $ansi; HostName = $null }
            } else {
                $name = $LogoHostColors[$idx]
                $cells += [pscustomobject]@{ Ch = $ch; Ansi = $null; HostName = $name }
            }
        }
        $rows += ,$cells
    }
    return ,$rows
}

# ---- Кроссплатформенные хелперы -----------------------------------------
function Get-OsKind {
    if ($IsWindows) { return 'Windows' }
    if ($IsLinux)   { return 'Linux' }
    if ($IsMacOS)   { return 'macOS' }
    # Fallback для Windows PowerShell 5.1
    if ([System.Runtime.InteropServices.RuntimeInformation]::IsOSPlatform([System.Runtime.InteropServices.OSPlatform]::Windows)) { return 'Windows' }
    if ([System.Runtime.InteropServices.RuntimeInformation]::IsOSPlatform([System.Runtime.InteropServices.OSPlatform]::Linux)) { return 'Linux' }
    if ([System.Runtime.InteropServices.RuntimeInformation]::IsOSPlatform([System.Runtime.InteropServices.OSPlatform]::OSX)) { return 'macOS' }
    return 'Unknown'
}

function Read-FileOrNull($path) {
    if (Test-Path -LiteralPath $path) { return (Get-Content -LiteralPath $path -Raw -ErrorAction SilentlyContinue) }
    return $null
}

function Get-FirstMatch([string[]]$files, [string]$pattern) {
    foreach ($f in $files) {
        $c = Read-FileOrNull $f
        if ($c -and $c -match $pattern) {
            return ($Matches[1] -replace '"','').Trim()
        }
    }
    return $null
}

# ---- Сбор системной информации -------------------------------------------
function Get-Info {
    $osKind = Get-OsKind
    $info = [ordered]@{}

    if ($osKind -eq 'Windows') {
        $os      = Get-CimInstance -ClassName Win32_OperatingSystem
        $cs      = Get-CimInstance -ClassName Win32_ComputerSystem
        $cpu     = Get-CimInstance -ClassName Win32_Processor
        $gpus    = Get-CimInstance -ClassName Win32_VideoController
        $bios    = Get-CimInstance -ClassName Win32_BIOS
        $disks   = Get-CimInstance -ClassName Win32_LogicalDisk -Filter 'DriveType=3'
        $osInfo  = Get-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion'

        $uptime = 'N/A'
        if ($os -and $os.LastBootUpTime) {
            try {
                $boot = $os.LastBootUpTime
                $bootDt = if ($boot -is [string]) { [Management.ManagementDateTimeConverter]::ToDateTime($boot) } else { [DateTime]$boot }
                $ts = (Get-Date) - $bootDt
                $uptime = "{0}d {1}h {2}m" -f [int]$ts.TotalDays, $ts.Hours, $ts.Minutes
            } catch {}
        }

        $memUsed = 'N/A'
        if ($os) {
            $memUsed = '{0}MiB / {1}MiB' -f [int](($os.TotalVisibleMemorySize - $os.FreePhysicalMemory) / 1KB), [int]($os.TotalVisibleMemorySize / 1KB)
        }

        $host_ = if ($cs) { "$($cs.Manufacturer) $($cs.Model)".Trim() -replace '\s+', ' ' } else { 'N/A' }

        $resolution = 'N/A'
        try {
            Add-Type -AssemblyName System.Windows.Forms
            $mons = [System.Windows.Forms.Screen]::AllScreens
            if ($mons) {
                $parts = @($mons | ForEach-Object { "$($_.Bounds.Width)x$($_.Bounds.Height)" })
                $resolution = ($parts -join ', ')
            }
        } catch {}

        $theme = 'N/A'
        try {
            $v = (Get-ItemProperty -Path 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Themes\Personalize' -Name 'AppsUseLightTheme' -ErrorAction Stop).AppsUseLightTheme
            if ($null -ne $v) { $theme = if ($v -eq 0) { 'Dark' } else { 'Light' } }
        } catch {}

        $de = 'Explorer'
        $gpuStr = if ($gpus) { ($gpus.Name -join ', ') } else { 'N/A' }
        $cpuName = if ($cpu) { ($cpu.Name -replace '\s+', ' ' -replace '\(R\)|\(TM\)', '') } else { 'N/A' }
        $diskStr = if ($disks) {
            ($disks | ForEach-Object { "{0} {1}G/{2}G" -f $_.DeviceID, [int]($_.FreeSpace / 1GB), [int]($_.Size / 1GB) }) -join '  '
        } else { 'N/A' }
        $biosStr = if ($bios) { "$($bios.Manufacturer) $($bios.SMBIOSBIOSVersion)".Trim() } else { 'N/A' }

        $ip = 'N/A'
        try { $ip = (Get-NetIPAddress -AddressFamily IPv4 | Where-Object { $_.InterfaceAlias -notmatch 'Loopback' -and $_.IPAddress -ne '127.0.0.1' } | Select-Object -First 1).IPAddress } catch {}

        $osLabel = if ($osInfo -and $osInfo.ProductName) { "$($osInfo.ProductName) $($osInfo.DisplayVersion)".Trim() }
                   elseif ($os) { $os.Caption } else { [System.Runtime.InteropServices.RuntimeInformation]::OSDescription }
        $kernel = [Environment]::OSVersion.Version.ToString()
        $prettyName = $osLabel
    }
    else {
        # ---- Linux / macOS ----
        $osRelease = Read-FileOrNull '/etc/os-release'
        $prettyName = $null
        if ($osRelease -and $osRelease -match '(?m)^PRETTY_NAME="?([^"\n]+)"?') { $prettyName = $Matches[1] }
        if (-not $prettyName) {
            if (Test-Path '/System/Applications/Finder.app') { $prettyName = 'macOS ' + (sw_vers -productVersion 2>$null) }
            else { $prettyName = (uname -s) }
        }

        $kernel = (uname -r)
        $arch   = (uname -m)

        # Uptime: читаем /proc/uptime (Linux). На macOS — sysctl kern.boottime
        $uptime = 'N/A'
        try {
            if ($IsLinux) {
                $u = (Get-Content '/proc/uptime' -Raw -ErrorAction Stop).Split(' ')[0]
                $ts = [TimeSpan]::FromSeconds([double]$u)
                $uptime = "{0}d {1}h {2}m" -f [int]$ts.TotalDays, $ts.Hours, $ts.Minutes
            } elseif ($IsMacOS) {
                $bt = (sysctl -n kern.boottime 2>$null)
                if ($bt -match 'sec\s*=\s*(\d+)') {
                    $bootDt = [DateTimeOffset]::FromUnixTimeSeconds([int64]$Matches[1]).LocalDateTime
                    $ts = (Get-Date) - $bootDt
                    $uptime = "{0}d {1}h {2}m" -f [int]$ts.TotalDays, $ts.Hours, $ts.Minutes
                }
            }
        } catch {}

        # Host
        $host_ = 'N/A'
        if ($IsLinux) {
            $v = Read-FileOrNull '/sys/devices/virtual/dmi/id/product_name'
            $m = Read-FileOrNull '/sys/devices/virtual/dmi/id/sys_vendor'
            if ($v -or $m) { $host_ = ("$m $v").Trim() -replace '\s+', ' ' }
        }
        if ($host_ -eq 'N/A' -or -not $host_) {
            try { $host_ = (hostname) } catch { $host_ = [System.Net.Dns]::GetHostName() }
        }

        # CPU
        $cpuName = 'N/A'
        if ($IsLinux) {
            $cpuinfo = Read-FileOrNull '/proc/cpuinfo'
            if ($cpuinfo -and $cpuinfo -match '(?m)^model name\s*:\s*(.+)$') {
                $cpuName = $Matches[1].Trim() -replace '\(R\)|\(TM\)', ''
            } else {
                $cpuName = "$arch"
            }
        } elseif ($IsMacOS) {
            $cpuName = (sysctl -n machdep.cpu.brand_string 2>$null)
            if (-not $cpuName) { $cpuName = "$arch" }
        } else {
            $cpuName = "$arch"
        }

        # GPU
        $gpuStr = 'N/A'
        try {
            if ($IsLinux -and (Get-Command lspci -ErrorAction SilentlyContinue)) {
                $g = lspci 2>$null | Select-String -Pattern 'VGA|3D|Display' | ForEach-Object { ($_ -split ':')[-1].Trim() }
                if ($g) { $gpuStr = ($g -join ', ') }
            } elseif ($IsMacOS) {
                $gpuStr = (system_profiler SPDisplaysDataType 2>$null | Select-String -Pattern 'Chipset Model' | ForEach-Object { ($_ -split ':')[-1].Trim() } | Select-Object -First 1)
            }
        } catch {}

        # Memory
        $memUsed = 'N/A'
        if ($IsLinux) {
            $mi = Read-FileOrNull '/proc/meminfo'
            $total = if ($mi -and $mi -match '(?m)^MemTotal:\s*(\d+)\s*kB') { [int64]$Matches[1] * 1KB } else { 0 }
            $avail = if ($mi -and $mi -match '(?m)^MemAvailable:\s*(\d+)\s*kB') { [int64]$Matches[1] * 1KB } else { 0 }
            if ($total -gt 0) {
                $used = $total - $avail
                $memUsed = '{0}MiB / {1}MiB' -f [int]($used / 1MB), [int]($total / 1MB)
            }
        } elseif ($IsMacOS) {
            $total = [int64](sysctl -n hw.memsize 2>$null)
            $vm = (vm_stat 2>$null)
            $pageSize = [int64](sysctl -n hw.pagesize 2>$null)
            $free = 0
            if ($vm -and $vm -match '(?m)Pages free:\s*(\d+)') { $free = [int64]$Matches[1] * $pageSize }
            if ($total -gt 0 -and $free -ge 0) {
                $used = $total - $free
                $memUsed = '{0}MiB / {1}MiB' -f [int]($used / 1MB), [int]($total / 1MB)
            }
        }

        # Disks
        $diskStr = 'N/A'
        try {
            if ($IsLinux -or $IsMacOS) {
                $df = df -B1G 2>$null | Select-String -NotMatch 'tmpfs|devtmpfs|Filesystem'
                $parts = @()
                foreach ($line in $df) {
                    $cols = ($line -replace '\s+', ' ').Trim() -split ' '
                    if ($cols.Count -ge 6) {
                        $mount = $cols[-1]
                        if ($mount -match '^/(?!proc|sys|run|dev/pts)') {
                            $freeG = $cols[3]
                            $sizeG = $cols[2]
                            $parts += "$mount $freeG/$sizeG"
                        }
                    }
                }
                if ($parts) { $diskStr = $parts -join '  ' }
            }
        } catch {}

        # BIOS
        $biosStr = 'N/A'
        if ($IsLinux) {
            $b = Read-FileOrNull '/sys/devices/virtual/dmi/id/bios_vendor'
            $bv = Read-FileOrNull '/sys/devices/virtual/dmi/id/bios_version'
            if ($b -or $bv) { $biosStr = ("$b $bv").Trim() }
        }

        # IP
        $ip = 'N/A'
        try {
            if (Get-Command ip -ErrorAction SilentlyContinue) {
                $ip = (ip -4 addr 2>$null | Select-String 'inet ' | ForEach-Object { ($_ -split ' ')[1] -replace '/.*','' } | Where-Object { $_ -ne '127.0.0.1' } | Select-Object -First 1)
            } elseif (Get-Command hostname -ErrorAction SilentlyContinue) {
                $ip = (hostname -I 2>$null) -split ' ' | Where-Object { $_ -ne '127.0.0.1' -and $_ } | Select-Object -First 1
            }
        } catch {}

        $resolution = 'N/A'
        $de = $env:XDG_CURRENT_DESKTOP
        if (-not $de) {
            $de = $env:DISPLAY + '' ; if (-not $de) { $de = 'N/A' }
        }

        $theme = 'N/A'
    }

    # Общие поля
    $shell = if ($env:SHELL) { $env:SHELL } else { "powershell $($PSVersionTable.PSVersion)" }
    $terminal = (Get-Process -Id $PID).ProcessName
    if ($env:WT_SESSION) { $terminal = 'Windows Terminal' }
    elseif ($env:TERM_PROGRAM) { $terminal = $env:TERM_PROGRAM }
    elseif ($env:TERMINAL) { $terminal = $env:TERMINAL }

    $info['OS']         = $prettyName
    $info['Host']       = $host_
    $info['Kernel']     = $kernel
    $info['Uptime']     = $uptime
    $info['Shell']      = $shell
    $info['Resolution'] = $resolution
    $info['DE/WM']      = $de
    $info['Theme']      = $theme
    $info['Terminal']   = $terminal
    $info['CPU']        = $cpuName
    $info['GPU']        = $gpuStr
    $info['Memory']     = $memUsed
    $info['Disks']      = $diskStr
    $info['BIOS']       = $biosStr
    $info['IP']         = $ip

    return ,$info
}

# ---- Рендер ---------------------------------------------------------------
# Утилита: пишет строку с покраской через ANSI или Host.ForegroundColor
function Write-ColorLine {
    param(
        [string]$Text,
        [string]$AnsiColor = $null,
        [string]$HostName = $null
    )
    if ($UseVT -and $AnsiColor) {
        Write-Host "$AnsiColor$Text$($C.Reset)"
    } elseif ($UseHostColor -and $HostName) {
        Write-Host $Text -ForegroundColor $HostName
    } else {
        Write-Host $Text
    }
}

# Пишет строку логотипа (массив ячеек)
function Write-LogoLine {
    param([object[]]$Cells)
    if (-not $Cells) { Write-Host ''; return }
    if ($UseVT) {
        $sb = ''
        foreach ($cell in $Cells) {
            $sb += if ($cell.Ansi) { "$($cell.Ansi)$($cell.Ch)$($C.Reset)" } else { $cell.Ch }
        }
        Write-Host $sb
    } elseif ($UseHostColor) {
        $curColor = $null
        $buf = ''
        foreach ($cell in $Cells) {
            $name = $cell.HostName
            if ($name -ne $curColor) {
                if ($buf.Length -gt 0 -and $curColor) { Write-Host $buf -ForegroundColor $curColor -NoNewline }
                $curColor = $name
                $buf = $cell.Ch
            } else {
                $buf += $cell.Ch
            }
        }
        if ($buf.Length -gt 0) {
            if ($curColor) { Write-Host $buf -ForegroundColor $curColor -NoNewline } else { Write-Host $buf -NoNewline }
        }
        Write-Host ''
    } else {
        $s = ''
        foreach ($cell in $Cells) { $s += $cell.Ch }
        Write-Host $s
    }
}

$info = Get-Info

if ($Fields) {
    $filtered = [ordered]@{}
    foreach ($f in $Fields) { if ($info.Contains($f)) { $filtered[$f] = $info[$f] } }
    $info = $filtered
}

$logoLines = if ($NoLogo) { @() } else { Get-PaintedLogo }
$logoWidth = if ($Logo.Count) { ($Logo | Measure-Object -Property Length -Maximum).Maximum } else { 0 }

$user = $env:USERNAME
if (-not $user -and $env:USER) { $user = $env:USER }
$hostName = $env:COMPUTERNAME
if (-not $hostName) { try { $hostName = hostname } catch { $hostName = [System.Net.Dns]::GetHostName() } }

$title = "$user@$hostName"
$underline = '-' * $title.Length

# Формируем массив "правых" строк: каждая — массив сегментов @{ Text; Ansi; HostName }
$rightSegs = @()
$rightSegs += ,(Paint $title 'BCyan')
$rightSegs += ,(Paint $underline 'Cyan')
$rightSegs += ,([pscustomobject]@{ Text = ''; Ansi = $null; HostName = $null })
foreach ($k in $info.Keys) {
    $line = @()
    $line += Paint "$k" 'BGreen'
    $line += Paint ':' 'Dim'
    $line += Paint " $([string]$info[$k])" 'White'
    $rightSegs += ,$line
}

function Write-RightLine([object[]]$Segs) {
    if (-not $Segs -or $Segs.Count -eq 0) { Write-Host ''; return }
    if ($UseVT) {
        $sb = ''
        foreach ($s in $Segs) { $sb += if ($s.Ansi) { "$($s.Ansi)$($s.Text)$($C.Reset)" } else { $s.Text } }
        Write-Host $sb -NoNewline
    } elseif ($UseHostColor) {
        foreach ($s in $Segs) {
            if ($s.HostName) { Write-Host $s.Text -ForegroundColor $s.HostName -NoNewline }
            elseif ($s.Text) { Write-Host $s.Text -NoNewline }
        }
    } else {
        $sb = ''
        foreach ($s in $Segs) { $sb += $s.Text }
        Write-Host $sb -NoNewline
    }
}

$maxLines = [Math]::Max($logoLines.Count, $rightSegs.Count)

for ($i = 0; $i -lt $maxLines; $i++) {
    $hasLeft  = ($i -lt $logoLines.Count) -and $logoLines[$i] -and $logoLines[$i].Count -gt 0
    $hasRight = ($i -lt $rightSegs.Count) -and $rightSegs[$i] -and $rightSegs[$i].Count -gt 0

    if ($hasLeft -and $hasRight) {
        Write-LogoLine $logoLines[$i]
        $pad = ' ' * [Math]::Max($Padding, $logoWidth - $Logo[$i].Length + $Padding)
        Write-Host $pad -NoNewline
        Write-RightLine $rightSegs[$i]
        Write-Host ''
    } elseif ($hasLeft) {
        Write-LogoLine $logoLines[$i]
    } elseif ($hasRight) {
        Write-RightLine $rightSegs[$i]
        Write-Host ''
    } else {
        Write-Host ''
    }
}

# Цветные квадратики внизу
if ($UseColor) {
    Write-Host ''
    $bg = @(40,41,42,43,44,45,46,47,100,101,102,103,104,105,106,107)
    if ($UseVT) {
        $line = ''
        foreach ($c in $bg) { $line += "`e[${c}m  $($C.Reset)" }
        Write-Host $line
    } else {
        # 16 host-цветов: Black, DarkRed, DarkGreen, DarkYellow, DarkBlue, DarkMagenta, DarkCyan, Gray,
        # DarkGray, Red, Green, Yellow, Blue, Magenta, Cyan, White
        $names = @('Black','DarkRed','DarkGreen','DarkYellow','DarkBlue','DarkMagenta','DarkCyan','Gray','DarkGray','Red','Green','Yellow','Blue','Magenta','Cyan','White')
        foreach ($n in $names) { Write-Host '  ' -ForegroundColor $n -NoNewline }
        Write-Host ''
    }
}

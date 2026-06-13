# KebiFetch - кроссплатформенный аналог neofetch
# Изначально под Windows. Запуск: powershell -ExecutionPolicy Bypass -File kebifetch.ps1
#                  или: ./kebifetch.ps1
#                  или: kebifetch (после установки в PATH)

[CmdletBinding()]
param(
    [switch]$NoLogo,
    [switch]$NoColor,
    [string[]]$Fields,
    [int]$Padding = 2
)

# ---- Цвета ----------------------------------------------------------------
$UseColor = -not $NoColor -and -not [Console]::IsOutputRedirected -and $Host.UI.SupportsVirtualTerminal
if ($UseColor) {
    $C = @{
        Reset   = "`e[0m"
        Dim     = "`e[2m"
        White   = "`e[37m"
        Cyan    = "`e[36m"
        BCyan   = "`e[1;36m"
        BGreen  = "`e[1;32m"
    }
    $LogoColors = @("`e[1;32m", "`e[1;36m", "`e[1;34m", "`e[1;35m")
} else {
    $C = @{} ; foreach ($k in 'Reset','Dim','White','Cyan','BCyan','BGreen') { $C[$k] = '' }
    $LogoColors = @('','','','')
}

function Paint($text, $color) {
    if ($UseColor -and $color) { return "$color$text$($C.Reset)" }
    return $text
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
    $lines = @()
    for ($i = 0; $i -lt $Logo.Count; $i++) {
        $row = $Logo[$i]
        $painted = ''
        for ($j = 0; $j -lt $row.Length; $j++) {
            $ratio = if ($row.Length -gt 0) { $j / [double]$row.Length } else { 0 }
            $idx = [int][Math]::Floor($ratio * $LogoColors.Count)
            if ($idx -ge $LogoColors.Count) { $idx = $LogoColors.Count - 1 }
            if ($idx -lt 0) { $idx = 0 }
            $painted += Paint $row[$j] $LogoColors[$idx]
        }
        $lines += $painted
    }
    return ,$lines
}

# ---- Сбор системной информации -------------------------------------------
function Get-Info {
    $os      = Get-CimInstance -ClassName Win32_OperatingSystem
    $cs      = Get-CimInstance -ClassName Win32_ComputerSystem
    $cpu     = Get-CimInstance -ClassName Win32_Processor
    $gpus    = Get-CimInstance -ClassName Win32_VideoController
    $bios    = Get-CimInstance -ClassName Win32_BIOS
    $disks   = Get-CimInstance -ClassName Win32_LogicalDisk -Filter 'DriveType=3'
    $osInfo  = Get-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion'

    # Аптайм
    $uptime = 'N/A'
    if ($os -and $os.LastBootUpTime) {
        try {
            $boot = $os.LastBootUpTime
            $bootDt = if ($boot -is [string]) {
                [Management.ManagementDateTimeConverter]::ToDateTime($boot)
            } else { [DateTime]$boot }
            $ts = (Get-Date) - $bootDt
            $uptime = "{0}d {1}h {2}m" -f [int]$ts.TotalDays, $ts.Hours, $ts.Minutes
        } catch {}
    }

    # Память
    $memUsed = 'N/A'
    if ($os) {
        $memUsed = '{0}MiB / {1}MiB' -f [int](($os.TotalVisibleMemorySize - $os.FreePhysicalMemory) / 1KB), [int]($os.TotalVisibleMemorySize / 1KB)
    }

    # Shell / терминал
    $shell = if ($PSVersionTable.PSEdition -eq 'Core') { "pwsh $($PSVersionTable.PSVersion)" } else { "powershell $($PSVersionTable.PSVersion)" }
    $terminal = (Get-Process -Id $PID).ProcessName
    if ($env:WT_SESSION) { $terminal = 'Windows Terminal' }
    elseif ($env:TERM_PROGRAM) { $terminal = $env:TERM_PROGRAM }

    # Хост
    $host_ = if ($cs) { "$($cs.Manufacturer) $($cs.Model)".Trim() -replace '\s+', ' ' } else { 'N/A' }

    # Дисплей
    $resolution = 'N/A'
    try {
        Add-Type -AssemblyName System.Windows.Forms
        $mons = [System.Windows.Forms.Screen]::AllScreens
        if ($mons) {
            $parts = @($mons | ForEach-Object { "$($_.Bounds.Width)x$($_.Bounds.Height)" })
            $resolution = ($parts -join ', ')
        }
    } catch {}

    # Тема
    $theme = 'N/A'
    try {
        $appsUseLight = (Get-ItemProperty -Path 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Themes\Personalize' -Name 'AppsUseLightTheme' -ErrorAction Stop).AppsUseLightTheme
        if ($null -ne $appsUseLight) { $theme = if ($appsUseLight -eq 0) { 'Dark' } else { 'Light' } }
    } catch {}

    $gpuStr = if ($gpus) { ($gpus.Name -join ', ') } else { 'N/A' }
    $cpuName = if ($cpu) { ($cpu.Name -replace '\s+', ' ' -replace '\(R\)|\(TM\)', '') } else { 'N/A' }
    $diskStr = if ($disks) {
        ($disks | ForEach-Object {
            "{0} {1}G/{2}G" -f $_.DeviceID, [int]($_.FreeSpace / 1GB), [int]($_.Size / 1GB)
        }) -join '  '
    } else { 'N/A' }
    $biosStr = if ($bios) { "$($bios.Manufacturer) $($bios.SMBIOSBIOSVersion)".Trim() } else { 'N/A' }

    # IP
    $ip = 'N/A'
    try {
        $ip = (Get-NetIPAddress -AddressFamily IPv4 |
            Where-Object { $_.InterfaceAlias -notmatch 'Loopback' -and $_.IPAddress -ne '127.0.0.1' } |
            Select-Object -First 1).IPAddress
    } catch {}

    $osLabel = if ($osInfo -and $osInfo.ProductName) {
        "$($osInfo.ProductName) $($osInfo.DisplayVersion)".Trim()
    } elseif ($os) { $os.Caption } else { [System.Runtime.InteropServices.RuntimeInformation]::OSDescription }

    $result = [ordered]@{
        'OS'         = $osLabel
        'Host'       = $host_
        'Kernel'     = [Environment]::OSVersion.Version.ToString()
        'Uptime'     = $uptime
        'Shell'      = $shell
        'Resolution' = $resolution
        'DE/WM'      = 'Explorer'
        'Theme'      = $theme
        'Terminal'   = $terminal
        'CPU'        = $cpuName
        'GPU'        = $gpuStr
        'Memory'     = $memUsed
        'Disks'      = $diskStr
        'BIOS'       = $biosStr
        'IP'         = $ip
    }
    return ,$result
}

# ---- Рендер ---------------------------------------------------------------
$info = Get-Info

if ($Fields) {
    $filtered = [ordered]@{}
    foreach ($f in $Fields) { if ($info.Contains($f)) { $filtered[$f] = $info[$f] } }
    $info = $filtered
}

$logoLines = if ($NoLogo) { @() } else { Get-PaintedLogo }
$logoWidth = if ($Logo.Count) { ($Logo | Measure-Object -Property Length -Maximum).Maximum } else { 0 }

$title = "$($env:USERNAME)@$($env:COMPUTERNAME)"
$underline = '-' * $title.Length

$rightCol = @()
$rightCol += Paint $title $C.BCyan
$rightCol += Paint $underline $C.Cyan
$rightCol += ''
foreach ($k in $info.Keys) {
    $label = Paint "$k" $C.BGreen
    $sep   = Paint ':' $C.Dim
    $val   = Paint ([string]$info[$k]) $C.White
    $rightCol += "$label$sep $val"
}

$maxLines = [Math]::Max($logoLines.Count, $rightCol.Count)

for ($i = 0; $i -lt $maxLines; $i++) {
    $left  = if ($i -lt $logoLines.Count) { $logoLines[$i] } else { '' }
    $right = if ($i -lt $rightCol.Count) { $rightCol[$i] } else { '' }
    if ($left -and $right) {
        $pad = ' ' * [Math]::Max($Padding, $logoWidth - $Logo[$i].Length + $Padding)
        Write-Host "$left$pad$right"
    } elseif ($left) {
        Write-Host $left
    } else {
        Write-Host $right
    }
}

# Цветные квадратики внизу (палитра)
if ($UseColor) {
    Write-Host ''
    $bg = @(40,41,42,43,44,45,46,47,100,101,102,103,104,105,106,107)
    $line = ''
    foreach ($c in $bg) { $line += "`e[${c}m  $($C.Reset)" }
    Write-Host $line
}

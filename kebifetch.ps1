# KebiFetch - cross-platform neofetch alternative
# Works in PowerShell 5.1+ and PowerShell 7+

[CmdletBinding()]
param(
    [switch]$NoLogo,
    [switch]$NoColor,
    [string[]]$Fields,
    [int]$Padding = 3
)

$ESC = [char]27

# ---- Colors ----
$UseVT = $false
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
            $handle = [Kebi.KebiConsole]::GetStdHandle(-11)
            $mode = 0
            if ([Kebi.KebiConsole]::GetConsoleMode($handle, [ref]$mode)) {
                $ENABLE_VIRTUAL_TERMINAL_PROCESSING = 0x0004
                [void][Kebi.KebiConsole]::SetConsoleMode($handle, $mode -bor $ENABLE_VIRTUAL_TERMINAL_PROCESSING)
                $mode2 = 0
                [void][Kebi.KebiConsole]::GetConsoleMode($handle, [ref]$mode2)
                if (($mode2 -band $ENABLE_VIRTUAL_TERMINAL_PROCESSING) -ne 0) { $UseVT = $true }
            }
            [Console]::OutputEncoding = [System.Text.Encoding]::UTF8
        } catch {}
    } else {
        $UseVT = $true
    }
}
$UseColor = $UseVT -or (-not $NoColor -and -not [Console]::IsOutputRedirected)

# Fallback: use Host UI colors if VT failed on Windows
$UseHost = $false
if (-not $UseVT -and $UseColor -and ($IsWindows -or ($env:OS -eq 'Windows_NT'))) {
    try { $UseHost = $Host -and $Host.UI -and $Host.UI.RawUI } catch {}
}

# Color map
$CLR = @{
    Reset   = if ($UseVT) { "${ESC}[0m" } else { '' }
    Dim     = if ($UseVT) { "${ESC}[2m" } else { '' }
    White   = if ($UseVT) { "${ESC}[37m" } else { '' }
    Cyan    = if ($UseVT) { "${ESC}[36m" } else { '' }
    BCyan   = if ($UseVT) { "${ESC}[1;36m" } else { '' }
    BGreen  = if ($UseVT) { "${ESC}[1;32m" } else { '' }
}
$HC = @{
    Reset   = ''
    Dim     = 'Gray'
    White   = 'White'
    Cyan    = 'Cyan'
    BCyan   = 'Cyan'
    BGreen  = 'Green'
}
$LogoC = @("${ESC}[1;32m", "${ESC}[1;36m", "${ESC}[1;34m", "${ESC}[1;35m")

function C($text, $key) {
    if (-not $UseColor) { return $text }
    if ($UseVT) {
        $c = $CLR[$key]
        if ($c) { return "$c$text$($CLR.Reset)" } else { return $text }
    }
    return $text
}

function C-Host($text, $key) {
    if (-not $UseHost) { return $text }
    $h = $HC[$key]
    if ($h) {
        Write-Host $text -ForegroundColor $h -NoNewline
        return ''
    }
    return $text
}

# ---- Logo ----
$Logo = @(
    " _  ____ "
    "| |/ / _ "
    "| ` / |_ "
    "| . \  _|"
    "|_|\_\___|"
)

# ---- System info ----
function Get-Info {
    $osKind = 'Unknown'
    if ($IsWindows) { $osKind = 'Windows' }
    elseif ($IsLinux) { $osKind = 'Linux' }
    elseif ($IsMacOS) { $osKind = 'macOS' }
    elseif ($env:OS -eq 'Windows_NT') { $osKind = 'Windows' }
    else {
        try {
            if ([System.Runtime.InteropServices.RuntimeInformation]::IsOSPlatform([System.Runtime.InteropServices.OSPlatform]::Windows)) { $osKind = 'Windows' }
            elseif ([System.Runtime.InteropServices.RuntimeInformation]::IsOSPlatform([System.Runtime.InteropServices.OSPlatform]::Linux)) { $osKind = 'Linux' }
            elseif ([System.Runtime.InteropServices.RuntimeInformation]::IsOSPlatform([System.Runtime.InteropServices.OSPlatform]::OSX)) { $osKind = 'macOS' }
        } catch {}
    }
    $info = [ordered]@{}

    if ($osKind -eq 'Windows') {
        $os   = Get-CimInstance Win32_OperatingSystem -ErrorAction SilentlyContinue
        $cs   = Get-CimInstance Win32_ComputerSystem -ErrorAction SilentlyContinue
        $cpu  = Get-CimInstance Win32_Processor -ErrorAction SilentlyContinue
        $gpus = Get-CimInstance Win32_VideoController -ErrorAction SilentlyContinue

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
            $totalMB = [int]($os.TotalVisibleMemorySize / 1KB)
            $freeMB = [int]($os.FreePhysicalMemory / 1KB)
            $memUsed = "{0}MiB / {1}MiB" -f ($totalMB - $freeMB), $totalMB
        }

        $host_ = if ($cs) { "$($cs.Manufacturer) $($cs.Model)".Trim() -replace '\s+', ' ' } else { 'N/A' }

        $resolution = 'N/A'
        try {
            Add-Type -AssemblyName System.Windows.Forms -ErrorAction Stop
            $mons = [System.Windows.Forms.Screen]::AllScreens
            if ($mons) { $resolution = ($mons | ForEach-Object { "$($_.Bounds.Width)x$($_.Bounds.Height)" }) -join ', ' }
        } catch {}

        $theme = 'N/A'
        try {
            $v = (Get-ItemProperty 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Themes\Personalize' -Name 'AppsUseLightTheme' -ErrorAction Stop).AppsUseLightTheme
            if ($null -ne $v) { $theme = if ($v -eq 0) { 'Dark' } else { 'Light' } }
        } catch {}

        $gpuStr = if ($gpus) { ($gpus.Name -join ', ') } else { 'N/A' }
        $cpuName = if ($cpu) { ($cpu.Name -replace '\s+', ' ' -replace '\(R\)|\(TM\)', '').Trim() } else { 'N/A' }

        $ip = 'N/A'
        try { $ip = (Get-NetIPAddress -AddressFamily IPv4 | Where-Object { $_.InterfaceAlias -notmatch 'Loopback' -and $_.IPAddress -ne '127.0.0.1' } | Select-Object -First 1).IPAddress } catch {}

        $osInfo = Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion' -ErrorAction SilentlyContinue
        $osLabel = if ($osInfo -and $osInfo.ProductName) { "$($osInfo.ProductName) $($osInfo.DisplayVersion)".Trim() }
                   elseif ($os) { $os.Caption } else { 'Windows' }
        $kernel = [Environment]::OSVersion.Version.ToString()

        $info['OS']         = $osLabel
        $info['Host']       = $host_
        $info['Kernel']     = $kernel
        $info['Uptime']     = $uptime
        $info['Shell']      = "powershell $($PSVersionTable.PSVersion)"
        $info['DE']         = 'Explorer'
        $info['Theme']      = $theme
        $info['Resolution'] = $resolution
        $info['Terminal']   = if ($env:WT_SESSION) { 'Windows Terminal' } elseif ($env:TERM_PROGRAM) { $env:TERM_PROGRAM } else { (Get-Process -Id $PID).ProcessName }
        $info['CPU']        = $cpuName
        $info['GPU']        = $gpuStr
        $info['Memory']     = $memUsed
        $info['IP']         = $ip
    }
    else {
        # Linux / macOS
        $osRelease = Get-Content '/etc/os-release' -Raw -ErrorAction SilentlyContinue
        $prettyName = $null
        if ($osRelease -and $osRelease -match 'PRETTY_NAME="?([^"]+)"?') { $prettyName = $Matches[1] }
        if (-not $prettyName) {
            try { $prettyName = "macOS " + (sw_vers -productVersion 2>`$null) } catch {}
            if (-not $prettyName) { try { $prettyName = (uname -s) } catch { $prettyName = 'Linux' } }
        }

        $kernel = try { uname -r } catch { 'N/A' }
        $arch   = try { uname -m } catch { 'N/A' }

        $uptime = 'N/A'
        try {
            if ($IsLinux) {
                $u = (Get-Content '/proc/uptime' -Raw).Split(' ')[0]
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

        $cpuName = 'N/A'
        if ($IsLinux) {
            $ci = Get-Content '/proc/cpuinfo' -Raw -ErrorAction SilentlyContinue
            if ($ci -and $ci -match '(?m)^model name\s*:\s*(.+)$') { $cpuName = $Matches[1].Trim() -replace '\(R\)|\(TM\)', '' }
        } elseif ($IsMacOS) { $cpuName = (sysctl -n machdep.cpu.brand_string 2>$null) }
        if (-not $cpuName) { $cpuName = $arch }

        $gpuStr = 'N/A'
        try {
            if ($IsLinux -and (Get-Command lspci -ErrorAction SilentlyContinue)) {
                $g = lspci 2>$null | Select-String 'VGA|3D|Display' | ForEach-Object { ($_ -split ':')[-1].Trim() }
                if ($g) { $gpuStr = ($g -join ', ') }
            }
        } catch {}

        $memUsed = 'N/A'
        if ($IsLinux) {
            $mi = Get-Content '/proc/meminfo' -Raw -ErrorAction SilentlyContinue
            $total = if ($mi -and $mi -match '(?m)^MemTotal:\s*(\d+)\s*kB') { [int64]$Matches[1] * 1KB } else { 0 }
            $avail = if ($mi -and $mi -match '(?m)^MemAvailable:\s*(\d+)\s*kB') { [int64]$Matches[1] * 1KB } else { 0 }
            if ($total -gt 0) { $memUsed = "{0}MiB / {1}MiB" -f [int](($total - $avail) / 1MB), [int]($total / 1MB) }
        }

        $ip = 'N/A'
        try {
            if (Get-Command ip -ErrorAction SilentlyContinue) {
                $ip = (ip -4 addr 2>$null | Select-String 'inet ' | ForEach-Object { ($_ -split ' ')[1] -replace '/.*','' } | Where-Object { $_ -ne '127.0.0.1' } | Select-Object -First 1)
            }
        } catch {}

        $de = $env:XDG_CURRENT_DESKTOP
        if (-not $de) { $de = 'N/A' }

        $info['OS']         = $prettyName
        $info['Host']       = if ($IsLinux) { (Get-Content '/sys/devices/virtual/dmi/id/product_name' -ErrorAction SilentlyContinue) } else { hostname }
        $info['Kernel']     = $kernel
        $info['Uptime']     = $uptime
        $info['Shell']      = if ($env:SHELL) { $env:SHELL } else { "pwsh $($PSVersionTable.PSVersion)" }
        $info['DE']         = $de
        $info['Theme']      = 'N/A'
        $info['Resolution'] = 'N/A'
        $info['Terminal']   = if ($env:TERM_PROGRAM) { $env:TERM_PROGRAM } else { (Get-Process -Id $PID).ProcessName }
        $info['CPU']        = $cpuName
        $info['GPU']        = $gpuStr
        $info['Memory']     = $memUsed
        $info['IP']         = $ip
    }
    return ,$info
}

# ---- Render ----
$info = Get-Info

if ($Fields) {
    $filtered = [ordered]@{}
    foreach ($f in $Fields) { if ($info.Contains($f)) { $filtered[$f] = $info[$f] } }
    $info = $filtered
}

$user = if ($env:USERNAME) { $env:USERNAME } elseif ($env:USER) { $env:USER } else { 'user' }
$hostName = try { hostname } catch { $env:COMPUTERNAME }
$title = "$user@$hostName"

$logoLines = @()
if (-not $NoLogo) { $logoLines = $Logo }

$logoWidth = if ($logoLines.Count) { ($logoLines | Measure-Object -Property Length -Maximum).Maximum } else { 0 }

# Build right-side lines
$rightLines = @()
$rightLines += ,@{ Text = $title; Color = 'Cyan' }
$rightLines += ,@{ Text = ('-' * $title.Length); Color = 'Cyan' }
$rightLines += ,@{ Text = ''; Color = '' }
foreach ($k in $info.Keys) {
    $val = [string]$info[$k]
    $rightLines += ,@{ Key = $k; Text = $val; Color = 'White' }
}

$maxLines = [Math]::Max($logoLines.Count, $rightLines.Count)

for ($i = 0; $i -lt $maxLines; $i++) {
    $left = ''
    if ($i -lt $logoLines.Count) { $left = $logoLines[$i] }

    $pad = ' ' * ([Math]::Max($Padding, $logoWidth - $left.Length + $Padding))

    if ($i -lt $rightLines.Count) {
        $rl = $rightLines[$i]
        if ($left) { Write-Host $left -NoNewline }
        Write-Host $pad -NoNewline

        if ($rl.Key) {
            Write-Host "$($rl.Key):" -ForegroundColor Green -NoNewline
            Write-Host " $($rl.Text)" -ForegroundColor White -NoNewline
        } elseif ($rl.Color) {
            Write-Host $rl.Text -ForegroundColor $rl.Color -NoNewline
        } else {
            Write-Host $rl.Text -NoNewline
        }
        Write-Host ''
    } else {
        if ($left) { Write-Host $left }
        else { Write-Host '' }
    }
}

# Color blocks
if ($UseColor) {
    Write-Host ''
    $blockColors = @('DarkRed','DarkGreen','DarkYellow','DarkBlue','DarkMagenta','DarkCyan','Gray','Black',
                      'Red','Green','Yellow','Blue','Magenta','Cyan','White','DarkGray')
    foreach ($c in $blockColors) { Write-Host '  ' -ForegroundColor $c -NoNewline }
    Write-Host ''
}

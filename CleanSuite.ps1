<#
    CleanSuite.ps1 - modulo PowerShell modular para Windows 10/11
    Inclui funcoes de limpeza, diagnostico e reparo rapido.
#>

[CmdletBinding()]
param()

$Script:LogRoot = Join-Path -Path ${env:ProgramData} -ChildPath 'CleanSuite'
if (-not (Test-Path $Script:LogRoot)) { New-Item -Path $Script:LogRoot -ItemType Directory -ErrorAction SilentlyContinue | Out-Null }
$Script:LogPath = Join-Path -Path $Script:LogRoot -ChildPath ("CleanSuite_{0:yyyy-MM-dd}.log" -f (Get-Date))

function Write-Log {
    param([string]$Message)
    $line = "[{0:yyyy-MM-dd HH:mm:ss}] {1}" -f (Get-Date), $Message
    $line | Tee-Object -FilePath $Script:LogPath -Append
}

function Assert-Admin {
    $isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    if (-not $isAdmin) { throw 'Execute o PowerShell como Administrador.' }
}

function Remove-PathSafe {
    param([Parameter(Mandatory)][string]$Path)
    if (-not (Test-Path $Path)) { return }
    Write-Log "Removendo $Path"
    Remove-Item -Path $Path -Force -Recurse -ErrorAction SilentlyContinue
}

function Get-UserProfiles {
    $protected = @('Administrator','Administrators','Default','Default User','Public','All Users','defaultuser0','systemprofile')
    Get-ChildItem -Directory -Path "${env:SystemDrive}\Users" -ErrorAction SilentlyContinue | Where-Object { $protected -notcontains $_.Name }
}

function Clean-Temp {
    Write-Log 'Limpando temporarios do sistema e perfis'
    Remove-PathSafe "$env:TEMP\*"
    Remove-PathSafe "$env:SystemRoot\Temp\*"
    foreach ($u in Get-UserProfiles) {
        Remove-PathSafe (Join-Path $u.FullName 'AppData/Local/Temp/*')
        Remove-PathSafe (Join-Path $u.FullName 'AppData/Local/Microsoft/Windows/INetCache/*')
    }
}

function Clean-BrowserCache {
    Write-Log 'Limpando caches de Edge/Chrome/Firefox'
    foreach ($u in Get-UserProfiles) {
        $targets = @(
            (Join-Path $u.FullName 'AppData/Local/Microsoft/Edge/User Data/*/Cache/*'),
            (Join-Path $u.FullName 'AppData/Local/Google/Chrome/User Data/*/Cache/*'),
            (Join-Path $u.FullName 'AppData/Local/Mozilla/Firefox/Profiles/*/cache2/*')
        )
        foreach ($p in $targets) { Remove-PathSafe $p }
    }
}

function Clear-DnsCache {
    Write-Log 'Limpando cache DNS'
    ipconfig /flushdns | Tee-Object -FilePath $Script:LogPath -Append | Out-Null
}

function Clean-Spooler {
    Write-Log 'Limpando spooler de impressao'
    Stop-Service -Name spooler -Force -ErrorAction SilentlyContinue
    Remove-PathSafe "$env:SystemRoot\System32\spool\PRINTERS\*"
    Start-Service -Name spooler -ErrorAction SilentlyContinue
}

function Repair-System {
    param([switch]$SkipSfc)
    Write-Log 'Executando DISM /RestoreHealth'
    DISM /Online /Cleanup-Image /RestoreHealth | Tee-Object -FilePath $Script:LogPath -Append | Out-Null
    if (-not $SkipSfc) {
        Write-Log 'Executando SFC /SCANNOW'
        sfc /scannow | Tee-Object -FilePath $Script:LogPath -Append | Out-Null
    }
}

function Optimize-Prefetch {
    Write-Log 'Limpando arquivos de prefetch (.pf)'
    Get-ChildItem -Path "$env:SystemRoot\Prefetch" -Filter '*.pf' -ErrorAction SilentlyContinue | Remove-Item -Force -ErrorAction SilentlyContinue
}

function Clean-WindowsUpdate {
    Write-Log 'Limpando caches do Windows Update'
    Stop-Service -Name wuauserv,bits,cryptsvc -Force -ErrorAction SilentlyContinue
    Remove-PathSafe "$env:SystemRoot\SoftwareDistribution\Download"
    Remove-PathSafe "$env:SystemRoot\SoftwareDistribution\DataStore/DataStore.edb"
    Remove-PathSafe "$env:SystemRoot\SoftwareDistribution\DataStore/Logs"
    Remove-PathSafe "$env:SystemRoot\System32\catroot2"
    Start-Service -Name cryptsvc,bits,wuauserv -ErrorAction SilentlyContinue
}

function Invoke-DiskReport {
    Write-Log 'Gerando diagnostico de espaco em disco'
    Get-UserProfiles | ForEach-Object {
        $sizeMB = (Get-ChildItem -LiteralPath $_.FullName -Recurse -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum).Sum / 1MB
        "{0,-45} {1,10:N2} MB" -f $_.FullName, $sizeMB
    } | Sort-Object { [double]($_ -split ' +')[-2] } -Descending | Select-Object -First 10 | Tee-Object -FilePath $Script:LogPath -Append
}

function Clear-RecycleBinSafe {
    Write-Log 'Limpando lixeira'
    Clear-RecycleBin -Force -ErrorAction SilentlyContinue
}

function Uninstall-WpsOffice {
    Write-Log 'Procurando WPS Office para desinstalar'
    Get-CimInstance -ClassName Win32_Product -Filter "Name LIKE 'WPS Office%'" -ErrorAction SilentlyContinue |
        ForEach-Object { Write-Log "Removendo $($_.Name)"; $_.Uninstall() | Out-Null }
}

function Invoke-CleanAll {
    Assert-Admin
    Clean-Temp
    Clean-BrowserCache
    Clear-DnsCache
    Clean-Spooler
    Clean-WindowsUpdate
    Clear-RecycleBinSafe
    Optimize-Prefetch
    Invoke-DiskReport
    Write-Log 'Limpeza completa finalizada'
}

function Invoke-CleanLite {
    Assert-Admin
    Clean-Temp
    Clean-BrowserCache
    Clear-DnsCache
    Write-Log 'Limpeza rapida finalizada'
}

Write-Log "Modulo CleanSuite carregado. Use Invoke-CleanAll ou Invoke-CleanLite."

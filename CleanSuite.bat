@echo off
setlocal EnableExtensions EnableDelayedExpansion

:: ===============================================================
:: CleanSuite - limpeza e diagnóstico para Windows 10/11
:: Versão: 1.0.0
:: Este script cria logs, valida operações e utiliza PowerShell
:: para tarefas avançadas. Inclui um menu interativo e seguro.
:: ===============================================================

set "SCRIPT_NAME=CleanSuite"
set "SCRIPT_VERSION=1.0.0"
set "SCRIPT_DATE=%DATE% %TIME%"
set "LOGROOT=%ProgramData%\CleanSuite"
if not exist "%LOGROOT%" mkdir "%LOGROOT%" >nul 2>&1
if not exist "%LOGROOT%" set "LOGROOT=%TEMP%"
for /f "tokens=1-4 delims=/.- " %%a in ("%DATE%") do set "TODAY=%%a-%%b-%%c"
set "LOGFILE=%LOGROOT%\CleanSuite_%TODAY%.log"
set "POWERSHELL=powershell -NoLogo -NoProfile"

:RequireAdmin
net session >nul 2>&1
if not %errorlevel%==0 (
    echo [ERRO] Este script precisa ser executado como Administrador.
    echo Reabra o prompt como Administrador e tente novamente.
    goto :EOF
)

call :Log "==== %SCRIPT_NAME% v%SCRIPT_VERSION% iniciado em %SCRIPT_DATE% ===="
call :MainMenu
endlocal
exit /b

:Log
set "TS=[%date% %time%]"
echo %TS% %~1>>"%LOGFILE%"
if not "%~2"=="quiet" echo %TS% %~1
exit /b

:RunAndLog
set "CMD=%~1"
call :Log "Executando: %CMD%"
%CMD% >>"%LOGFILE%" 2>&1
if %errorlevel%==0 (
    call :Log "Concluido: %CMD%"
) else (
    call :Log "Falhou (%errorlevel%): %CMD%"
)
exit /b %errorlevel%

:MainMenu
cls
echo ------------------------------------------------------------
echo   ____ _                    _____       _          _       
echo  / ___| | ___  __ _ _ __   |_   _|__ __| |_ _   _| | ___  
echo | |   | |/ _ \/ _` | '_ \    | |/ _ \_  | __| | | | |/ _ \ 
echo | |___| |  __/ (_| | |_) |   | |  __// /| |_| |_| | |  __/ 
echo  \____|_|\___|\__,_| .__/    |_|\___/_/  \__|\__, |_|\___| 
echo                     |_|                      |___/         
echo ------------------------------------------------------------
echo   %SCRIPT_NAME% v%SCRIPT_VERSION% - Menu principal
set "CHOICE="
echo.
echo   [1] Limpeza completa (temp, logs, cache, WU, lixeira)
echo   [2] Limpar caches de navegadores (Edge/Chrome/Firefox)
echo   [3] Limpar DNS e conexoes temporarias
echo   [4] Limpar spooler de impressao
echo   [5] Reparos rapidos (DISM / SFC opcional)
echo   [6] Otimizar inicializacao (Prefetch)
echo   [7] Diagnostico de espaco em disco
echo   [8] Limpeza do Windows Update
echo   [9] Limpar lixeira
echo   [A] Limpeza rapida de temporarios
echo   [B] Desinstalar WPS Office (quando instalado)
echo   [0] Sair
echo.
choice /C 123456789AB0 /N /M "Selecione uma opcao: "
set "CHOICE=%errorlevel%"
if "%CHOICE%"==12 goto :ExitScript
if "%CHOICE%"==1 goto :CleanAll
if "%CHOICE%"==2 goto :CleanBrowserCache
if "%CHOICE%"==3 goto :FlushDNS
if "%CHOICE%"==4 goto :CleanSpooler
if "%CHOICE%"==5 goto :RepairSystem
if "%CHOICE%"==6 goto :OptimizePrefetch
if "%CHOICE%"==7 goto :DiskUsageReport
if "%CHOICE%"==8 goto :CleanWindowsUpdate
if "%CHOICE%"==9 goto :CleanRecycleBin
if "%CHOICE%"==10 goto :QuickTemp
if "%CHOICE%"==11 goto :UninstallWPS
goto :MainMenu

:ReturnMenu
call :Log "Voltando ao menu."
pause
goto :MainMenu

:CleanAll
call :Log "[1] Limpeza completa iniciada"
call :ClearTemps
call :CleanBrowserCache
call :FlushDNS
call :CleanSpooler
call :CleanWindowsUpdate
call :CleanRecycleBin
call :OptimizePrefetch
call :DiskUsageReport
call :Log "[1] Limpeza completa finalizada"
goto :ReturnMenu

:QuickTemp
call :Log "[A] Limpeza rapida de temporarios"
call :ClearTemps
call :FlushDNS
call :Log "[A] Limpeza rapida concluida"
goto :ReturnMenu

:CleanRecycleBin
call :Log "[9] Limpando lixeira"
%POWERSHELL% -Command "Clear-RecycleBin -Force -ErrorAction SilentlyContinue" >>"%LOGFILE%" 2>&1
if %errorlevel%==0 (call :Log "Lixeira limpa") else (call :Log "Falha ao limpar lixeira")
goto :ReturnMenu

:CleanBrowserCache
call :Log "[2] Limpando caches de navegadores"
%POWERSHELL% -Command "`$skip=@('Administrator','Default','Default User','All Users','Public','defaultuser0','systemprofile');`$users=Get-ChildItem -Path `$env:SystemDrive\Users -Directory -ErrorAction SilentlyContinue | Where-Object {`$skip -notcontains `$_.Name};foreach(`$u in `$users){`$paths=@(`"`$(`$u.FullName)\AppData\Local\Microsoft\Edge\User Data\*\Cache\*`",`"`$(`$u.FullName)\AppData\Local\Google\Chrome\User Data\*\Cache\*`",`"`$(`$u.FullName)\AppData\Local\Mozilla\Firefox\Profiles\*\cache2\*`",`"`$(`$u.FullName)\AppData\Local\Temp\*`",`"`$(`$u.FullName)\AppData\Local\Microsoft\Windows\INetCache\*`" );foreach(`$p in `$paths){ if(Test-Path `$p){ Remove-Item -Path `$p -Recurse -Force -ErrorAction SilentlyContinue } } }" >>"%LOGFILE%" 2>&1
if %errorlevel%==0 (call :Log "Caches de navegador limpas") else (call :Log "Falha ao limpar caches")
goto :ReturnMenu

:FlushDNS
call :Log "[3] Limpando cache DNS"
call :RunAndLog "ipconfig /flushdns"
goto :ReturnMenu

:CleanSpooler
call :Log "[4] Limpando spooler de impressao"
call :RunAndLog "net stop spooler"
call :RemovePath "%SystemRoot%\System32\spool\PRINTERS\*"
call :RunAndLog "net start spooler"
goto :ReturnMenu

:RepairSystem
call :Log "[5] Reparos (DISM /RestoreHealth)"
call :RunAndLog "DISM /Online /Cleanup-Image /RestoreHealth"
set /p "RUNSFC=Deseja executar SFC /SCANNOW? (S/N): "
if /I "%RUNSFC%"=="S" (
    call :RunAndLog "sfc /scannow"
) else (
    call :Log "SFC ignorado pelo usuario"
)
goto :ReturnMenu

:OptimizePrefetch
call :Log "[6] Limpando arquivos de prefetch (sem remover pastas)"
if exist "%SystemRoot%\Prefetch\*.pf" del /q /f "%SystemRoot%\Prefetch\*.pf" >>"%LOGFILE%" 2>&1
call :Log "Prefetch limpo"
goto :ReturnMenu

:DiskUsageReport
call :Log "[7] Gerando diagnostico de espaco em disco"
%POWERSHELL% -Command "Get-ChildItem -Path `$env:SystemDrive\Users -Directory -ErrorAction SilentlyContinue | Where-Object {`$_.Name -notin 'Default','Default User','Public','All Users','defaultuser0','systemprofile'} | ForEach-Object {`$size=(Get-ChildItem -LiteralPath `$_.FullName -Recurse -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum).Sum/1MB;`"{0,-45} {1,10:N2} MB`" -f `$_.FullName,`$size} | Sort-Object { [double]($_ -split ' +')[-2] } -Descending | Select-Object -First 10" >>"%LOGFILE%" 2>&1
call :Log "Relatorio salvo em %LOGFILE%"
goto :ReturnMenu

:CleanWindowsUpdate
call :Log "[8] Limpando caches do Windows Update"
call :RunAndLog "net stop wuauserv"
call :RunAndLog "net stop bits"
call :RunAndLog "net stop cryptsvc"
call :RemovePath "%SystemRoot%\SoftwareDistribution\Download"
call :RemovePath "%SystemRoot%\SoftwareDistribution\DataStore\DataStore.edb"
call :RemovePath "%SystemRoot%\SoftwareDistribution\DataStore\Logs"
call :RemovePath "%SystemRoot%\System32\catroot2"
call :RunAndLog "net start cryptsvc"
call :RunAndLog "net start bits"
call :RunAndLog "net start wuauserv"
call :Log "Windows Update limpo"
goto :ReturnMenu

:ClearTemps
call :Log "Limpando temporarios do sistema e de usuarios"
call :RemovePath "%TEMP%\*"
call :RemovePath "%SystemRoot%\Temp\*"
for /d %%U in ("%SystemDrive%\Users\*") do (
    call :IsProtectedProfile "%%~nxU"
    if errorlevel 1 (
        call :Log "Ignorando perfil protegido %%~nxU"
    ) else (
        call :RemovePath "%%~fU\AppData\Local\Temp\*"
        call :RemovePath "%%~fU\AppData\Local\Microsoft\Windows\INetCache\*"
    )
)
exit /b

:IsProtectedProfile
set "USERCHECK=%~1"
set "USERCHECK=!USERCHECK: =!"
for %%P in (Administrator Administrators "Default User" Default Public "All Users" defaultuser0 systemprofile) do (
    if /I "%%~P"=="%USERCHECK%" exit /b 1
)
exit /b 0

:RemovePath
set "TARGET=%~1"
if "%TARGET%"=="" exit /b 0
%POWERSHELL% -Command "param([string]`$p) if(Test-Path `$p){ Remove-Item -Path `$p -Recurse -Force -ErrorAction SilentlyContinue }; if(Test-Path `$p){ exit 1 }" -Args "%TARGET%" >>"%LOGFILE%" 2>&1
if %errorlevel%==0 (call :Log "Removido: %TARGET%" "quiet") else (call :Log "Falha ao remover: %TARGET%" "quiet")
exit /b 0

:UninstallWPS
call :Log "[B] Tentando desinstalar WPS Office"
%POWERSHELL% -Command "Get-CimInstance -ClassName Win32_Product -Filter \"Name LIKE 'WPS Office%'\" -ErrorAction SilentlyContinue | ForEach-Object { Write-Host ('Removendo {0}' -f `$_.Name); `$_.Uninstall() | Out-Null }" >>"%LOGFILE%" 2>&1
if %errorlevel%==0 (call :Log "Verificacao de WPS concluida (consulte log)") else (call :Log "Nao foi possivel concluir desinstalacao do WPS")
goto :ReturnMenu

:ExitScript
call :Log "Script finalizado pelo usuario"
echo Logs gravados em: %LOGFILE%
endlocal
exit /b

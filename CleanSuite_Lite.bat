@echo off
setlocal EnableExtensions

:: ===============================================================
:: CleanSuite Lite - limpeza segura e rápida para Windows 10/11
:: Mantém logs e validações básicas.
:: ===============================================================

set "LOGFILE=%TEMP%\CleanSuite_Lite.log"
set "POWERSHELL=powershell -NoLogo -NoProfile"
net session >nul 2>&1
if not %errorlevel%==0 (
    echo [ERRO] Execute como Administrador.
    goto :EOF
)

echo [INFO] Iniciando CleanSuite Lite > "%LOGFILE%"
call :ClearTemps
call :CleanBrowserCache
call :FlushDNS
echo [INFO] Concluido. Consulte o log em %LOGFILE%.
endlocal
exit /b

:IsProtected
set "U=%~1"
for %%P in (Administrator "Default User" Default Public "All Users" defaultuser0 systemprofile) do (
    if /I "%%~P"=="%U%" exit /b 1
)
exit /b 0

:ClearTemps
echo [INFO] Limpando temporarios...
%POWERSHELL% -Command "Remove-Item -Path `$env:TEMP\* -Recurse -Force -ErrorAction SilentlyContinue" >>"%LOGFILE%" 2>&1
%POWERSHELL% -Command "Remove-Item -Path `$env:SystemRoot\Temp\* -Recurse -Force -ErrorAction SilentlyContinue" >>"%LOGFILE%" 2>&1
for /d %%U in ("%SystemDrive%\Users\*") do (
    call :IsProtected "%%~nxU"
    if errorlevel 1 (
        echo [INFO] Ignorando %%~nxU >>"%LOGFILE%"
    ) else (
        %POWERSHELL% -Command "param([string]`$p) if(Test-Path `$p){Remove-Item -Path `$p -Recurse -Force -ErrorAction SilentlyContinue}" -Args "%%~fU\AppData\Local\Temp\*" >>"%LOGFILE%" 2>&1
        %POWERSHELL% -Command "param([string]`$p) if(Test-Path `$p){Remove-Item -Path `$p -Recurse -Force -ErrorAction SilentlyContinue}" -Args "%%~fU\AppData\Local\Microsoft\Windows\INetCache\*" >>"%LOGFILE%" 2>&1
    )
)
exit /b

:CleanBrowserCache
echo [INFO] Limpando caches de navegadores...
%POWERSHELL% -Command "`$skip=@('Administrator','Default','Default User','All Users','Public','defaultuser0','systemprofile');`$users=Get-ChildItem -Path `$env:SystemDrive\Users -Directory -ErrorAction SilentlyContinue | Where-Object {`$skip -notcontains `$_.Name};foreach(`$u in `$users){`$paths=@(`"`$(`$u.FullName)\AppData\Local\Microsoft\Edge\User Data\*\Cache\*`",`"`$(`$u.FullName)\AppData\Local\Google\Chrome\User Data\*\Cache\*`",`"`$(`$u.FullName)\AppData\Local\Mozilla\Firefox\Profiles\*\cache2\*`" );foreach(`$p in `$paths){ if(Test-Path `$p){ Remove-Item -Path `$p -Recurse -Force -ErrorAction SilentlyContinue } } }" >>"%LOGFILE%" 2>&1
exit /b

:FlushDNS
echo [INFO] Limpando cache DNS...
ipconfig /flushdns >>"%LOGFILE%" 2>&1
exit /b

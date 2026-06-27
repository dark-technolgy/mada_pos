@echo off
chcp 65001 >nul
cd /d "%~dp0"

set MARKER=%LOCALAPPDATA%\Mada_POS\prerequisites_v1.done
if not exist "%MARKER%" (
    if exist "redist\vc_redist.x64.exe" (
        echo Installing Visual C++ Runtime...
        "redist\vc_redist.x64.exe" /install /quiet /norestart
    )
    if exist "redist\ndp48-web.exe" (
        echo Installing .NET Framework 4.8...
        "redist\ndp48-web.exe" /q /norestart
    )
    if exist "redist\ndp48-x86-x64-allos-enu.exe" (
        echo Installing .NET Framework 4.8 (offline)...
        "redist\ndp48-x86-x64-allos-enu.exe" /q /norestart
    )
    if not exist "%LOCALAPPDATA%\Mada_POS" mkdir "%LOCALAPPDATA%\Mada_POS"
    echo ok>"%MARKER%"
)

start "" "mada_pos.exe"

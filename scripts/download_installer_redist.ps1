# Downloads Windows runtime installers bundled with Mada Smart POS distribution.
# Usage: .\scripts\download_installer_redist.ps1 [-IncludeDotNetOffline]

param(
    [switch]$IncludeDotNetOffline
)

$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$RedistDir = Join-Path $Root "installer\redist"
New-Item -ItemType Directory -Path $RedistDir -Force | Out-Null

function Save-Download {
    param(
        [string]$Url,
        [string]$OutFile,
        [string]$Label
    )
    if (Test-Path $OutFile) {
        Write-Host "  OK (cached): $Label" -ForegroundColor DarkGray
        return
    }
    Write-Host "  Downloading: $Label ..." -ForegroundColor Yellow
    Invoke-WebRequest -Uri $Url -OutFile $OutFile -UseBasicParsing
    Write-Host "  Saved: $OutFile" -ForegroundColor Green
}

Write-Host "=== Mada Smart POS - Runtime redistributables ===" -ForegroundColor Cyan

$vcRedist = Join-Path $RedistDir "vc_redist.x64.exe"
Save-Download `
    -Url "https://aka.ms/vs/17/release/vc_redist.x64.exe" `
    -OutFile $vcRedist `
    -Label "Visual C++ 2015-2022 x64"

$ndpWeb = Join-Path $RedistDir "ndp48-web.exe"
Save-Download `
    -Url "https://go.microsoft.com/fwlink/?linkid=2085155" `
    -OutFile $ndpWeb `
    -Label ".NET Framework 4.8 web installer"

if ($IncludeDotNetOffline) {
    $ndpOffline = Join-Path $RedistDir "ndp48-x86-x64-allos-enu.exe"
    Save-Download `
        -Url "https://go.microsoft.com/fwlink/?LinkId=2088631" `
        -OutFile $ndpOffline `
        -Label ".NET Framework 4.8 offline installer"
}

Write-Host ""
Write-Host "Done. Files in: $RedistDir" -ForegroundColor Cyan
Get-ChildItem $RedistDir -File | ForEach-Object {
    $mb = [math]::Round($_.Length / 1MB, 2)
    Write-Host ("  {0} ({1} MB)" -f $_.Name, $mb)
}
exit 0

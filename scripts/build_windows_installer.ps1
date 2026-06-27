# Mada Smart POS — Build Windows release + installer + user manual PDF
# Usage: .\scripts\build_windows_installer.ps1 [-SkipInstaller] [-SkipManual] [-SkipClean] [-SkipTests]

param(
    [switch]$SkipInstaller,
    [switch]$SkipManual,
    [switch]$SkipClean,
    [switch]$SkipTests
)

$AppVersion = "1.0.0"
$SymbolsDir = "build\symbols\windows\$AppVersion"

$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
Set-Location $Root

Write-Host "=== Mada Smart POS Windows Build (Release + Obfuscation) ===" -ForegroundColor Cyan

# Clean previous outputs
if (-not $SkipClean) {
    Write-Host "`n[Clean] Removing old build artifacts..." -ForegroundColor Yellow
    $DistDir = Join-Path $Root "dist"
    if (Test-Path $DistDir) {
        Remove-Item $DistDir -Recurse -Force
    }
    New-Item -ItemType Directory -Path $DistDir -Force | Out-Null
    if (Test-Path "build") {
        flutter clean 2>&1 | Out-Null
    }
    Write-Host "Clean complete." -ForegroundColor Green
}

# 0. Windows runtime redistributables (VC++, .NET)
Write-Host "`n[0/6] Downloading Windows runtimes (VC++, .NET)..." -ForegroundColor Yellow
& (Join-Path $Root "scripts\download_installer_redist.ps1") -IncludeDotNetOffline
if (-not $?) { exit 1 }

# 1. Flutter dependencies
Write-Host "`n[1/6] flutter pub get..." -ForegroundColor Yellow
flutter pub get
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

# 2. Tests (optional gate)
if (-not $SkipTests) {
    Write-Host "`n[2/6] flutter test..." -ForegroundColor Yellow
    flutter test
    if ($LASTEXITCODE -ne 0) {
        Write-Host "Tests failed. Fix before release build." -ForegroundColor Red
        exit $LASTEXITCODE
    }
}
else {
    Write-Host "`n[2/6] Skipping tests (-SkipTests)" -ForegroundColor DarkGray
}

# 3. Release build (Dart obfuscation — do not ship symbols to customers)
Write-Host "`n[3/6] flutter build windows --release --obfuscate..." -ForegroundColor Yellow
$SymbolsPath = Join-Path $Root $SymbolsDir
New-Item -ItemType Directory -Path $SymbolsPath -Force | Out-Null
flutter build windows --release --obfuscate --split-debug-info="$SymbolsPath"
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
Write-Host "Debug symbols (keep private): $SymbolsPath" -ForegroundColor DarkGray

$ReleaseDir = Join-Path $Root "build\windows\x64\runner\Release"
$ExePath = Join-Path $ReleaseDir "mada_pos.exe"
if (-not (Test-Path $ExePath)) {
    throw "Build output not found: $ExePath"
}
Write-Host "Built: $ExePath" -ForegroundColor Green

# Copy runtime installers next to the app (first-run + portable)
$RedistSrc = Join-Path $Root "installer\redist"
$RedistDst = Join-Path $ReleaseDir "redist"
if (Test-Path $RedistSrc) {
    if (Test-Path $RedistDst) { Remove-Item $RedistDst -Recurse -Force }
    Copy-Item $RedistSrc $RedistDst -Recurse -Force
    Copy-Item (Join-Path $Root "installer\Start_Mada_POS.bat") $ReleaseDir -Force
    Write-Host "Bundled redist + launcher into Release folder" -ForegroundColor Green
}

# 4. User manual PDF
if (-not $SkipManual) {
    Write-Host "`n[4/6] Generating user manuals (AR, EN, KU)..." -ForegroundColor Yellow
    dart run tool/generate_user_manual.dart all
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
}

# 5. Portable ZIP (always)
$DistDir = Join-Path $Root "dist"
if (-not (Test-Path $DistDir)) { New-Item -ItemType Directory -Path $DistDir | Out-Null }

$ZipName = "Mada_POS_Portable_$AppVersion.zip"
$ZipPath = Join-Path $DistDir $ZipName
if (Test-Path $ZipPath) { Remove-Item $ZipPath -Force }

Write-Host "`nCreating portable ZIP..." -ForegroundColor Yellow
$Staging = Join-Path $env:TEMP "mada_pos_portable_staging"
if (Test-Path $Staging) { Remove-Item $Staging -Recurse -Force }
New-Item -ItemType Directory -Path $Staging | Out-Null
Copy-Item -Path "$ReleaseDir\*" -Destination $Staging -Recurse -Force
$Launcher = Join-Path $ReleaseDir "Start_Mada_POS.bat"
if (Test-Path $Launcher) {
    Copy-Item $Launcher (Join-Path $Staging "Start_Mada_POS.bat") -Force
}
$DocsDir = Join-Path $Staging "docs"
New-Item -ItemType Directory -Path $DocsDir -Force | Out-Null
foreach ($manual in @(
    "Mada_POS_User_Manual_AR.pdf",
    "Mada_POS_User_Manual_EN.pdf",
    "Mada_POS_User_Manual_KU.pdf"
)) {
    $src = Join-Path $DistDir $manual
    if (Test-Path $src) {
        Copy-Item $src -Destination (Join-Path $DocsDir $manual)
    }
}
# Also bundle docs into Release for dev runs
$ReleaseDocs = Join-Path $ReleaseDir "docs"
New-Item -ItemType Directory -Path $ReleaseDocs -Force | Out-Null
Copy-Item "$DocsDir\*" $ReleaseDocs -Force -ErrorAction SilentlyContinue
Compress-Archive -Path "$Staging\*" -DestinationPath $ZipPath -Force
Remove-Item $Staging -Recurse -Force
Write-Host "Created: $ZipPath" -ForegroundColor Green

# 6. Inno Setup installer
if (-not $SkipInstaller) {
    Write-Host "`n[6/6] Building installer (Inno Setup)..." -ForegroundColor Yellow
    $Iscc = @(
        "${env:ProgramFiles(x86)}\Inno Setup 6\ISCC.exe",
        "${env:ProgramFiles}\Inno Setup 6\ISCC.exe",
        "$env:LOCALAPPDATA\Programs\Inno Setup 6\ISCC.exe"
    ) | Where-Object { Test-Path $_ } | Select-Object -First 1

    if ($Iscc) {
        & $Iscc (Join-Path $Root "installer\mada_pos.iss")
        if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
        $SetupExe = Join-Path $DistDir "Mada_POS_Setup_$AppVersion.exe"
        Write-Host "Created installer: $SetupExe" -ForegroundColor Green
    }
    else {
        Write-Host "Inno Setup 6 not found. Install from: https://jrsoftware.org/isdl.php" -ForegroundColor Yellow
        Write-Host "Portable ZIP is ready. Re-run script after installing Inno Setup for .exe installer." -ForegroundColor Yellow
    }
}

Write-Host "`n=== Done ===" -ForegroundColor Cyan
Write-Host "Outputs in: $DistDir"
Get-ChildItem $DistDir | Format-Table Name, Length, LastWriteTime

# Instala o que é preciso no Windows (PowerShell como utilizador normal): Git, Docker Desktop,
# Android Studio (traz o Android SDK e o emulador) e Flutter.
# Uso:  powershell -ExecutionPolicy Bypass -File scripts\install-prereqs-windows.ps1
$ErrorActionPreference = "Stop"

function Install-IfMissing($id) {
    winget install --id $id -e --accept-package-agreements --accept-source-agreements
}

Install-IfMissing "Git.Git"
Install-IfMissing "Docker.DockerDesktop"
Install-IfMissing "Google.AndroidStudio"

$flutterDir = "$env:USERPROFILE\development\flutter"
if (-not (Test-Path $flutterDir)) {
    New-Item -ItemType Directory -Force -Path (Split-Path $flutterDir) | Out-Null
    git clone --depth 1 -b stable https://github.com/flutter/flutter.git $flutterDir
}
$userPath = [Environment]::GetEnvironmentVariable("Path", "User")
if ($userPath -notlike "*$flutterDir\bin*") {
    [Environment]::SetEnvironmentVariable("Path", "$userPath;$flutterDir\bin", "User")
}

Write-Host ""
Write-Host "Falta (uma vez, manualmente):"
Write-Host " 1. Abre o Android Studio, conclui o assistente (instala o Android SDK) e em"
Write-Host "    More Actions > SDK Manager > SDK Tools marca 'Android SDK Command-line Tools'."
Write-Host " 2. Abre um PowerShell NOVO e corre:  flutter doctor --android-licenses   e depois   flutter doctor"
Write-Host " 3. Cria um emulador em Android Studio > Device Manager."

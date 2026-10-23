# Prepara o projeto Flutter (Windows, PowerShell). Corre uma vez, dentro da pasta mobile\:
#   powershell -ExecutionPolicy Bypass -File tool\setup.ps1
$ErrorActionPreference = "Stop"
Set-Location (Split-Path -Parent $PSScriptRoot)

if (-not (Get-Command flutter -ErrorAction SilentlyContinue)) {
    Write-Host "ERRO: o Flutter não está instalado ou não está no PATH." -ForegroundColor Red
    Write-Host "Instala em https://docs.flutter.dev/get-started/install e corre 'flutter doctor'."
    exit 1
}

Write-Host "==> A gerar as pastas android/ (e ios/) ..."
flutter create --platforms=android,ios,web --org pt.gamehall --project-name gamehall_torneios .
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

# 1) Android: permitir HTTP (sem TLS) APENAS em debug.
$debugManifest = "android\app\src\debug\AndroidManifest.xml"
if (Test-Path $debugManifest) {
    $text = Get-Content $debugManifest -Raw
    if ($text -notmatch "usesCleartextTraffic") {
        $needle = '<manifest xmlns:android="http://schemas.android.com/apk/res/android">'
        $text = $text.Replace($needle, "$needle`n    <application android:usesCleartextTraffic=`"true`" />")
        Set-Content $debugManifest $text -NoNewline
        Write-Host "==> HTTP local permitido só em debug."
    }
}

# 2) Android: o flutter_secure_storage precisa de minSdk 23.
foreach ($f in @("android\app\build.gradle", "android\app\build.gradle.kts")) {
    if (Test-Path $f) {
        $content = Get-Content $f -Raw
        $content = $content -replace 'minSdk(Version)?( =|) *flutter\.minSdkVersion', 'minSdk$1$2 23'
        Set-Content $f $content -NoNewline
        Write-Host "==> minSdk ajustado para 23 em $f"
    }
}

# 3) Android: permissão de internet também nas versões de produção (necessária para a API e para os vídeos).
$mainManifest = "android\app\src\main\AndroidManifest.xml"
if (Test-Path $mainManifest) {
    $text = Get-Content $mainManifest -Raw
    if ($text -notmatch "android.permission.INTERNET") {
        $needle = '<manifest xmlns:android="http://schemas.android.com/apk/res/android">'
        $text = $text.Replace($needle, "$needle`n    <uses-permission android:name=`"android.permission.INTERNET`" />")
        Set-Content $mainManifest $text -NoNewline
        Write-Host "==> Permissão INTERNET adicionada ao manifesto principal."
    }
}

Write-Host "==> A instalar dependências..."
flutter pub get

Write-Host ""
Write-Host "Pronto. Para correr:"
Write-Host "  (1) na raiz do repositório:  .\scripts\dev.ps1 up"
Write-Host "  (2) aqui:                    flutter run     (emulador Android usa http://10.0.2.2:8080)"
Write-Host "Telemóvel real:  flutter run --dart-define=API_BASE_URL=http://IP_DO_PC:8080"

#!/usr/bin/env bash
# Prepara o projeto Flutter (Linux/macOS). Corre uma vez, dentro da pasta mobile/:
#   bash tool/setup.sh
set -euo pipefail
cd "$(dirname "$0")/.."

if ! command -v flutter >/dev/null 2>&1; then
  echo "ERRO: o Flutter não está instalado ou não está no PATH."
  echo "Instala em https://docs.flutter.dev/get-started/install e corre 'flutter doctor'."
  exit 1
fi

echo "==> A gerar as pastas android/ e ios/ (não mexe nos ficheiros que já existem)..."
flutter create --platforms=android,ios,web --org pt.gamehall --project-name gamehall_torneios .

# 1) Android: permitir HTTP (sem TLS) APENAS em debug, para falar com a API local.
DEBUG_MANIFEST="android/app/src/debug/AndroidManifest.xml"
if [ -f "$DEBUG_MANIFEST" ] && ! grep -q usesCleartextTraffic "$DEBUG_MANIFEST"; then
  sed -i 's#<manifest xmlns:android="http://schemas.android.com/apk/res/android">#<manifest xmlns:android="http://schemas.android.com/apk/res/android">\n    <application android:usesCleartextTraffic="true" />#' "$DEBUG_MANIFEST"
  echo "==> HTTP local permitido só em debug (android/app/src/debug)."
fi

# 2) Android: o flutter_secure_storage precisa de minSdk 23.
for f in android/app/build.gradle android/app/build.gradle.kts; do
  if [ -f "$f" ]; then
    sed -i -E 's/minSdk(Version)?( =|) *flutter\.minSdkVersion/minSdk\1\2 23/' "$f"
    echo "==> minSdk ajustado para 23 em $f"
  fi
done

# 3) Android: permissão de internet também nas versões de produção (o Flutter só a põe em debug/profile).
#    Necessária para falar com a API e para os vídeos de destaque.
MAIN_MANIFEST="android/app/src/main/AndroidManifest.xml"
if [ -f "$MAIN_MANIFEST" ] && ! grep -q "android.permission.INTERNET" "$MAIN_MANIFEST"; then
  sed -i 's#<manifest xmlns:android="http://schemas.android.com/apk/res/android">#<manifest xmlns:android="http://schemas.android.com/apk/res/android">\n    <uses-permission android:name="android.permission.INTERNET" />#' "$MAIN_MANIFEST"
  echo "==> Permissão INTERNET adicionada ao manifesto principal."
fi

echo "==> A instalar dependências..."
flutter pub get

echo ""
echo "Pronto. Para correr:"
echo "  (1) na raiz do repositório:  make up      # API + base de dados + MailHog"
echo "  (2) aqui:                    flutter run  # emulador Android: usa http://10.0.2.2:8080"
echo "Telemóvel real:  flutter run --dart-define=API_BASE_URL=http://IP_DO_PC:8080"

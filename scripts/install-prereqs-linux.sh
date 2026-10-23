#!/usr/bin/env bash
# Instala TUDO o que é preciso para desenvolver a app no Linux (Ubuntu/Debian):
# Docker, Flutter, JDK 17, Android SDK + emulador. É o "requirements" do projeto.
# Uso (na raiz do repositório):  bash scripts/install-prereqs-linux.sh
# É seguro correr mais de uma vez: salta o que já estiver instalado.
set -euo pipefail

FLUTTER_DIR="$HOME/development/flutter"
ANDROID_DIR="$HOME/Android/Sdk"
CMDLINE_ZIP_URL="https://dl.google.com/android/repository/commandlinetools-linux-11076708_latest.zip"
API_LEVEL=35

say() { printf '\n==> %s\n' "$*"; }

say "1/6 Pacotes do sistema (pede a palavra-passe sudo)"
sudo apt-get update
sudo apt-get install -y curl git unzip xz-utils zip libglu1-mesa openjdk-17-jdk \
  clang cmake ninja-build pkg-config libgtk-3-dev qemu-kvm

if ! command -v docker >/dev/null 2>&1; then
  say "2/6 Docker"
  sudo apt-get install -y docker.io docker-compose-v2 || sudo apt-get install -y docker.io docker-compose-plugin
  sudo usermod -aG docker "$USER"
  echo "   (Docker instalado. Termina sessão e volta a entrar para usares 'docker' sem sudo.)"
else
  say "2/6 Docker já instalado"
fi

if [ ! -d "$FLUTTER_DIR" ]; then
  say "3/6 Flutter (canal stable)"
  mkdir -p "$(dirname "$FLUTTER_DIR")"
  git clone --depth 1 -b stable https://github.com/flutter/flutter.git "$FLUTTER_DIR"
else
  say "3/6 Flutter já instalado (a atualizar)"
  git -C "$FLUTTER_DIR" pull --ff-only || true
fi

if [ ! -x "$ANDROID_DIR/cmdline-tools/latest/bin/sdkmanager" ]; then
  say "4/6 Android command-line tools"
  mkdir -p "$ANDROID_DIR/cmdline-tools"
  tmp="$(mktemp -d)"
  curl -fL "$CMDLINE_ZIP_URL" -o "$tmp/cmdline.zip"
  unzip -q "$tmp/cmdline.zip" -d "$tmp"
  rm -rf "$ANDROID_DIR/cmdline-tools/latest"
  mv "$tmp/cmdline-tools" "$ANDROID_DIR/cmdline-tools/latest"
  rm -rf "$tmp"
else
  say "4/6 Android command-line tools já instaladas"
fi

export ANDROID_HOME="$ANDROID_DIR"
export PATH="$FLUTTER_DIR/bin:$ANDROID_DIR/cmdline-tools/latest/bin:$ANDROID_DIR/platform-tools:$ANDROID_DIR/emulator:$PATH"

say "5/6 Android SDK, emulador e imagem do sistema (alguns GB, demora)"
yes | sdkmanager --licenses >/dev/null || true
sdkmanager "platform-tools" "emulator" "platforms;android-$API_LEVEL" "build-tools;$API_LEVEL.0.0" \
  "system-images;android-$API_LEVEL;google_apis;x86_64"
if ! avdmanager list avd | grep -q "gamehall_pixel"; then
  echo no | avdmanager create avd -n gamehall_pixel -k "system-images;android-$API_LEVEL;google_apis;x86_64" -d pixel_7
fi

say "6/6 Configurar o Flutter"
flutter config --android-sdk "$ANDROID_DIR" --no-analytics >/dev/null
yes | flutter doctor --android-licenses >/dev/null || true

# PATH permanente
PROFILE="$HOME/.bashrc"
if ! grep -q "GAMEHALL-FLUTTER" "$PROFILE" 2>/dev/null; then
  cat >> "$PROFILE" <<EOT

# GAMEHALL-FLUTTER
export ANDROID_HOME="$ANDROID_DIR"
export PATH="$FLUTTER_DIR/bin:$ANDROID_DIR/cmdline-tools/latest/bin:$ANDROID_DIR/platform-tools:$ANDROID_DIR/emulator:\$PATH"
EOT
fi

echo ""
if [ -e /dev/kvm ] && [ -r /dev/kvm ] && [ -w /dev/kvm ]; then
  echo "KVM: OK (o emulador corre acelerado)."
else
  echo "AVISO: sem acesso a /dev/kvm. O emulador fica MUITO lento ou falha."
  echo "       Ativa a virtualização na BIOS e corre: sudo adduser \$USER kvm   (depois reinicia a sessão)."
  echo "       Em WSL/VM sem virtualização aninhada, usa um telemóvel real por USB."
fi
echo ""
echo "Pronto. Abre um terminal NOVO e corre:  flutter doctor"
echo "Emulador:  flutter emulators --launch gamehall_pixel"

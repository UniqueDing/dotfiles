#!/usr/bin/env bash
set -euo pipefail

DOTFILES_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"

cat > "$DOTFILES_DIR/local.nix" <<EOF
{
  dotfilesPath = "$DOTFILES_DIR";
}
EOF

sudo mkdir -p /opt/android-sdk
sudo chown "$(id -u):$(id -g)" /opt/android-sdk

sdkmanager --install "cmdline-tools;latest"
sdkmanager --install "build-tools;36.0.0"
sdkmanager --install "platforms;android-36"
sdkmanager --install "platform-tools;36.0.2"
yes y | sdkmanager --licenses

flutter config --android-sdk /opt/android-sdk
yes y | flutter doctor --android-licenses

#!/usr/bin/env bash
# =====================================================
#  setup.sh — First-time development environment setup
#
#  Supported OS: macOS (Homebrew), Ubuntu/Debian
#  Estimated time: 15–30 minutes depending on download speed
# =====================================================
set -euo pipefail

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; NC='\033[0m'
log()  { echo -e "${GREEN}[setup]${NC} $*"; }
warn() { echo -e "${YELLOW}[warn]${NC}  $*"; }
err()  { echo -e "${RED}[error]${NC} $*"; exit 1; }

OS="$(uname -s)"
log "OS: $OS"

# ─────────────────────────────────────────────
#  1. Install Rust
# ─────────────────────────────────────────────
if ! command -v rustc &>/dev/null; then
  log "Installing Rust..."
  curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
  # shellcheck disable=SC1090
  source "$HOME/.cargo/env"
  log "Rust installed: $(rustc --version)"
else
  log "Rust already installed: $(rustc --version)"
fi

# ─────────────────────────────────────────────
#  2. Add cross-compilation targets
# ─────────────────────────────────────────────
log "Adding Rust cross-compilation targets..."
rustup target add aarch64-linux-android   # Android arm64
rustup target add x86_64-linux-android    # Android x86_64 emulator
rustup target add aarch64-apple-ios 2>/dev/null || warn "iOS target can only be added on macOS"

# ─────────────────────────────────────────────
#  3. Android NDK setup (cargo-ndk)
# ─────────────────────────────────────────────
if ! cargo ndk --version &>/dev/null 2>&1; then
  log "Installing cargo-ndk..."
  cargo install cargo-ndk
fi
log "cargo-ndk: $(cargo ndk --version)"

# ─────────────────────────────────────────────
#  4. Install Flutter
# ─────────────────────────────────────────────
if ! command -v flutter &>/dev/null; then
  log "Installing Flutter..."
  if [[ "$OS" == "Darwin" ]]; then
    # macOS: via Homebrew
    if ! command -v brew &>/dev/null; then
      err "Homebrew not found. Install it from https://brew.sh"
    fi
    brew install --cask flutter
  elif [[ "$OS" == "Linux" ]]; then
    # Linux: via snap (Ubuntu recommended)
    if command -v snap &>/dev/null; then
      sudo snap install flutter --classic
    else
      # snap not found — show manual instructions
      warn "snap not found. Run the following manually:"
      warn "  git clone https://github.com/flutter/flutter.git ~/flutter"
      warn "  export PATH=\"\$PATH:\$HOME/flutter/bin\""
      warn "  flutter doctor"
      warn "Then re-run setup.sh"
      exit 1
    fi
  fi
else
  log "Flutter already installed: $(flutter --version | head -1)"
fi

# ─────────────────────────────────────────────
#  5. Fetch Flutter packages
# ─────────────────────────────────────────────
FLUTTER_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/patchi_wani_flutter"
log "Fetching Flutter packages..."
cd "$FLUTTER_DIR"
flutter pub get
log "Flutter packages ready"

# ─────────────────────────────────────────────
#  6. Verify Android NDK path (optional)
# ─────────────────────────────────────────────
log "Checking Android SDK..."
if [[ -z "${ANDROID_NDK_HOME:-}" ]]; then
  warn "ANDROID_NDK_HOME is not set. For Android builds, add this to your shell profile:"
  warn "  export ANDROID_NDK_HOME=\$HOME/Android/Sdk/ndk/<version>"
  warn "  Or set the NDK linker path in ~/.cargo/config.toml"
  warn "  See SETUP.md Step 4 for details"
else
  log "ANDROID_NDK_HOME=$ANDROID_NDK_HOME"
fi

# ─────────────────────────────────────────────
#  7. Run Rust unit tests (smoke check)
# ─────────────────────────────────────────────
ENGINE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/patchi_wani_engine"
log "Running Rust engine tests..."
cd "$ENGINE_DIR"
cargo test
log "All tests passed!"

# ─────────────────────────────────────────────
#  Done
# ─────────────────────────────────────────────
echo ""
log "========================================"
log "  Setup complete!"
log "========================================"
echo ""
echo "  Next steps:"
echo "  1. Build the Rust engine:"
echo "       cd patchi_wani_engine && cargo build --release"
echo ""
echo "  2. Run the Flutter app on a device:"
echo "       cd patchi_wani_flutter && flutter run"
echo ""
echo "  3. One-command build (APK etc.):"
echo "       chmod +x build_all.sh"
echo "       ./build_all.sh android"
echo ""
echo "  See SETUP.md for full instructions."

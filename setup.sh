#!/usr/bin/env bash
# =====================================================
#  setup.sh — 開発環境のセットアップ（初回のみ実行）
#
#  対応OS: macOS (Homebrew), Ubuntu/Debian
#  所要時間: 15〜30分（ダウンロード速度による）
# =====================================================
set -euo pipefail

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; NC='\033[0m'
log()  { echo -e "${GREEN}[setup]${NC} $*"; }
warn() { echo -e "${YELLOW}[warn]${NC}  $*"; }
err()  { echo -e "${RED}[error]${NC} $*"; exit 1; }

OS="$(uname -s)"
log "OS: $OS"

# ─────────────────────────────────────────────
#  1. Rust のインストール
# ─────────────────────────────────────────────
if ! command -v rustc &>/dev/null; then
  log "Rust をインストール中..."
  curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
  # shellcheck disable=SC1090
  source "$HOME/.cargo/env"
  log "Rust インストール完了: $(rustc --version)"
else
  log "Rust 確認済み: $(rustc --version)"
fi

# ─────────────────────────────────────────────
#  2. クロスコンパイルターゲットの追加
# ─────────────────────────────────────────────
log "Rust クロスコンパイルターゲットを追加..."
rustup target add aarch64-linux-android   # Android (arm64)
rustup target add x86_64-linux-android    # Android (x86_64 エミュレータ)
rustup target add aarch64-apple-ios 2>/dev/null || warn "iOS ターゲットは macOS でのみ追加可能"

# ─────────────────────────────────────────────
#  3. Android NDK セットアップ（cargo-ndk）
# ─────────────────────────────────────────────
if ! cargo ndk --version &>/dev/null 2>&1; then
  log "cargo-ndk をインストール中..."
  cargo install cargo-ndk
fi
log "cargo-ndk: $(cargo ndk --version)"

# ─────────────────────────────────────────────
#  4. Flutter のインストール
# ─────────────────────────────────────────────
if ! command -v flutter &>/dev/null; then
  log "Flutter をインストール中..."
  if [[ "$OS" == "Darwin" ]]; then
    # macOS: Homebrew 経由
    if ! command -v brew &>/dev/null; then
      err "Homebrew が見つかりません。https://brew.sh を参照してインストールしてください"
    fi
    brew install --cask flutter
  elif [[ "$OS" == "Linux" ]]; then
    # Linux: snap 経由（Ubuntu 推奨）
    if command -v snap &>/dev/null; then
      sudo snap install flutter --classic
    else
      # snap がない場合は手動インストール案内
      warn "snap が見つかりません。以下を手動で実行してください:"
      warn "  git clone https://github.com/flutter/flutter.git ~/flutter"
      warn "  export PATH=\"\$PATH:\$HOME/flutter/bin\""
      warn "  flutter doctor"
      warn "インストール後に再度 setup.sh を実行してください"
      exit 1
    fi
  fi
else
  log "Flutter 確認済み: $(flutter --version | head -1)"
fi

# ─────────────────────────────────────────────
#  5. Flutter の依存関係インストール
# ─────────────────────────────────────────────
FLUTTER_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/patchi_wani_flutter"
log "Flutter パッケージを取得中..."
cd "$FLUTTER_DIR"
flutter pub get
log "Flutter パッケージ取得完了"

# ─────────────────────────────────────────────
#  6. Android NDK のパス確認（任意）
# ─────────────────────────────────────────────
log "Android SDK の確認..."
if [[ -z "${ANDROID_NDK_HOME:-}" ]]; then
  warn "ANDROID_NDK_HOME が未設定です。Android ビルドには以下を設定してください:"
  warn "  export ANDROID_NDK_HOME=\$HOME/Android/Sdk/ndk/<version>"
  warn "  または ~/.cargo/config.toml に NDK ツールチェーンのパスを記入してください"
  warn "  詳細は SETUP.md の「Android クロスコンパイル」を参照"
else
  log "ANDROID_NDK_HOME=$ANDROID_NDK_HOME"
fi

# ─────────────────────────────────────────────
#  7. Rust エンジンのテスト実行（動作確認）
# ─────────────────────────────────────────────
ENGINE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/patchi_wani_engine"
log "Rust エンジンのテストを実行中..."
cd "$ENGINE_DIR"
cargo test
log "テスト通過！"

# ─────────────────────────────────────────────
#  完了
# ─────────────────────────────────────────────
echo ""
log "========================================"
log "  セットアップ完了！"
log "========================================"
echo ""
echo "  次のステップ:"
echo "  1. Rust エンジンをビルド:"
echo "       cd patchi_wani_engine && cargo build --release"
echo ""
echo "  2. Flutter アプリをデバイスで実行:"
echo "       cd patchi_wani_flutter && flutter run"
echo ""
echo "  3. 一括ビルド（APK など）:"
echo "       chmod +x build_all.sh"
echo "       ./build_all.sh android"
echo ""
echo "  詳細は SETUP.md を参照してください。"

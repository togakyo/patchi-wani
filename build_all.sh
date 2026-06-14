#!/usr/bin/env bash
# =====================================================
#  build_all.sh — Rust エンジン + Flutter アプリ一括ビルド
#
#  使い方:
#    chmod +x build_all.sh
#    ./build_all.sh [android|ios|linux|all]
#
#  前提: setup.sh を先に実行してください
# =====================================================
set -euo pipefail

TARGET="${1:-all}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENGINE_DIR="$SCRIPT_DIR/patchi_wani_engine"
FLUTTER_DIR="$SCRIPT_DIR/patchi_wani_flutter"

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
log()  { echo -e "${GREEN}[build]${NC} $*"; }
warn() { echo -e "${YELLOW}[warn]${NC}  $*"; }

# ─────────────────────────────────────────────
#  Rust エンジンのビルド（共通）
# ─────────────────────────────────────────────
build_rust_android() {
  log "Rust → Android (arm64-v8a)"
  cd "$ENGINE_DIR"
  cargo build --release --target aarch64-linux-android
  mkdir -p "$FLUTTER_DIR/android/app/src/main/jniLibs/arm64-v8a"
  cp target/aarch64-linux-android/release/libpatchi_wani_engine.so \
     "$FLUTTER_DIR/android/app/src/main/jniLibs/arm64-v8a/"
  log "  → android/app/src/main/jniLibs/arm64-v8a/libpatchi_wani_engine.so"
}

build_rust_ios() {
  log "Rust → iOS (aarch64-apple-ios)"
  cd "$ENGINE_DIR"
  cargo build --release --target aarch64-apple-ios
  mkdir -p "$FLUTTER_DIR/ios/Frameworks"
  cp target/aarch64-apple-ios/release/libpatchi_wani_engine.a \
     "$FLUTTER_DIR/ios/Frameworks/"
  log "  → ios/Frameworks/libpatchi_wani_engine.a"
}

build_rust_linux() {
  log "Rust → Linux (x86_64)"
  cd "$ENGINE_DIR"
  cargo build --release
  mkdir -p "$FLUTTER_DIR/linux/lib"
  cp target/release/libpatchi_wani_engine.so \
     "$FLUTTER_DIR/linux/lib/"
  log "  → linux/lib/libpatchi_wani_engine.so"
}

# ─────────────────────────────────────────────
#  Flutter のビルド
# ─────────────────────────────────────────────
build_flutter_android() {
  log "Flutter → Android APK"
  cd "$FLUTTER_DIR"
  flutter build apk --release
  log "  → build/app/outputs/flutter-apk/app-release.apk"
}

build_flutter_ios() {
  log "Flutter → iOS (requires Xcode on macOS)"
  cd "$FLUTTER_DIR"
  flutter build ios --release --no-codesign
  log "  → build/ios/iphoneos/Runner.app"
}

build_flutter_linux() {
  log "Flutter → Linux"
  cd "$FLUTTER_DIR"
  flutter build linux --release
  log "  → build/linux/x64/release/bundle/"
}

# ─────────────────────────────────────────────
#  Rust ユニットテスト
# ─────────────────────────────────────────────
run_tests() {
  log "Rust ユニットテスト実行"
  cd "$ENGINE_DIR"
  cargo test
  log "  全テスト通過"
}

# ─────────────────────────────────────────────
#  メイン
# ─────────────────────────────────────────────
case "$TARGET" in
  android)
    run_tests
    build_rust_android
    build_flutter_android
    ;;
  ios)
    run_tests
    build_rust_ios
    build_flutter_ios
    ;;
  linux)
    run_tests
    build_rust_linux
    build_flutter_linux
    ;;
  all)
    run_tests
    warn "all を指定した場合、現在の OS に応じたターゲットのみビルドします"
    if [[ "$OSTYPE" == "darwin"* ]]; then
      build_rust_ios
      build_rust_android
      build_flutter_ios
      build_flutter_android
    elif [[ "$OSTYPE" == "linux"* ]]; then
      build_rust_linux
      build_flutter_linux
    else
      warn "Windows は手動で build_all.sh android または ios を実行してください"
    fi
    ;;
  *)
    echo "使い方: $0 [android|ios|linux|all]"
    exit 1
    ;;
esac

log "ビルド完了！"

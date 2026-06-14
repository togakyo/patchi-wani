#!/usr/bin/env bash
# =============================================================
#  doctor.sh — Development environment check for Patchi-Wani
#
#  Usage:
#    chmod +x doctor.sh
#    ./doctor.sh
#
#  Checks:
#    1. Required CLI tools (Rust, Flutter, Dart, cargo-ndk)
#    2. Rust cross-compilation targets
#    3. VS Code + required extensions
#    4. Android / iOS SDK (optional, warns if missing)
#    5. Rust engine (cargo check + unit tests)
#    6. Flutter packages (pub get dry-run)
#    7. Project asset files
#    8. .gitignore hygiene (no build artifacts committed)
#    9. GameRule JSON validity
# =============================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENGINE_DIR="$SCRIPT_DIR/patchi_wani_engine"
FLUTTER_DIR="$SCRIPT_DIR/patchi_wani_flutter"

# ── Colour helpers ────────────────────────────────────────────
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

pass()  { echo -e "  ${GREEN}✔${NC}  $*"; }
warn()  { echo -e "  ${YELLOW}⚠${NC}  $*"; WARN_COUNT=$((WARN_COUNT+1)); }
fail()  { echo -e "  ${RED}✘${NC}  $*"; FAIL_COUNT=$((FAIL_COUNT+1)); }
info()  { echo -e "  ${CYAN}ℹ${NC}  $*"; }
title() { echo -e "\n${BOLD}$*${NC}"; }

WARN_COUNT=0
FAIL_COUNT=0

# =============================================================
#  1. Required CLI tools
# =============================================================
title "1. Required CLI tools"

check_cmd() {
  local cmd="$1" label="$2" hint="$3"
  if command -v "$cmd" &>/dev/null; then
    local ver
    ver=$("$cmd" --version 2>/dev/null | head -1) || ver="(version unknown)"
    pass "$label: $ver"
  else
    fail "$label not found — $hint"
  fi
}

check_cmd rustc   "Rust (rustc)"    "run: curl https://sh.rustup.rs | sh"
check_cmd cargo   "Cargo"           "installed with Rust"
check_cmd flutter "Flutter"         "see https://docs.flutter.dev/get-started/install"
check_cmd dart    "Dart"            "installed with Flutter"

if cargo ndk --version &>/dev/null 2>&1; then
  pass "cargo-ndk: $(cargo ndk --version 2>/dev/null | head -1)"
else
  warn "cargo-ndk not found — needed for Android builds. Run: cargo install cargo-ndk"
fi

# Minimum version checks
RUSTC_VER=$(rustc --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+' | head -1 || echo "0.0")
RUSTC_MAJOR=$(echo "$RUSTC_VER" | cut -d. -f1)
RUSTC_MINOR=$(echo "$RUSTC_VER" | cut -d. -f2)
if [ "$RUSTC_MAJOR" -gt 1 ] || { [ "$RUSTC_MAJOR" -eq 1 ] && [ "$RUSTC_MINOR" -ge 77 ]; }; then
  pass "Rust version >= 1.77 ✓"
else
  fail "Rust version < 1.77 (found $RUSTC_VER) — run: rustup update"
fi

FLUTTER_VER=$(flutter --version 2>/dev/null | grep -oE 'Flutter [0-9]+\.[0-9]+' | grep -oE '[0-9]+\.[0-9]+' | head -1 || echo "0.0")
FLUTTER_MAJOR=$(echo "$FLUTTER_VER" | cut -d. -f1)
FLUTTER_MINOR=$(echo "$FLUTTER_VER" | cut -d. -f2)
if [ "$FLUTTER_MAJOR" -gt 3 ] || { [ "$FLUTTER_MAJOR" -eq 3 ] && [ "$FLUTTER_MINOR" -ge 22 ]; }; then
  pass "Flutter version >= 3.22 ✓"
else
  fail "Flutter version < 3.22 (found $FLUTTER_VER) — run: flutter upgrade"
fi

# =============================================================
#  2. Rust cross-compilation targets
# =============================================================
title "2. Rust cross-compilation targets"

check_target() {
  local target="$1" label="$2"
  if rustup target list --installed 2>/dev/null | grep -q "^$target"; then
    pass "$label ($target)"
  else
    warn "$label not installed — run: rustup target add $target"
  fi
}

check_target "aarch64-linux-android"  "Android arm64"
check_target "x86_64-linux-android"   "Android x86_64 (emulator)"

if [[ "$(uname -s)" == "Darwin" ]]; then
  check_target "aarch64-apple-ios" "iOS arm64"
else
  info "iOS target check skipped (macOS only)"
fi

# =============================================================
#  3. VS Code + extensions
# =============================================================
title "3. VS Code + extensions"

if command -v code &>/dev/null; then
  pass "VS Code: $(code --version 2>/dev/null | head -1)"

  check_ext() {
    local id="$1" label="$2" install_hint="$3"
    if code --list-extensions 2>/dev/null | grep -qi "^${id}$"; then
      pass "Extension: $label"
    else
      warn "Extension missing: $label — run: code --install-extension $install_hint"
    fi
  }

  check_ext "Dart-Code.flutter"        "Flutter"        "Dart-Code.flutter"
  check_ext "Dart-Code.dart-code"      "Dart"           "Dart-Code.dart-code"
  check_ext "rust-lang.rust-analyzer"  "rust-analyzer"  "rust-lang.rust-analyzer"
  check_ext "vadimcn.vscode-lldb"      "CodeLLDB"       "vadimcn.vscode-lldb"

  # Workspace file
  if [ -f "$SCRIPT_DIR/patchi-wani.code-workspace" ]; then
    pass "Workspace file: patchi-wani.code-workspace"
  else
    warn "patchi-wani.code-workspace not found — open the repo as a workspace for best results"
  fi

  # launch.json
  if [ -f "$SCRIPT_DIR/.vscode/launch.json" ]; then
    pass ".vscode/launch.json present"
  else
    warn ".vscode/launch.json not found — debug configurations are missing"
  fi
else
  warn "VS Code (code) not found in PATH — extension checks skipped"
  info "If VS Code is installed, add it to PATH via: Shell Command: Install 'code' command in PATH"
fi

# =============================================================
#  4. Android / iOS SDK (optional)
# =============================================================
title "4. Android / iOS SDK"

if [[ -n "${ANDROID_HOME:-}" ]] || [[ -n "${ANDROID_SDK_ROOT:-}" ]]; then
  local_sdk="${ANDROID_HOME:-$ANDROID_SDK_ROOT}"
  pass "ANDROID_HOME set: $local_sdk"
else
  warn "ANDROID_HOME / ANDROID_SDK_ROOT not set — needed for Android builds"
fi

if [[ -n "${ANDROID_NDK_HOME:-}" ]]; then
  pass "ANDROID_NDK_HOME set: $ANDROID_NDK_HOME"
  if [ -d "$ANDROID_NDK_HOME" ]; then
    pass "NDK directory exists"
  else
    fail "ANDROID_NDK_HOME points to a missing directory: $ANDROID_NDK_HOME"
  fi
else
  warn "ANDROID_NDK_HOME not set — needed for Rust → Android cross-compilation"
  info "See SETUP.md Step 4 for instructions"
fi

if [[ "$(uname -s)" == "Darwin" ]]; then
  if command -v xcodebuild &>/dev/null; then
    pass "Xcode: $(xcodebuild -version 2>/dev/null | head -1)"
  else
    warn "Xcode not found — needed for iOS builds"
  fi
else
  info "Xcode check skipped (macOS only)"
fi

# =============================================================
#  5. Rust engine
# =============================================================
title "5. Rust engine (cargo check + tests)"

if [ -f "$ENGINE_DIR/Cargo.toml" ]; then
  pass "Cargo.toml found"

  echo ""
  info "Running cargo check..."
  if cargo check --manifest-path "$ENGINE_DIR/Cargo.toml" --quiet 2>/dev/null; then
    pass "cargo check passed"
  else
    fail "cargo check failed — run: cd patchi_wani_engine && cargo check"
  fi

  echo ""
  info "Running cargo test..."
  if cargo test --manifest-path "$ENGINE_DIR/Cargo.toml" --quiet 2>/dev/null; then
    pass "All Rust unit tests passed"
  else
    fail "Rust tests failed — run: cd patchi_wani_engine && cargo test"
  fi

  # clippy (warn only)
  if cargo clippy --manifest-path "$ENGINE_DIR/Cargo.toml" -- -D warnings &>/dev/null 2>&1; then
    pass "cargo clippy: no warnings"
  else
    warn "cargo clippy reported issues — run: cd patchi_wani_engine && cargo clippy"
  fi
else
  fail "patchi_wani_engine/Cargo.toml not found — is the repository complete?"
fi

# =============================================================
#  6. Flutter packages
# =============================================================
title "6. Flutter packages"

if [ -f "$FLUTTER_DIR/pubspec.yaml" ]; then
  pass "pubspec.yaml found"

  echo ""
  info "Running flutter pub get..."
  if flutter pub get --directory "$FLUTTER_DIR" &>/dev/null 2>/dev/null; then
    pass "flutter pub get succeeded"
  else
    fail "flutter pub get failed — run: cd patchi_wani_flutter && flutter pub get"
  fi

  # dart analyze
  echo ""
  info "Running dart analyze..."
  if dart analyze "$FLUTTER_DIR" --fatal-infos &>/dev/null 2>/dev/null; then
    pass "dart analyze: no issues"
  else
    warn "dart analyze found issues — run: dart analyze patchi_wani_flutter"
  fi
else
  fail "patchi_wani_flutter/pubspec.yaml not found — is the repository complete?"
fi

# =============================================================
#  7. Project asset files
# =============================================================
title "7. Project asset files"

check_file() {
  local path="$1" label="$2"
  if [ -f "$path" ]; then
    pass "$label"
  else
    fail "$label missing: $path"
  fi
}

check_file "$FLUTTER_DIR/assets/game_rule_default.json" "game_rule_default.json"
check_file "$ENGINE_DIR/src/lib.rs"                     "lib.rs (Rust engine)"
check_file "$FLUTTER_DIR/lib/main.dart"                 "main.dart"
check_file "$FLUTTER_DIR/lib/game/engine_ffi.dart"      "engine_ffi.dart"
check_file "$FLUTTER_DIR/lib/game/game_controller.dart" "game_controller.dart"

# audio placeholder check
AUDIO_DIR="$FLUTTER_DIR/assets/audio"
if [ -d "$AUDIO_DIR" ]; then
  pass "assets/audio/ directory exists"
  if [ -f "$AUDIO_DIR/hit.mp3" ]; then
    info "Custom hit.mp3 found"
  else
    info "No hit.mp3 yet — placeholder sound will be used"
  fi
else
  warn "assets/audio/ directory missing"
fi

# =============================================================
#  8. .gitignore hygiene
# =============================================================
title "8. .gitignore hygiene"

if [ -f "$SCRIPT_DIR/.gitignore" ]; then
  pass ".gitignore present"

  checks=(
    "patchi_wani_engine/target"
    "patchi_wani_flutter/build"
    "patchi_wani_flutter/.dart_tool"
  )
  for pattern in "${checks[@]}"; do
    if grep -qF "$pattern" "$SCRIPT_DIR/.gitignore"; then
      pass ".gitignore covers: $pattern"
    else
      warn ".gitignore may be missing: $pattern"
    fi
  done

  # Warn if Rust build artifacts exist but aren't gitignored
  if [ -d "$ENGINE_DIR/target" ]; then
    info "patchi_wani_engine/target/ exists (will be excluded by .gitignore)"
  fi
else
  fail ".gitignore not found"
fi

# =============================================================
#  9. GameRule JSON validity
# =============================================================
title "9. GameRule JSON validity"

RULE_JSON="$FLUTTER_DIR/assets/game_rule_default.json"
if [ -f "$RULE_JSON" ]; then
  if python3 -c "import json,sys; d=json.load(open(sys.argv[1])); \
      assert 'duration_secs' in d and 'appear_ms' in d \
         and 'threshold_1'   in d and 'threshold_2' in d \
         and 'target_sizes'  in d and len(d['target_sizes'])==3, \
      'Missing required keys'" "$RULE_JSON" 2>/dev/null; then
    pass "game_rule_default.json is valid JSON with all required keys"
  else
    fail "game_rule_default.json is invalid or missing required keys"
    info "Required: duration_secs, appear_ms, threshold_1, threshold_2, target_sizes[3]"
  fi
else
  fail "game_rule_default.json not found"
fi

# =============================================================
#  Summary
# =============================================================
echo ""
echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

if [ "$FAIL_COUNT" -eq 0 ] && [ "$WARN_COUNT" -eq 0 ]; then
  echo -e "${GREEN}${BOLD}  All checks passed! Ready to develop. 🐊${NC}"
elif [ "$FAIL_COUNT" -eq 0 ]; then
  echo -e "${YELLOW}${BOLD}  $WARN_COUNT warning(s), 0 failures.${NC}"
  echo -e "  Warnings are non-blocking — the project should run."
else
  echo -e "${RED}${BOLD}  $FAIL_COUNT failure(s), $WARN_COUNT warning(s).${NC}"
  echo -e "  Fix the ✘ items above before running the app."
fi

echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# Exit non-zero if there are hard failures
[ "$FAIL_COUNT" -eq 0 ]

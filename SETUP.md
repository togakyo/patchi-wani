# SETUP.md — Detailed Build Instructions

> For a quick start, see [README.md](./README.md).

## Requirements

| Tool | Min version | Purpose |
|------|-------------|---------|
| Rust | 1.77+ | Game engine (BE) |
| Flutter | 3.22+ | UI (FE) |
| Android Studio | Latest | Android build & emulator |
| Xcode | 15+ | iOS build (macOS only) |
| Android NDK | r25c+ | Rust → Android cross-compilation |

---

## Step 1 — Automated setup (recommended)

```bash
cd patchi-wani
chmod +x setup.sh
./setup.sh
```

This installs Rust and Flutter, fetches packages, and runs the Rust unit tests.

---

## Step 2 — Verify the Rust engine

```bash
cd patchi_wani_engine

# Run unit tests
cargo test

# Debug build
cargo build

# Release build
cargo build --release
```

If `cargo test` passes, the Rust side is working correctly.

---

## Step 3 — Run the Flutter app on a simulator

```bash
cd patchi_wani_flutter

# List connected devices and simulators
flutter devices

# Run (select a device or pass -d <device-id>)
flutter run
```

> **Note:** At this stage the Rust `.so` / `.a` library does not exist yet,
> so `EngineFFI` will throw an `UnsupportedError`.
> Complete Step 4 to build the library, then restart the app.

---

## Step 4 — Android cross-compilation

### 4-1. Install the Android NDK

Open Android Studio:

```
SDK Manager → SDK Tools → NDK (Side by side) → Apply
```

### 4-2. Set the NDK path environment variable

```bash
# Add to ~/.zshrc or ~/.bashrc
export ANDROID_NDK_HOME="$HOME/Library/Android/sdk/ndk/25.2.9519653"  # macOS example
# Linux: export ANDROID_NDK_HOME="$HOME/Android/Sdk/ndk/25.2.9519653"

source ~/.zshrc
```

### 4-3. Build the Rust library for Android

```bash
cd patchi_wani_engine

# Use cargo-ndk (recommended — resolves the linker automatically)
cargo ndk -t arm64-v8a build --release

# Copy the .so into the Flutter project
cp target/aarch64-linux-android/release/libpatchi_wani_engine.so \
   ../patchi_wani_flutter/android/app/src/main/jniLibs/arm64-v8a/
```

### 4-4. Build the Flutter APK

```bash
cd ../patchi_wani_flutter
flutter build apk --release
```

Output: `build/app/outputs/flutter-apk/app-release.apk`

---

## Step 5 — iOS build (macOS only)

### 5-1. Add the iOS target

```bash
rustup target add aarch64-apple-ios
```

### 5-2. Build the Rust static library for iOS

```bash
cd patchi_wani_engine
cargo build --release --target aarch64-apple-ios

cp target/aarch64-apple-ios/release/libpatchi_wani_engine.a \
   ../patchi_wani_flutter/ios/Frameworks/
```

### 5-3. Link the library in Xcode

Open `patchi_wani_flutter/ios/Runner.xcworkspace` in Xcode:

1. Runner → Build Phases → Link Binary With Libraries
2. `+` → `Add Other...` → select `ios/Frameworks/libpatchi_wani_engine.a`
3. Build Settings → Other Linker Flags → add `-lc++`

### 5-4. Build the Flutter iOS app

```bash
cd patchi_wani_flutter
flutter build ios --release --no-codesign
```

---

## Step 6 — One-command builds

```bash
cd patchi-wani
chmod +x build_all.sh

./build_all.sh android   # Android APK
./build_all.sh ios       # iOS (macOS only)
./build_all.sh linux     # Linux desktop
```

---

## Repository layout

```
patchi-wani/
│
├── patchi_wani_engine/          # Rust game engine (BE)
│   ├── Cargo.toml
│   ├── .cargo/
│   │   └── config.toml          # Cross-compilation linker config (template)
│   └── src/
│       └── lib.rs               # C ABI exports + game logic
│
├── patchi_wani_flutter/         # Flutter app (FE)
│   ├── pubspec.yaml
│   ├── assets/
│   │   ├── audio/               # Place .mp3 sound files here
│   │   ├── images/              # Place character images here
│   │   └── game_rule_default.json
│   ├── android/
│   │   └── app/src/main/
│   │       └── jniLibs/
│   │           └── arm64-v8a/
│   │               └── libpatchi_wani_engine.so  ← copied after Rust build
│   ├── ios/
│   │   └── Frameworks/
│   │       └── libpatchi_wani_engine.a           ← copied after Rust build
│   └── lib/
│       ├── main.dart
│       ├── game/
│       │   ├── engine_ffi.dart       # dart:ffi bridge
│       │   └── game_controller.dart
│       ├── scratch/
│       │   └── block_model.dart      # Block definitions + JSON conversion
│       └── screens/
│           ├── game_screen.dart
│           └── block_editor_screen.dart
│
├── setup.sh                     # First-time setup script
├── build_all.sh                 # One-command build script
└── SETUP.md                     # This file
```

---

## Troubleshooting

### `DynamicLibrary.open` — Cannot open shared library

The Rust library has not been built yet, or was copied to the wrong path.
Re-run Step 4-3 and verify the destination path.

### `engine_init` returns -1

JSON parse error in `GameRule`. Check that `game_rule_default.json` is valid JSON.

### `cargo ndk` not found

```bash
cargo install cargo-ndk
```

### Flutter `ffi` package error

```bash
cd patchi_wani_flutter
flutter pub get
```

### Rust tests fail

```bash
cd patchi_wani_engine
cargo test -- --nocapture   # show log output
```

---

## Customization

For character, sound, and block editor customization, see [README.md](./README.md#customization).

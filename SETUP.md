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

# Generate platform files (first time only)
flutter create . --platforms android   # add --platforms ios on macOS if needed

# List connected devices and simulators
flutter devices

# Run on a specific device (use the device id shown by flutter devices)
flutter run -d emulator-5554   # example — replace with your device id
```

> **Note:** At this stage the Rust `.so` / `.a` library does not exist yet,
> so `EngineFFI` will throw an `UnsupportedError`.
> Complete Step 4 to build the library, then restart the app.

> **Web is not supported.** This project uses `dart:ffi` to call the Rust engine,
> which is incompatible with the web platform. Use an Android emulator or iOS simulator.

---

## Step 4 — Android cross-compilation

### 4-1. Install the Android NDK

Open Android Studio:

```
SDK Manager → SDK Tools → NDK (Side by side) → Apply
```

### 4-2. Set the NDK path environment variable

```bash
# Check which NDK version was installed
ls ~/Library/Android/sdk/ndk/   # e.g. 26.1.10909125

# Add to ~/.zshrc or ~/.bashrc (replace the version number with the output above)
export ANDROID_NDK_HOME="$HOME/Library/Android/sdk/ndk/26.1.10909125"  # macOS example
# Linux: export ANDROID_NDK_HOME="$HOME/Android/Sdk/ndk/26.1.10909125"

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

### 5-1. Install Xcode and add Rust targets

Install Xcode from the App Store, then:

```bash
sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer
sudo xcodebuild -runFirstLaunch

rustup target add aarch64-apple-ios        # physical device
rustup target add aarch64-apple-ios-sim    # simulator (Apple Silicon Mac)
```

### 5-2. Generate iOS platform files

```bash
cd patchi_wani_flutter
flutter create . --platforms ios
```

### 5-3. Build the Rust static library

**For simulator:**

```bash
cd patchi_wani_engine
cargo build --release --target aarch64-apple-ios-sim

mkdir -p ../patchi_wani_flutter/ios/Frameworks
cp target/aarch64-apple-ios-sim/release/libpatchi_wani_engine.a \
   ../patchi_wani_flutter/ios/Frameworks/
```

**For physical device:**

```bash
cargo build --release --target aarch64-apple-ios

cp target/aarch64-apple-ios/release/libpatchi_wani_engine.a \
   ../patchi_wani_flutter/ios/Frameworks/
```

### 5-4. Link the library via xcconfig

> **Do NOT use Xcode's Build Phases GUI** — it corrupts `project.pbxproj`.

`ios/Flutter/Debug.xcconfig` と `ios/Flutter/Release.xcconfig` の両方に以下を追記：

```
OTHER_LDFLAGS = $(inherited) -force_load $(SRCROOT)/Frameworks/libpatchi_wani_engine.a -lc++
```

### 5-5. Run on iOS Simulator

```bash
# List available simulators
xcrun simctl list devices available | grep "iOS"

# Boot a simulator (replace <device-id> with the ID shown above)
xcrun simctl boot <device-id>

# Run the Flutter app
cd patchi_wani_flutter
flutter run -d <device-id>
```

> **Note:** `open -a Simulator` may not work on some macOS versions. Use `xcrun simctl boot` instead.

> **Note:** Do not run `pod install` manually on Xcode 26+ — CocoaPods may fail to parse the project file. Use `flutter run` directly and let Flutter handle pod setup.

### 5-6. Build the Flutter iOS app (release)

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

### `Build failed due to use of deleted Android v1 embedding`

Android platform files are missing. Run the following to generate them:

```bash
cd patchi_wani_flutter
flutter create . --platforms android
```

### `flutter run -d android` — No supported devices found

Pass the device id directly instead of `android`:

```bash
flutter devices          # find the id (e.g. emulator-5554)
flutter run -d emulator-5554
```

### `Failed to lookup symbol engine_init`

The Rust library is not linked. Do NOT use Xcode's Build Phases GUI — it corrupts `project.pbxproj`.
Instead, add the following to both `ios/Flutter/Debug.xcconfig` and `ios/Flutter/Release.xcconfig`:

```
OTHER_LDFLAGS = $(inherited) -force_load $(SRCROOT)/Frameworks/libpatchi_wani_engine.a -lc++
```

### `Building for iOS-simulator, but linking in object file built for iOS`

The `.a` was built for a physical device. Rebuild for the simulator target:

```bash
cd patchi_wani_engine
cargo build --release --target aarch64-apple-ios-sim
cp target/aarch64-apple-ios-sim/release/libpatchi_wani_engine.a \
   ../patchi_wani_flutter/ios/Frameworks/
```

### iOS Simulator not detected by `flutter devices`

```bash
# Find available simulators
xcrun simctl list devices available | grep "iOS"

# Boot the simulator manually
xcrun simctl boot <device-id>
```

### CocoaPods parse error on Xcode 26+

CocoaPods may fail with `Found additional characters after parsing the root plist object`.
Do not run `pod install` manually — use `flutter run` directly and let Flutter handle pod setup.

If `project.pbxproj` is corrupted, regenerate the iOS platform (`.a` is preserved separately):

```bash
cp ios/Frameworks/libpatchi_wani_engine.a /tmp/
rm -rf ios
flutter create . --platforms ios
mkdir -p ios/Frameworks
cp /tmp/libpatchi_wani_engine.a ios/Frameworks/
```

### Rust tests fail

```bash
cd patchi_wani_engine
cargo test -- --nocapture   # show log output
```

---

## Customization

For character, sound, and block editor customization, see [README.md](./README.md#customization).

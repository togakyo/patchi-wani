# SETUP.md — 詳細ビルド手順

> クイックスタートは [README.md](./README.md) を参照してください。

## 必要な環境

| ツール         | 最低バージョン | 用途                        |
|--------------|------------|---------------------------|
| Rust          | 1.77+      | ゲームエンジン（BE）          |
| Flutter       | 3.22+      | UI（FE）                   |
| Android Studio| 最新版      | Android ビルド・エミュレータ   |
| Xcode         | 15+        | iOS ビルド（macOS のみ）     |
| Android NDK   | r25c+      | Rust → Android クロスコンパイル |

---

## 手順 1：自動セットアップ（推奨）

```bash
cd patchi_wani
chmod +x setup.sh
./setup.sh
```

これだけで Rust / Flutter のインストールとパッケージ取得、Rust テストの実行まで完了します。

---

## 手順 2：Rust エンジン単体の動作確認

```bash
cd patchi_wani_engine

# テスト実行（ネイティブ）
cargo test

# デバッグビルド
cargo build

# リリースビルド
cargo build --release
```

`cargo test` が通れば Rust 側のロジックは正常です。

---

## 手順 3：Flutter アプリをシミュレータで起動

```bash
cd patchi_wani_flutter

# 接続済みデバイス / シミュレータ確認
flutter devices

# 起動（デバイスを選択するか -d で指定）
flutter run
```

> **注意**: この段階では Rust の `.so` / `.a` ファイルがないため、
> `EngineFFI` の呼び出しで UnsupportedError が発生します。
> 次の手順でライブラリをビルドしてから再起動してください。

---

## 手順 4：Android 向けクロスコンパイル

### 4-1. Android NDK のインストール

Android Studio を開き：

```
SDK Manager → SDK Tools → NDK (Side by side) にチェック → Apply
```

### 4-2. NDK パスを環境変数に設定

```bash
# ~/.zshrc または ~/.bashrc に追記
export ANDROID_NDK_HOME="$HOME/Library/Android/sdk/ndk/25.2.9519653"  # macOS 例
# Linux: export ANDROID_NDK_HOME="$HOME/Android/Sdk/ndk/25.2.9519653"

source ~/.zshrc
```

### 4-3. Rust → Android ライブラリのビルド

```bash
cd patchi_wani_engine

# cargo-ndk を使う（推奨・自動でリンカーを解決）
cargo ndk -t arm64-v8a build --release

# ビルドされた .so を Flutter プロジェクトにコピー
cp target/aarch64-linux-android/release/libpatchi_wani_engine.so \
   ../patchi_wani_flutter/android/app/src/main/jniLibs/arm64-v8a/
```

### 4-4. Flutter → Android APK のビルド

```bash
cd ../patchi_wani_flutter
flutter build apk --release
```

出力: `build/app/outputs/flutter-apk/app-release.apk`

---

## 手順 5：iOS 向けビルド（macOS のみ）

### 5-1. iOS ターゲットの追加

```bash
rustup target add aarch64-apple-ios
```

### 5-2. Rust → iOS スタティックライブラリのビルド

```bash
cd patchi_wani_engine
cargo build --release --target aarch64-apple-ios

cp target/aarch64-apple-ios/release/libpatchi_wani_engine.a \
   ../patchi_wani_flutter/ios/Frameworks/
```

### 5-3. Xcode プロジェクトへのリンク設定

Xcode で `patchi_wani_flutter/ios/Runner.xcworkspace` を開き：

1. Runner → Build Phases → Link Binary With Libraries
2. `+` → `Add Other...` → `ios/Frameworks/libpatchi_wani_engine.a` を追加
3. Build Settings → Other Linker Flags に `-lc++` を追加

### 5-4. Flutter → iOS ビルド

```bash
cd patchi_wani_flutter
flutter build ios --release --no-codesign
```

---

## 手順 6：一括ビルド（ショートカット）

```bash
cd patchi_wani
chmod +x build_all.sh

# Android のみ
./build_all.sh android

# iOS のみ（macOS）
./build_all.sh ios

# Linux デスクトップのみ
./build_all.sh linux
```

---

## フォルダ構成

```
patchi_wani/
│
├── patchi_wani_engine/          # Rust ゲームエンジン（BE）
│   ├── Cargo.toml
│   ├── .cargo/
│   │   └── config.toml       # クロスコンパイル リンカー設定
│   └── src/
│       └── lib.rs            # C ABI 公開関数 + ゲームロジック
│
├── patchi_wani_flutter/         # Flutter アプリ（FE）
│   ├── pubspec.yaml
│   ├── assets/
│   │   ├── audio/            # 効果音・親御さんの声（.mp3）を置く
│   │   ├── images/           # キャラクター画像を置く
│   │   └── game_rule_default.json
│   ├── android/
│   │   └── app/src/main/
│   │       └── jniLibs/
│   │           └── arm64-v8a/
│   │               └── libpatchi_wani_engine.so  ← Rust ビルド後に配置
│   ├── ios/
│   │   └── Frameworks/
│   │       └── libpatchi_wani_engine.a           ← Rust ビルド後に配置
│   └── lib/
│       ├── main.dart
│       ├── game/
│       │   ├── engine_ffi.dart    # dart:ffi ブリッジ
│       │   └── game_controller.dart
│       ├── scratch/
│       │   └── block_model.dart   # Scratch ブロック定義 + JSON 変換
│       └── screens/
│           ├── game_screen.dart
│           └── block_editor_screen.dart
│
├── setup.sh                  # 初回セットアップスクリプト
├── build_all.sh              # 一括ビルドスクリプト
└── SETUP.md                  # このファイル
```

---

## よくあるエラーと対処

### `DynamicLibrary.open` で `Cannot open shared library` エラー

→ Rust のビルドが完了していないか、`.so` のコピー先が違います。
手順 4-3 を再確認してください。

### `engine_init` が -1 を返す

→ `GameRule.json` のパースエラーです。
`game_rule_default.json` の JSON が正しいか確認してください。

### `cargo ndk` コマンドが見つからない

```bash
cargo install cargo-ndk
```

### Flutter で `ffi` パッケージのエラー

```bash
cd patchi_wani_flutter
flutter pub get
```

### Rust のテストが失敗する

```bash
cd patchi_wani_engine
cargo test -- --nocapture  # ログを表示して原因を確認
```

---

## カスタマイズ

キャラクター変更・音声差し替え・ブロックエディタの使い方は [README.md](./README.md#カスタマイズ親御さん向け) を参照してください。

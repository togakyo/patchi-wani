# 🐊 パッチワニを捕まえろ！

**弱視治療中のお子さん（3〜6歳）向け、アイパッチ訓練ゲームです。**

画面に現れるワニをすばやくタップして、楽しみながら**注視訓練・手眼協調運動**を行います。
アイパッチの時間を「特別な変身タイム」に変えることを目指しています。

> ⚠️ **本アプリは治療の補助ツールです。必ず眼科医の指導のもとでご使用ください。**

---

## スクリーンショット

<!-- スクリーンショットが用意できたら以下を差し替えてください -->
```
[スタート画面]     [ゲーム画面]       [ブロックエディタ]   [結果画面]
  🐊               🎯               🟪🟩🟨              🏆
  パッチワニを      ━━ 12点 ━━       ブロックで           よくできました！
  捕まえろ！        のこり 42秒       ルールを変えよう      15 てん
```

---

## 特徴

- **60秒の短時間設計** — 幼児の集中力とアイパッチ導入のハードルを考慮
- **自動難易度調整** — スコアに応じてターゲットが小さくなり、より高い注視を促す
- **Scratch風ブロックエディタ** — お子さん自身がルールをカスタマイズできる
- **親御さんの声に差し替え可能** — 効果音を録音した声に変更できる設計
- **高コントラスト設計** — 弱視の視覚刺激に配慮した配色（背景 `#0D1117`、ターゲット `#FF3B30`）

---

## アーキテクチャ

```
Flutter (FE)  ←─ dart:ffi ─→  Rust Engine (BE)
     │                               │
     └── Scratch Block Editor        └── GameRule JSON
         ブロック → JSON → Rust           ゲームロジック・当たり判定
```

| レイヤー | 技術 | 役割 |
|--------|------|------|
| フロントエンド | Flutter (Dart) | UI・タッチ操作・ブロックエディタ |
| ブリッジ | `dart:ffi` | Flutter ↔ Rust 間の C ABI 呼び出し |
| バックエンド | Rust | ゲームループ・スコア管理・難易度計算 |
| データ | JSON / SQLite | ルール設定・訓練ログ |

---

## 必要な環境

| ツール | 最低バージョン | 用途 |
|--------|------------|------|
| Rust | 1.77+ | ゲームエンジン（BE） |
| Flutter | 3.22+ | UI（FE） |
| Android Studio | 最新版 | Android ビルド・エミュレータ |
| Xcode | 15+ | iOS ビルド（macOS のみ） |
| Android NDK | r25c+ | Rust → Android クロスコンパイル |

---

## クイックスタート

```bash
git clone https://github.com/<your-username>/patchi-wani.git
cd patchi-wani

# 1. 環境セットアップ（初回のみ・約15〜30分）
chmod +x setup.sh && ./setup.sh

# 2. Rust エンジンのテスト確認
cd patchi_wani_engine && cargo test && cd ..

# 3. Flutter アプリ起動（シミュレータ）
cd patchi_wani_flutter && flutter run
```

詳細なビルド手順（Android APK・iOS）は **[SETUP.md](./SETUP.md)** を参照してください。

---

## リポジトリ構成

```
patchi-wani/
├── patchi_wani_engine/       # 🦀 Rust ゲームエンジン
│   ├── Cargo.toml
│   └── src/lib.rs            # C ABI 公開 + ゲームロジック + ユニットテスト
│
├── patchi_wani_flutter/      # 🐦 Flutter アプリ
│   ├── lib/
│   │   ├── game/             # FFI ブリッジ・ゲームコントローラ
│   │   ├── scratch/          # Scratch ブロック定義・JSON 変換
│   │   └── screens/          # ゲーム画面・ブロックエディタ画面
│   └── assets/
│       ├── audio/            # 効果音（ここに mp3 を置く）
│       └── images/           # キャラクター画像（ここに置く）
│
├── setup.sh                  # 環境セットアップスクリプト
├── build_all.sh              # 一括ビルドスクリプト
├── SETUP.md                  # 詳細ビルド手順
├── CONTRIBUTING.md           # コントリビュートガイド
└── LICENSE                   # MIT License
```

---

## カスタマイズ（親御さん向け）

### ワニを別のキャラクターに変える

`patchi_wani_flutter/lib/screens/game_screen.dart` の `_Target` ウィジェット内の絵文字を変更します。

```dart
// 変更前
child: Text('🐊', style: TextStyle(fontSize: size * 0.44)),

// 変更後（例：恐竜に）
child: Text('🦖', style: TextStyle(fontSize: size * 0.44)),
```

画像ファイルを使う場合は `assets/images/` に置いて `Image.asset()` に変更してください。

### 親御さんの声を効果音にする

1. 「すごい！」「やったね！」などを録音して `assets/audio/hit.mp3` として保存
2. 「よくできました！」などを録音して `assets/audio/fanfare.mp3` として保存
3. `game_screen.dart` の `// CUSTOMIZE` コメント箇所を以下のように変更：

```dart
// audioplayers パッケージを使用
final player = AudioPlayer();
await player.play(AssetSource('audio/hit.mp3'));
```

### ブロックでゲームルールを変える

アプリ起動後、スタート画面の **「⚙ ルールをかえる」** ボタンからブロックエディタを開けます。
ドラッグ＆ドロップでブロックを並べ替えるだけでゲーム時間・難易度しきい値・ターゲットサイズを変更できます。

---

## 今後の拡張予定

- [ ] **追従モード** — ターゲットが画面を横断・縦断して動くモード（追従性眼球運動の訓練）
- [ ] **図地分離モード** — 背景にノイズを加えてターゲットを見つけにくくするモード
- [ ] **訓練ログ** — 日々のスコアをグラフで確認できる機能（SQLite 実装済み）
- [ ] **iOS / Android 向けビルド自動化** — GitHub Actions による CI

---

## コントリビュート

バグ報告・機能提案は [Issues](https://github.com/<your-username>/patchi-wani/issues) へ。
プルリクエストも歓迎です。詳細は [CONTRIBUTING.md](./CONTRIBUTING.md) を参照してください。

---

## ライセンス

[MIT License](./LICENSE)

---

## 免責事項

本アプリは弱視治療の**補助ツール**であり、医療機器ではありません。
治療方針については必ず担当の眼科医にご相談ください。

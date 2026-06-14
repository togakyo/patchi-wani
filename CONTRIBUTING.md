# コントリビュートガイド

パッチワニプロジェクトへの貢献を歓迎します。

## バグ報告・機能提案

[GitHub Issues](https://github.com/<your-username>/patchi-wani/issues) からお気軽にどうぞ。

バグ報告の際は以下を含めると助かります。

- OS・Flutter バージョン・対象デバイス
- 再現手順
- 期待する動作と実際の動作

## プルリクエストの手順

```bash
# 1. フォーク後、ローカルにクローン
git clone https://github.com/<your-username>/patchi-wani.git
cd patchi-wani

# 2. セットアップ
chmod +x setup.sh && ./setup.sh

# 3. ブランチを切る（例）
git checkout -b fix/target-spawn-timing

# 4. 変更・テスト
cd patchi_wani_engine && cargo test   # Rust テスト
cd ../patchi_wani_flutter && flutter test  # Flutter テスト

# 5. コミットしてプッシュ
git add . && git commit -m "fix: ターゲットのスポーン間隔を修正"
git push origin fix/target-spawn-timing
```

## コーディング規約

- Rust: `cargo fmt` と `cargo clippy` を通してください
- Dart: `dart format` を通してください
- コミットメッセージは [Conventional Commits](https://www.conventionalcommits.org/ja/) に準拠してください（`fix:` `feat:` `docs:` など）

## 注意事項

- 著作権のある画像・音声素材はリポジトリに含めないでください
- 個人情報（録音した声など）を誤ってコミットしないよう `.gitignore` を確認してください
- 医療的な有効性に関する主張は慎重に。本アプリはあくまで治療の補助ツールです

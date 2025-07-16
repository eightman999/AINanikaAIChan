# 手動作業ガイド - Xcodeプロジェクトセットアップ

## 現在の状況
以下の自動化作業が完了しています：
- ✅ ソースコードとリソースの物理的なコピー
- ✅ Info.plistの設定内容の確認
- ✅ コードの修正（AINanikaAIChanApp.swift、GhostManager.swift）

## 手動作業が必要な項目

### 1. Info.plistの設定（高優先度）
Xcodeプロジェクトを開いて以下の設定を追加してください：

**手順:**
1. Xcodeでプロジェクトを開く
2. 左側のプロジェクトナビゲータで、プロジェクトファイル（青いアイコン）を選択
3. TARGETS → AINanikaAIChan を選択
4. 「Info」タブをクリック
5. 「Custom macOS Application Target Properties」で以下を追加：

**設定項目:**
- `LSUIElement` (Boolean) = YES
- `NSAppleEventsUsageDescription` (String) = "SHIORIプロセスとの通信に必要です"
- `NSAppTransportSecurity` (Dictionary)
  - `NSAllowsArbitraryLoads` (Boolean) = YES

### 2. ファイルをXcodeプロジェクトに追加（高優先度）
以下のファイルをXcodeプロジェクトに追加してください：

**手順:**
1. Xcodeのプロジェクトナビゲータで右クリック → "Add Files to AINanikaAIChan"
2. 以下のファイルを選択して追加：
   - `AppDelegate.swift`
   - `GhostManager.swift`
   - `SHIORIClient.swift`
   - `CharacterWindowController.swift`
   - `SakuraScriptParser.swift`
   - `main.swift`

### 3. リソースファイルの重複エラー解決（高優先度）
現在、config.jsonとdescript.txtの重複エラーが発生しています。

**手順:**
1. Build Phases → Copy Bundle Resources を開く
2. 重複している個別ファイルを削除
3. Finderで `AINanikaAIChan/Resources/AINanikaAIChan/` を開く
4. `ghost`, `shiori`, `shell` フォルダをXcodeにドラッグ＆ドロップ
5. **重要:** "Create folder references" を選択（青いフォルダアイコンになる）

### 4. Build Settingsの設定（中優先度）
**手順:**
1. プロジェクト → Build Settings
2. 以下を設定：
   - Deployment Target: macOS 14.0
   - Architectures: x86_64
   - Swift Language Version: Swift 5

### 5. Build Phasesの設定（中優先度）
**手順:**
1. Build Phases → + → New Run Script Phase
2. 以下のスクリプトを追加：
```bash
chmod +x "${BUILT_PRODUCTS_DIR}/${PRODUCT_NAME}.app/Contents/Resources/AINanikaAIChan/shiori/MacUkagaka.SHIORI"
```

## 作業完了後の確認
すべての手動作業完了後、以下のコマンドでビルドテストを実行してください：

```bash
xcodebuild build -scheme AINanikaAIChan -destination 'platform=macOS'
```

## 問題発生時の対処
エラーが発生した場合は、エラーメッセージを確認して以下をチェック：
1. ファイルの参照が正しく追加されているか
2. リソースファイルの重複がないか
3. Build Settingsが正しく設定されているか

## 次のステップ
手動作業完了後は、アプリケーションの実行テストに進みます。
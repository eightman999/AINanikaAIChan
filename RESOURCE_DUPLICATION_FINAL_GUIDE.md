# リソースファイル重複エラー - 完全解決ガイド

## 完了した作業

### ✅ 1. 問題分析とGeminiコンサルティング
- リソースファイルの重複エラー原因を特定
- ディレクトリ構造を維持する解決方法を策定

### ✅ 2. コード側の修正完了
`GhostManager.swift` のリソースパス解決ロジックを修正：

**修正前:**
```swift
bundleResourceURL.appendingPathComponent("AINanikaAIChan/ghost")
bundleResourceURL.appendingPathComponent("AINanikaAIChan/shiori/MacUkagaka.SHIORI")
```

**修正後:**
```swift
bundleResourceURL.appendingPathComponent("ghost")
bundleResourceURL.appendingPathComponent("shiori/MacUkagaka.SHIORI")
```

### ✅ 3. 解決方法ドキュメント作成
- `RESOURCE_DUPLICATION_SOLUTION.md` - 詳細な解決手順
- カスタムビルドスクリプトの作成

## 残りの手動作業

### 🔧 1. Xcodeプロジェクトでの設定変更（必須）

**ステップ1: 既存のリソース参照を削除**
1. Xcodeで `AINanikaAIChan.xcodeproj` を開く
2. プロジェクト → TARGETS → AINanikaAIChan → Build Phases
3. "Copy Bundle Resources" から以下を削除：
   - `AINanikaAIChan` フォルダ
   - ghost, shell, shiori に関連するファイル

**ステップ2: カスタムビルドスクリプトを追加**
1. Build Phases → + → New Run Script Phase
2. "Copy Bundle Resources" の**直前**に移動
3. 以下のスクリプトを追加：

```bash
# Appバンドル内のリソースのコピー先ディレクトリ
DEST_DIR="${BUILT_PRODUCTS_DIR}/${PRODUCT_NAME}.app/Contents/Resources"

# プロジェクト内のリソースのソースディレクトリ
SOURCE_DIR="${PROJECT_DIR}/AINanikaAIChan/Resources/AINanikaAIChan"

# ghost フォルダをコピー
if [ -d "${SOURCE_DIR}/ghost" ]; then
  echo "Copying ghost directory..."
  rsync -av --delete "${SOURCE_DIR}/ghost/" "${DEST_DIR}/ghost/"
else
  echo "Warning: ${SOURCE_DIR}/ghost not found."
fi

# shell フォルダをコピー
if [ -d "${SOURCE_DIR}/shell" ]; then
  echo "Copying shell directory..."
  rsync -av --delete "${SOURCE_DIR}/shell/" "${DEST_DIR}/shell/"
else
  echo "Warning: ${SOURCE_DIR}/shell not found."
fi

# shiori フォルダをコピー
if [ -d "${SOURCE_DIR}/shiori" ]; then
  echo "Copying shiori directory..."
  rsync -av --delete "${SOURCE_DIR}/shiori/" "${DEST_DIR}/shiori/"
  # SHIORIファイルに実行権限を付与
  chmod +x "${DEST_DIR}/shiori/MacUkagaka.SHIORI"
else
  echo "Warning: ${SOURCE_DIR}/shiori not found."
fi
```

### 🔧 2. その他の必要な設定

**ファイルのプロジェクト追加:**
- AppDelegate.swift
- GhostManager.swift
- SHIORIClient.swift
- CharacterWindowController.swift
- SakuraScriptParser.swift
- main.swift

**Info.plist設定:**
- `LSUIElement` = YES
- `NSAppleEventsUsageDescription` = "SHIORIプロセスとの通信に必要です"
- `NSAppTransportSecurity` → `NSAllowsArbitraryLoads` = YES

## 期待される結果

### ✅ 解決される問題
- config.json の重複エラー解消
- descript.txt の重複エラー解消
- ディレクトリ構造の維持

### ✅ 実現される構造
```
AINanikaAIChan.app/Contents/Resources/
├── ghost/
│   ├── config.json
│   ├── descript.txt
│   └── ...
├── shell/
│   ├── descript.txt
│   └── ...
└── shiori/
    ├── config.json
    ├── MacUkagaka.SHIORI
    └── ...
```

## 次のステップ

1. **手動作業の実行** - 上記のXcode設定を完了
2. **CLIビルドテスト** - `xcodebuild build -scheme AINanikaAIChan -destination 'platform=macOS'`
3. **動作確認** - アプリケーションの起動とゴーストの動作確認

## 重要なポイント

- **rsyncコマンド**: 末尾のスラッシュが重要
- **スクリプトの順序**: Copy Bundle Resources の**直前**に配置
- **権限設定**: SHIORIファイルの実行権限を自動付与
- **パス解決**: コードはBundle.main.resourceURLから直接アクセス

これで重複エラーが完全に解決されます。
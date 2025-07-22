# Phase 1: Xcodeプロジェクトセットアップ完全ガイド

## 前提条件の確認

### システム要件
- **macOS**: Sonoma 14.0以降
- **Xcode**: 15.0以降
- **Swift**: 5.9以降
- **Command Line Tools**: 最新版
- **.NET**: 8.0以降

### 必要なアカウント
- **Apple Developer Program**: 配布時に必要（開発のみなら不要）
- **Apple ID**: App Store Connectアクセス用（配布時）

### 前提条件確認コマンド
```bash
# macOSバージョン確認
sw_vers

# Xcodeバージョン確認
xcodebuild -version

# Swift バージョン確認
swift --version

# .NET バージョン確認
dotnet --version
```

## 手順1: プロジェクトの準備

### 1.1 現在のプロジェクト構造確認
```bash
cd /Users/eightman/Desktop/AINanikaAIChan
ls -la MacUkagaka/
```

### 1.2 バックアップ作成
```bash
# プロジェクト全体のバックアップ
cp -r MacUkagaka MacUkagaka_backup_$(date +%Y%m%d_%H%M%S)
```

### 1.3 現在のビルドが正常か確認
```bash
cd MacUkagaka
swift build
swift run
```

## 手順2: Xcodeプロジェクトの作成

### 2.1 新しいXcodeプロジェクトの作成
1. **Xcodeを起動**
2. **"Create a new Xcode project"を選択**
3. **macOS → App を選択**
4. **プロジェクト設定:**
   - Product Name: `AINanikaAIChan`
   - Team: あなたのDeveloper Team
   - Organization Identifier: `com.yourname.ainanikaichan`
   - Bundle Identifier: `com.yourname.ainanikaichan`
   - Language: Swift
   - Interface: AppKit
   - Use Core Data: チェックなし
   - Include Tests: チェックあり

### 2.2 プロジェクトの保存場所
```
/Users/eightman/Desktop/AINanikaAIChan/AINanikaAIChan.xcodeproj
```

## 手順3: ソースコードの統合

### 3.1 既存のSwiftファイルをXcodeプロジェクトに追加
1. **Xcodeでプロジェクトを開く**
2. **File → Add Files to "AINanikaAIChan"**
3. **以下のファイルを選択してコピー:**
   ```
   MacUkagaka/MacUkagaka/AppDelegate.swift
   MacUkagaka/MacUkagaka/GhostManager.swift
   MacUkagaka/MacUkagaka/SHIORIClient.swift
   MacUkagaka/MacUkagaka/CharacterWindow.swift
   MacUkagaka/MacUkagaka/SakuraScript.swift
   MacUkagaka/MacUkagaka/CharacterWindowController.swift
   MacUkagaka/MacUkagaka/SpriteRenderer.swift
   ```

### 3.2 リソースファイルの統合
1. **プロジェクトナビゲーターで右クリック → New Group**
2. **グループ名: "Resources"**
3. **File → Add Files to "AINanikaAIChan"**
4. **以下のフォルダを選択してコピー:**
   ```
   MacUkagaka/MacUkagaka/Resources/AINanikaAIChan
   ```

## 手順4: プロジェクト設定の調整

### 4.1 Build Settings の設定
1. **プロジェクトを選択 → Build Settings**
2. **重要な設定項目:**
   - **Deployment Target**: macOS 14.0
   - **Swift Language Version**: Swift 5
   - **Architectures**: x86_64 (Intel Mac用)
   - **Valid Architectures**: x86_64

### 4.2 Info.plist の設定
```xml
<key>NSAppTransportSecurity</key>
<dict>
    <key>NSAllowsArbitraryLoads</key>
    <true/>
</dict>
<key>LSUIElement</key>
<true/>
<key>NSAppleEventsUsageDescription</key>
<string>This app uses Apple Events to communicate with SHIORI.</string>
```

### 4.3 Bundle Resources の設定
1. **Target → Build Phases → Copy Bundle Resources**
2. **以下のリソースを追加:**
   - `AINanikaAIChan/ghost/` フォルダ
   - `AINanikaAIChan/shiori/` フォルダ
   - `AINanikaAIChan/shell/` フォルダ

### 4.4 Signing & Capabilities の設定
1. **Target を選択 → Signing & Capabilities**
2. **Team**: `XBT5U5CHS8` (あなたのDeveloper Team ID)
3. **`+ Capability` をクリックし `Hardened Runtime` を追加**
4. **同様に `App Groups` を追加し `group.com.eightman.sstp` を登録**

## 手順5: Build Phases の設定

### 5.1 Run Script Phase の追加
1. **Target → Build Phases → + → New Run Script Phase**
2. **スクリプト内容:**
```bash
# .NET SHIORIファイルに実行権限を付与
chmod +x "${BUILT_PRODUCTS_DIR}/${PRODUCT_NAME}.app/Contents/Resources/AINanikaAIChan/shiori/MacUkagaka.SHIORI"
```

### 5.2 Copy Files Phase の追加
1. **Target → Build Phases → + → New Copy Files Phase**
2. **Destination**: Resources
3. **追加するファイル**: AINanikaAIChan リソースフォルダ全体

## 手順6: コードの修正

### 6.1 AppDelegate.swift の修正
```swift
// main.swift (新規作成)
import AppKit

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
```

### 6.2 Bundle resource path の修正
```swift
// GhostManager.swift内の getDefaultGhostPath() を以下に修正
private static func getDefaultGhostPath() throws -> String {
    if let bundleResourceURL = Bundle.main.resourceURL {
        let ghostPath = bundleResourceURL.appendingPathComponent("AINanikaAIChan/ghost").path
        if FileManager.default.fileExists(atPath: ghostPath) {
            return ghostPath
        }
    }
    throw GhostError.bundleResourceNotFound
}
```

## 手順7: テストとデバッグ

### 7.1 ビルドテスト
```bash
# Xcodeでビルド
⌘ + B (Build)

# コンソールでエラーを確認
⌘ + Shift + C (Console)
```

### 7.2 実行テスト
```bash
# Xcodeで実行
⌘ + R (Run)

# デバッグモードで実行
⌘ + Shift + R (Debug)
```

## トラブルシューティング

### 問題1: CPUアーキテクチャエラー
**エラー**: "Bad CPU type in executable"
**解決方法**:
1. **Build Settings → Architectures → x86_64 に設定**
2. **.NET SHIORIを x86_64 で再ビルド:**
```bash
cd MacUkagaka.SHIORI
dotnet publish -c Release -r osx-x64 --self-contained
```

### 問題2: リソースファイルの重複エラー
**エラー**: "Multiple resources named 'descript.txt'"
**解決方法**:
1. **Build Phases → Copy Bundle Resources でリソースを確認**
2. **重複しているリソースを削除**
3. **フォルダごとコピーする設定に変更**

### 問題3: Bundle Resource が見つからない
**エラー**: "bundleResourceNotFound"
**解決方法**:
1. **リソースパスを確認:**
```swift
print("Bundle resource URL: \(Bundle.main.resourceURL?.path ?? "Not found")")
```
2. **Build Phases → Copy Bundle Resources で正しく追加されているか確認**

### 問題4: SHIORI プロセスが起動しない
**エラー**: "processNotStarted"
**解決方法**:
1. **実行権限を確認:**
```bash
ls -l /path/to/MacUkagaka.SHIORI
```
2. **Run Script Phase で権限付与を確認**
3. **ファイルパスが正しいか確認**

## 検証手順

### 検証1: ビルドの成功確認
```bash
# 1. Clean Build
⌘ + Shift + K (Clean Build Folder)

# 2. Build
⌘ + B (Build)

# 3. エラーがないことを確認
# Build Succeeded が表示されることを確認
```

### 検証2: アプリケーションの起動テスト
```bash
# 1. アプリケーションの起動
⌘ + R (Run)

# 2. 以下を確認:
# - アプリケーションが起動する
# - エラーダイアログが表示されない
# - コンソールにエラーが出力されない
```

### 検証3: ゴーストの動作確認
```bash
# 1. キャラクターウィンドウが表示されることを確認
# 2. マウスクリック反応を確認
# 3. 時間経過による発話を確認
# 4. SHIORIプロセスが正常に動作することを確認
```

### 検証4: パフォーマンステスト
```bash
# 1. CPU使用率を確認
# アクティビティモニタで確認

# 2. メモリ使用量を確認
# Xcode → Debug → Memory Report

# 3. 長時間動作テスト
# 1時間以上の連続稼働テスト
```

## 次のPhaseへの準備

### Phase 2への準備事項
1. **UIデザインの準備**
   - 設定画面の設計
   - メニューバーアイコンの設計
   - 通知システムの設計

2. **配布準備の初期設定**
   - App Store Connect の設定
   - Code Signing の設定
   - Notarization の準備

### 設定ファイルの準備
```bash
# 設定ファイルのテンプレート作成
mkdir -p ~/Documents/AINanikaAIChan/Settings
touch ~/Documents/AINanikaAIChan/Settings/app_settings.json
```

## 重要な注意事項

### セキュリティ
- **API キーを含むファイルは配布版に含めない**
- **Code Signing は必ず実施する**
- **Notarization は配布前に必須**

### パフォーマンス
- **メモリリークの定期的なチェック**
- **CPU使用率の監視**
- **長時間動作テストの実施**

### 配布準備
- **Apple Developer Program への登録**
- **App Store Connect の設定**
- **配布証明書の取得**

## 完了確認チェックリスト

- [ ] Xcodeプロジェクトが正常に作成された
- [ ] すべてのソースファイルが統合された
- [ ] リソースファイルが正しく追加された
- [ ] Build Settings が適切に設定された
- [ ] Info.plist が正しく設定された
- [ ] Build Phases が適切に設定された
- [ ] アプリケーションが正常にビルドされる
- [ ] アプリケーションが正常に起動する
- [ ] ゴーストが正常に動作する
- [ ] SHIORIプロセスが正常に動作する
- [ ] パフォーマンステストが完了した
- [ ] 長時間動作テストが完了した

## サポートとヘルプ

### 問題が発生した場合
1. **エラーメッセージを正確に記録**
2. **再現手順を明確にする**
3. **システム環境を確認する**
4. **バックアップから復元する**

### 参考資料
- [Apple Developer Documentation](https://developer.apple.com/documentation/)
- [Swift Package Manager Guide](https://swift.org/package-manager/)
- [Xcode User Guide](https://developer.apple.com/library/archive/documentation/ToolsLanguages/Conceptual/Xcode_Overview/)
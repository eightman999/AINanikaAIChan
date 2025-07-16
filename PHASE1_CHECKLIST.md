# Phase 1: Xcodeプロジェクトセットアップ - 作業チェックリスト

## 📋 概要
Swift Package Managerプロジェクトを完全なmacOSアプリケーションとして配布可能なXcodeプロジェクトに変換します。

---

## 🔧 事前準備（必須）

### ✅ 開発環境確認
- [ ] **Xcode最新版**がインストールされている
- [ ] **.NET SDK**が正しくインストールされている
  ```bash
  dotnet --version  # 確認コマンド
  ```
- [ ] **Command Line Tools**がインストールされている
  ```bash
  xcode-select --install  # 必要な場合
  ```

### ✅ プロジェクト状態確認
- [ ] `MacUkagaka/Package.swift`が存在する
- [ ] `MacUkagaka.SHIORI/`が正常にビルドできる
- [ ] `ghost/`と`shell/`ディレクトリが存在する

---

## 📱 Step 1: Xcodeプロジェクト基本設定

### ✅ プロジェクト作成
1. [ ] **Xcodeで`MacUkagaka/Package.swift`を開く**
   - Finderから`Package.swift`をXcodeアイコンにドラッグ＆ドロップ
   - またはXcodeから`File > Open`で選択

2. [ ] **macOSアプリターゲットを追加**
   - `File > New > Target...`
   - `macOS > App`を選択
   - プロダクト名: `AINanikaAIChan`
   - Interface: `SwiftUI`
   - Life Cycle: `SwiftUI App`
   - Language: `Swift`

### ✅ 基本プロジェクト設定
3. [ ] **Deployment Targetの設定**
   - プロジェクト設定 > `Info`タブ
   - `macOS Deployment Target`: `macOS 12.0`（推奨）

4. [ ] **依存関係の確認**
   - アプリターゲットの`Build Phases > Link Binary With Libraries`
   - `MacUkagaka`ライブラリが追加されていることを確認

---

## 🏷️ Step 2: Bundle設定

### ✅ Info.plist設定
5. [ ] **Bundle Identifier設定**
   - アプリターゲット > `Signing & Capabilities`
   - Bundle Identifier: `com.yourcompany.ainanikaaichan`
   - ⚠️ **重要**: 実際のドメインまたは適切な識別子を使用

6. [ ] **基本情報設定**
   - アプリターゲット > `Info`タブで以下を設定:
   - [ ] `Bundle Name`: `AINanikaAIChan`
   - [ ] `Bundle Version`: `1`
   - [ ] `Bundle Version String (Short)`: `1.0.0`
   - [ ] `Copyright (human-readable)`: `© 2025 Your Name`
   - [ ] `Application Category`: `public.app-category.utilities`

### ✅ セキュリティ設定
7. [ ] **App Sandboxの設定**
   - `Signing & Capabilities`タブ
   - `+ Capability`をクリック
   - `App Sandbox`を追加
   - ⚠️ **注意**: 開発中は無効でも可（配布時は必須）

8. [ ] **Hardened Runtimeの設定**
   - 同様に`Hardened Runtime`を追加
   - ⚠️ **注意**: 公証(Notarization)に必須

---

## 📦 Step 3: リソース準備

### ✅ .NET SHIORIビルド
9. [ ] **自己完結型ビルドの実行**
   ```bash
   cd MacUkagaka.SHIORI
   
   # Apple Silicon (M1/M2) Mac の場合
   dotnet publish -c Release --runtime osx-arm64 --self-contained true -p:PublishSingleFile=true
   
   # Intel Mac の場合
   dotnet publish -c Release --runtime osx-x64 --self-contained true -p:PublishSingleFile=true
   ```

10. [ ] **ビルド結果の確認**
    - `bin/Release/netX.X/osx-arm64/publish/MacUkagaka.SHIORI`が生成される
    - 実行ファイルのサイズが妥当（通常50-100MB程度）

### ✅ リソースの整理
11. [ ] **リソースディレクトリの準備**
    - [ ] `ghost/`フォルダの内容確認
    - [ ] `shell/`フォルダの内容確認
    - [ ] 不要な一時ファイルの削除

---

## 🔗 Step 4: Xcodeプロジェクトへの統合

### ✅ リソースの追加
12. [ ] **Resourcesグループの作成**
    - Xcodeのプロジェクトナビゲーターで右クリック
    - `New Group`を選択
    - グループ名: `Resources`

13. [ ] **リソースファイルの追加**
    - [ ] **SHIORI実行ファイル**をXcodeに追加
      - `publish/MacUkagaka.SHIORI`をResourcesグループにドラッグ
      - `Copy items if needed`にチェック
      - アプリターゲットに追加
    
    - [ ] **ghost/ディレクトリ**をXcodeに追加
      - `Create folder references`を選択（重要）
      - アプリターゲットに追加
    
    - [ ] **shell/ディレクトリ**をXcodeに追加
      - `Create folder references`を選択（重要）
      - アプリターゲットに追加

### ✅ ビルド設定の確認
14. [ ] **Bundle Resourcesの確認**
    - アプリターゲット > `Build Phases > Copy Bundle Resources`
    - 追加したリソースがすべて含まれているか確認

---

## 🧪 Step 5: 初期テスト

### ✅ ビルドテスト
15. [ ] **プロジェクトのビルド**
    - `Product > Build` (⌘+B)
    - エラーなくビルドが完了する

16. [ ] **実行テスト**
    - `Product > Run` (⌘+R)
    - アプリケーションが起動する（機能は未完成でも可）

### ✅ リソースアクセステスト
17. [ ] **Bundle内リソースの確認**
    ```swift
    // テストコード例
    if let resourcesURL = Bundle.main.resourceURL {
        print("Resources URL: \(resourcesURL)")
        let shioriURL = resourcesURL.appendingPathComponent("MacUkagaka.SHIORI")
        print("SHIORI exists: \(FileManager.default.fileExists(atPath: shioriURL.path))")
    }
    ```

---

## 📋 完了確認

### ✅ 最終チェック
18. [ ] **プロジェクト構造確認**
    ```
    AINanikaAIChan/
    ├── MacUkagaka/           # 元のSwiftコード
    ├── Resources/            # Xcodeプロジェクト内
    │   ├── MacUkagaka.SHIORI # .NET実行ファイル
    │   ├── ghost/            # ゴーストデータ
    │   └── shell/            # シェル画像
    ```

19. [ ] **設定値の確認**
    - Bundle Identifier: 適切に設定済み
    - Deployment Target: 設定済み
    - リソース: 正しく追加済み

20. [ ] **ビルド・実行確認**
    - エラーなくビルド完了
    - アプリケーションが起動する

---

## 🚨 トラブルシューティング

### よくある問題と解決策

**問題**: .NET SHIORIのビルドが失敗する
**解決策**: 
```bash
dotnet restore
dotnet clean
dotnet publish -c Release --runtime osx-arm64 --self-contained true -p:PublishSingleFile=true
```

**問題**: リソースがBundle内に含まれない
**解決策**: 
- `Build Phases > Copy Bundle Resources`を確認
- `Create folder references`で追加したか確認

**問題**: Bundle Identifierエラー
**解決策**: 
- 逆ドメイン形式で設定 (例: `com.yourname.ainanikaaichan`)
- 特殊文字を避ける

---

## 📝 次のステップ

Phase 1完了後：
- [ ] **Phase 2**: リソース管理システム実装へ進む
- [ ] **ResourceManagerクラス**の実装準備
- [ ] **プロセス管理**の設計開始

---

## 📞 サポート

問題が発生した場合：
1. エラーメッセージを記録
2. Xcodeのビルドログを確認
3. 実装計画書の該当セクションを参照

**Phase 1推定完了時間**: 2-3日
**次のマイルストーン**: リソース管理システムの実装開始
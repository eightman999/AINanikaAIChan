# Phase 1: 事前準備（必須）詳細ガイド

## 📋 現在の環境確認結果

### ✅ 環境確認済み項目
- **Xcode Command Line Tools**: `/Applications/Xcode.app/Contents/Developer` ✓
- **Swift**: Apple Swift version 6.1 (最新版) ✓
- **.NET SDK**: 6.0.301 (プロジェクト要件の.NET 6.0対応) ✓
- **プロジェクトファイル**: Package.swift、.csproj確認済み ✓

---

## 🔧 1. 開発環境確認（詳細）

### Xcode & Swift
- **必要バージョン**: Xcode 15.3以降推奨
- **現在の環境**: Swift 6.1 (最新版で問題なし)
- **対応macOS**: macOS Sonoma以降
- **確認コマンド**:
  ```bash
  xcode-select -p
  # 期待結果: /Applications/Xcode.app/Contents/Developer
  
  swift --version
  # 期待結果: Apple Swift version 6.1以降
  ```

### .NET SDK
- **必要バージョン**: .NET 6.0以降
- **現在の環境**: .NET 6.0.301 ✓
- **プロジェクト設定**: `<TargetFramework>net6.0</TargetFramework>`
- **確認コマンド**:
  ```bash
  dotnet --list-sdks
  # 期待結果: 6.0.x以降が含まれている
  ```

---

## 📁 2. プロジェクト状態確認

### ✅ 確認済み項目

#### MacUkagaka (Swift)
- **場所**: `/Users/eightman/Desktop/AINanikaAIChan/MacUkagaka/Package.swift`
- **プラットフォーム**: `macOS(.v12)` - macOS 12.0以降対応
- **依存関係**: なし（依存関係解決済み）
- **確認結果**: 
  ```bash
  cd MacUkagaka && swift package resolve
  # 結果: エラーなし（正常）
  ```

#### MacUkagaka.SHIORI (.NET)
- **場所**: `/Users/eightman/Desktop/AINanikaAIChan/MacUkagaka.SHIORI/`
- **ターゲット**: `.NET 6.0`
- **ビルド状態**: 正常（エラーなし）
- **確認結果**:
  ```bash
  cd MacUkagaka.SHIORI && dotnet build
  # 結果: ビルドに成功しました。 0 個の警告 0 エラー
  ```

#### リソースファイル
- **ghost/ディレクトリ**: `/Users/eightman/Desktop/AINanikaAIChan/ghost/master/`
- **shell/ディレクトリ**: `/Users/eightman/Desktop/AINanikaAIChan/shell/master/`
- **画像ファイル**: 100枚以上のPNGファイル確認済み
- **設定ファイル**: `descript.txt`、`surfaces.txt`存在確認済み

---

## ⚠️ 3. 発見された注意点

### 📂 プロジェクト構造について
現在のプロジェクト構造は以下のようになっています：
```
AINanikaAIChan/
├── MacUkagaka/              # Swift UIアプリケーション
│   ├── Package.swift        # Swift Package設定
│   └── MacUkagaka/          # Swiftソースコード
├── MacUkagaka.SHIORI/       # .NET SHIORIサーバー
│   ├── MacUkagaka.SHIORI.csproj
│   └── Program.cs
├── ghost/master/            # ゴーストデータ
└── shell/master/            # キャラクター画像
```

### 🔄 作業ディレクトリについて
- **重要**: 作業は`/Users/eightman/Desktop/AINanikaAIChan/MacUkagaka/`で行います
- Phase 1では、このSwift Packageプロジェクトを macOSアプリケーションに変換します

---

## 🚨 4. 事前準備でのトラブルシューティング

### 問題1: Command Line Toolsのパスが正しくない
**症状**: `xcode-select -p` が `/Library/Developer/CommandLineTools` を返す
**解決策**:
```bash
sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
```

### 問題2: .NET SDKのバージョンが古い
**症状**: `dotnet --list-sdks` に6.0.xが含まれない
**解決策**:
1. [Microsoft .NET公式サイト](https://dotnet.microsoft.com/download)から .NET 6.0 SDK をダウンロード
2. インストール後、`dotnet --list-sdks` で確認

### 問題3: Swift Packageの依存関係エラー
**症状**: `swift package resolve` でエラーが発生
**解決策**:
```bash
cd MacUkagaka
swift package clean
swift package resolve
```

### 問題4: .NET SHIORIのビルドエラー
**症状**: `dotnet build` で復元エラー
**解決策**:
```bash
cd MacUkagaka.SHIORI
dotnet restore
dotnet clean
dotnet build
```

---

## 🎯 5. 次のステップ準備

### Phase 1で使用する主要ファイル
1. **MacUkagaka/Package.swift** - Swift Package設定
2. **MacUkagaka.SHIORI/bin/Debug/net6.0/** - ビルド済み.NET実行ファイル
3. **ghost/master/** - ゴーストデータ
4. **shell/master/** - キャラクター画像

### 準備完了チェック
- [ ] Swift Package が正常に解決できる
- [ ] .NET SHIORI が正常にビルドできる
- [ ] ghost/とshell/のリソースファイルが存在する
- [ ] 開発環境が要件を満たしている

---

## 📝 バージョン互換性マトリックス

| 項目 | 最小要件 | 推奨 | 現在の環境 |
|------|----------|------|------------|
| macOS | 12.0 | 14.0以降 | ✓ |
| Xcode | 15.0 | 15.3以降 | ✓ |
| Swift | 5.7 | 6.0以降 | ✓ Swift 6.1 |
| .NET | 6.0 | 6.0以降 | ✓ .NET 6.0.301 |

---

## 🔍 詳細確認コマンド集

### 環境確認
```bash
# システム情報
sw_vers
xcode-select -p
swift --version
dotnet --info

# プロジェクト確認
cd MacUkagaka && swift package dump-package
cd MacUkagaka.SHIORI && dotnet list package
```

### ビルドテスト
```bash
# Swift Package ビルド
cd MacUkagaka && swift build

# .NET SHIORI ビルド
cd MacUkagaka.SHIORI && dotnet build -c Release
```

### リソース確認
```bash
# ファイル数確認
find ghost/master -name "*.csx" | wc -l    # C#スクリプト
find shell/master -name "*.png" | wc -l    # 画像ファイル

# 重要ファイル確認
ls -la ghost/master/descript.txt
ls -la shell/master/surfaces.txt
```

---

## ✅ 事前準備完了確認

すべての項目が✓であることを確認してください：

- [ ] **開発環境**: Xcode、Swift、.NET SDK正常動作
- [ ] **プロジェクト**: Swift Package、.NET SHIORI正常ビルド
- [ ] **リソース**: ghost/、shell/ディレクトリ存在確認
- [ ] **権限**: 必要なディレクトリへの読み書き権限
- [ ] **作業準備**: `/Users/eightman/Desktop/AINanikaAIChan/MacUkagaka/` で作業開始可能

**事前準備完了！Phase 1のXcodeプロジェクトセットアップを開始できます。**
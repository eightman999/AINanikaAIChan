# MacUkagaka

macOS用の伺か互換アプリケーション

## 概要

MacUkagakaは、macOS上で動作する伺か互換のデスクトップマスコットアプリケーションです。既存のWindowsベースの伺かゴーストとシェルデータを活用して、macOS環境でキャラクターを表示・操作できます。

## 特徴

- **透明ウィンドウ**: 背景透過でキャラクターのみを表示
- **最前面表示**: 他のアプリケーションの上に常に表示
- **SHIORI通信**: 外部スクリプト（Python, C#）との通信対応
- **SakuraScript**: 基本的なSakuraScript制御コードの解釈
- **バルーン表示**: 会話文とセリフの表示
- **マウス操作**: キャラクターへのクリック操作対応

## 動作環境

- macOS 12.0以降
- Swift 5.7以降
- Apple Silicon / Intel両対応

## インストール方法

1. プロジェクトをクローンまたはダウンロード
2. プロジェクトディレクトリに移動
3. Swift Package Managerでビルド

```bash
cd MacUkagaka
swift build
```

## 使用方法

1. ゴーストとシェルデータを配置
2. アプリケーションを実行

```bash
swift run
```

## プロジェクト構造

```
MacUkagaka/
├── MacUkagaka/
│   ├── main.swift                    # アプリケーションエントリーポイント
│   ├── AppDelegate.swift             # アプリケーションライフサイクル管理
│   ├── GhostManager.swift            # ゴースト管理とSHIORIとの統合
│   ├── SHIORIClient.swift           # SHIORIプロトコル実装
│   ├── SakuraScriptParser.swift     # SakuraScript解析とアクション生成
│   ├── CharacterWindowController.swift # 透明ウィンドウとキャラクター表示
│   └── Resources/
├── Package.swift                     # Swift Package設定
└── README.md
```

## 技術仕様

### 実装済み機能

1. **基本ウィンドウ実装**
   - 透明背景 (`NSColor.clear`)
   - 最前面表示 (`NSWindow.level = .floating`)
   - 非矩形ウィンドウ (`NSWindow.StyleMask.borderless`)

2. **ゴースト管理**
   - `descript.txt`の解析
   - ゴースト情報の読み込み
   - SHIORI実行ファイルの管理

3. **SHIORI通信**
   - HTTP風プロトコル実装
   - 標準入出力による通信
   - Python/C#スクリプト対応

4. **SakuraScript解析**
   - 基本制御コード (`\\h`, `\\u`, `\\s[n]`, `\\n`, `\\e`)
   - ウェイト処理 (`\\_w[n]`)
   - 選択肢表示 (`\\q[text,id]`)

5. **キャラクター表示**
   - PNG画像の透過表示
   - Surface切り替え
   - 画像サイズによる自動ウィンドウ調整

6. **バルーン表示**
   - 会話文の表示
   - 自動消去タイマー
   - 選択肢UI

### 対応SHIORIイベント

- `OnBoot`: アプリケーション起動時
- `OnMouseClick`: キャラクターへのクリック時
- `OnSecondChange`: 毎秒実行（定期処理）
- `OnClose`: アプリケーション終了時

### 対応SakuraScript

- `\\h`: メインキャラクター（さくら）のスコープ
- `\\u`: サブキャラクター（うにゅう）のスコープ
- `\\s[n]`: Surface（表情）をnに変更
- `\\n`: 改行
- `\\_w[n]`: nミリ秒待機
- `\\q[text,id]`: 選択肢表示
- `\\e`: スクリプト終了

## 制限事項

- WindowsのDLLファイルは直接実行不可
- C#スクリプトの実行には.NET Core が必要
- surfaces.txtの複雑な合成機能は未実装
- アニメーション機能は未実装

## 今後の拡張予定

- 複数ゴーストの同時実行
- surfaces.txtの完全対応
- アニメーション機能
- 設定ファイルによる永続化
- プラグイン機構

## ライセンス

このプロジェクトは、MITライセンスの下で公開されています。

## 貢献

プルリクエストやイシューの報告を歓迎します。

## 関連リンク

- [伺かとは](https://ukagaka.jp/)
- [SSP (Sakura Script Player)](http://ssp.shillest.net/)
- [SakuraScript仕様](https://ssp.shillest.net/ukadoc/manual/manual_sakura_script.html)
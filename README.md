# AI何かちゃん & MacUkagaka

## プロジェクト概要

このリポジトリには2つの主要なプロジェクトが含まれています：

### 1. AI何かちゃん（Windows向け伺かゴースト）
ChatGPTを伺かに組み込んだゴーストです。
AI君にはAI何かちゃんとして振る舞ってもらっています。
デフォルトでは気だるげなダウナー系理系お姉さん「アイ」として振る舞い、ユーザーのことを「後輩くん」と呼びます。
クリスマスを「ニュートンの日」と言ってはばからない、少し皮肉屋な性格です。

現在は ChatGPT のほか、 Claude と Gemini も利用できます。
利用には選択した AI サービスの API キーが必要です。
設定メニューからサービスを選択し、各 API キーを入力してください。

### 2. MacUkagaka（macOS向け伺か互換アプリケーション）
macOS上で動作する伺か互換のデスクトップマスコットアプリケーションです。
Swift + AppKitで実装され、既存のゴーストとシェルデータを活用できます。

**主要機能**:
- 透明ウィンドウでのキャラクター表示
- SHIORIプロトコル対応（Python/C#スクリプト実行）
- SakuraScript基本パーサー
- バルーン表示機能
- マウスクリック対応

**詳細ドキュメント**: [MacUkagaka/README.md](MacUkagaka/README.md)

## ディレクトリ構成

```
AINanikaAIChan/
├── README.md                    # このファイル
├── ghost/                       # ゴーストデータ
│   └── master/
│       ├── descript.txt         # ゴースト設定
│       ├── test_shiori.py       # テスト用SHIORI
│       └── (その他SHIORIファイル)
├── shell/                       # シェルデータ（キャラクター画像）
│   └── master/
│       ├── descript.txt         # シェル設定
│       ├── surfaces.txt         # Surface定義
│       └── *.png                # 画像ファイル
├── MacUkagaka/                  # macOS向け伺か互換アプリ
│   ├── README.md                # MacUkagaka詳細情報
│   ├── Package.swift            # Swift Package設定
│   ├── MacUkagaka/              # ソースコード
│   └── (ドキュメント)
├── geminicli.py                 # Gemini CLI (Python)
├── geminicli.csx                # Gemini CLI (C#)
├── geminicli.sh                 # Unix系ラッパー
└── geminicli.bat                # Windows系ラッパー
```

## 使用方法

### Windows（AI何かちゃん）
1. SSP（Sakura Script Player）をインストール
2. このリポジトリをゴーストディレクトリに配置
3. 各AIサービスのAPIキーを設定
4. ゴーストを起動

### macOS（MacUkagaka）
1. Xcodeまたはコマンドラインツールをインストール
2. リポジトリをクローン
3. MacUkagakaディレクトリに移動
4. `swift run` でアプリケーションを実行

詳細は [MacUkagaka/README.md](MacUkagaka/README.md) を参照してください。

## GeminiCLIの利用

`geminicli.py` (Python) または `geminicli.csx` (C#) を使うとコマンドラインから Gemini API にアクセスできます。
`geminicli.sh` (Unix系) や `geminicli.bat` (Windows) を使うと、スクリプトの有無を確認して自動で実行してくれます。

### Python版
```bash
python3 geminicli.py "質問内容" --api-key YOUR_API_KEY
```

### C#版
```bash
dotnet script geminicli.csx "質問内容" --api-key YOUR_API_KEY
```

### ラッパースクリプト
Unix系では `./geminicli.sh`、Windowsでは `geminicli.bat` を実行すると、
`geminicli.py` または `geminicli.csx` が存在する場合に自動で呼び出します。

API キーを環境変数 `GEMINI_API_KEY` に設定している場合は `--api-key` オプションを省略できます。
実行時にコンソール操作の許可を確認するプロンプトが表示され、`y` を入力すると送信が行われます。

## MacUkagaka.SHIORI (.NET Core)

`MacUkagaka.SHIORI` ディレクトリには、macOS でも動作する C# 製 SHIORI の実装を配置しています。
以下のようにビルドして実行できます。

```bash
dotnet build MacUkagaka.SHIORI/MacUkagaka.SHIORI.csproj
cd MacUkagaka.SHIORI
dotnet run
```

設定ファイル `config.json` に各 AI サービスの API キーとモデル名を記述してください。

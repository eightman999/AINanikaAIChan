# リポジトリ構成

このドキュメントでは、本リポジトリに含まれる主なファイルやディレクトリを簡単に説明します。

## ルートに存在する主な項目

- `README.md` – AI何かちゃんの概要と利用方法
- `CHANGELOG.md` – 更新履歴
- `LICENSE` – ライセンス条項
- `THIRD-PARTY-LIBRARIES.md` – 利用している外部ライブラリ一覧
- `geminicli.py`, `geminicli.csx`, `geminicli.sh`, `geminicli.bat` – Gemini API を操作する CLI ツール
- `ghost/` – ゴーストの C# スクリプトと設定類
- `shell/` – 画像リソースやサーフェス定義
- `developer_options.txt`, `install.txt` – 開発者向け/インストールに関するメモ
- `readme-shiolink.txt` – SHIOLINK のドキュメント
- `updates.txt`, `updates2.dau` – 更新情報
- `aisisteraichan.gif` – デモ用 GIF

## `ghost` ディレクトリ

ゴーストのメインロジックが格納されています。

```
ghost/
  master/
    ChatGPT.csx          # ChatGPT インターフェース
    CollisionParts.csx   # 衝突判定定義
    Ghost.csx            # メインスクリプト
    GhostBootClose.csx   # 起動・終了処理
    GhostMenu.csx        # メニュー処理
    Log.csx              # ログ関連
    Newtonsoft.Json.dll  # 依存ライブラリ
    Rosalind.CSharp.exe  # Rosalind 実行ファイル
    Rosalind.dll
    Rosalind.xml
    SaveData.csx         # ユーザーデータ管理
    SurfaceCategory.csx  # サーフェスカテゴリ
    Surfaces.csx         # サーフェス管理
    SHIOLINK.INI         # SHIOLINK 設定
    descript.txt         # ゴースト説明文
    updates.txt          # 更新情報
    updates2.dau
```

## `shell` ディレクトリ

ゴースト用の画像アセットを格納しています。`master` サブディレクトリには、サーフェスやアニメーションを定義する 100 枚以上の PNG ファイルがあり、`descript.txt` と `surfaces.txt` で説明されています。

```
shell/
  master/
    000_000.png
    ...
    surface10.png
    "surface1000 .png"
    descript.txt
    surfaces.txt
```

各 PNG ファイルはゴーストで使用されるサーフェス画像に対応します。

# AI何かちゃん
![動画](./aisisteraichan.gif)
## これは何？
ChatGPTを伺かに組み込んだゴーストです。
AI君にはAI何かちゃんとして振る舞ってもらっています。
デフォルトでは気だるげなダウナー系理系お姉さん「アイ」として振る舞い、ユーザーのことを「後輩くん」と呼びます。
クリスマスを「ニュートンの日」と言ってはばからない、少し皮肉屋な性格です。

現在は ChatGPT のほか、 Claude と Gemini も利用できます。
利用には選択した AI サービスの API キーが必要です。
設定メニューからサービスを選択し、各 API キーを入力してください。

## GeminiCLIの利用
`geminicli.py` (Python) または `geminicli.csx` (C#) を使うとコマンドラインから Gemini API にアクセスできます。

### Python版
```
python3 geminicli.py "質問内容" --api-key YOUR_API_KEY
```

### C#版
```
dotnet script geminicli.csx "質問内容" --api-key YOUR_API_KEY
```

API キーを環境変数 `GEMINI_API_KEY` に設定している場合は `--api-key` オプションを省略できます。
実行時にコンソール操作の許可を確認するプロンプトが表示され、`y` を入力すると送信が行われます。

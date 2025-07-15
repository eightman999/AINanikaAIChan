# 優先実装タスク

## 今後2週間の重点作業

### 🚀 Phase 1: 基盤整備（Week 1-2）

#### 最優先タスク（今週実施）

1. **C#版SHIORIの.NET Core移行調査**
   - 既存の`ChatGPT.csx`、`Rosalind.CSharp.exe`の分析
   - .NET 6/8での動作確認
   - 依存関係の整理（Newtonsoft.Json.dll等）
   - macOS環境での実行テスト

2. **MacUkagakaの安定化**
   - 現在のSHIORIClient.swiftの通信エラー修正
   - タイムアウト処理の改善
   - メモリリーク対策
   - エラーハンドリングの強化

3. **共通設定フォーマットの設計**
   - Windows版とmacOS版の設定統一
   - APIキー管理方式の決定
   - 設定ファイルの暗号化検討

#### 次優先タスク（来週実施）

4. **基本的なAI API統合**
   - ChatGPT APIの基本統合
   - API抽象化レイヤーの実装
   - エラーハンドリングとリトライ機能

5. **テスト環境の構築**
   - 単体テストの作成
   - 統合テストの実装
   - CI/CDパイプラインの検討

---

## 具体的な実装作業

### Task 1: C#版SHIORIの.NET Core移行

**現状の課題**:
- `Rosalind.CSharp.exe`がmacOSで動作しない
- 依存関係の解決が必要
- API呼び出し部分の移植が必要

**実装手順**:
1. 新しい.NET Coreプロジェクトの作成
2. 既存コードの移植
3. API呼び出し部分の修正
4. 動作テストの実施

**成果物**:
```
MacUkagaka.SHIORI/
├── MacUkagaka.SHIORI.csproj
├── Program.cs
├── AIServices/
│   ├── ChatGPTService.cs
│   ├── ClaudeService.cs
│   └── GeminiService.cs
└── Models/
    ├── SHIORIRequest.cs
    └── SHIORIResponse.cs
```

### Task 2: MacUkagakaの安定化

**現状の課題**:
- SHIORI通信のタイムアウト
- プロセス管理の不安定性
- エラー時の適切な処理がない

**実装手順**:
1. SHIORIClient.swiftのリファクタリング
2. 非同期処理の改善
3. エラーハンドリングの強化
4. ログ出力の追加

**修正箇所**:
```swift
// SHIORIClient.swift
class SHIORIClient {
    private let timeout: TimeInterval = 10.0
    private let maxRetries: Int = 3
    
    func requestWithRetry(event: String, references: [String]) throws -> String {
        // リトライ機能付きリクエスト
    }
    
    private func handleProcessError(_ error: Error) {
        // プロセスエラーの適切な処理
    }
}
```

### Task 3: 共通設定フォーマットの設計

**目標**: Windows版とmacOS版で設定を共有

**設計方針**:
- JSON形式での設定管理
- 暗号化されたAPIキー保存
- プラットフォーム固有設定の分離

**実装内容**:
```json
{
  "version": "1.0",
  "ai_settings": {
    "default_service": "chatgpt",
    "services": {
      "chatgpt": {
        "api_key_encrypted": "...",
        "model": "gpt-4",
        "temperature": 0.7,
        "max_tokens": 1000
      },
      "claude": {
        "api_key_encrypted": "...",
        "model": "claude-3-sonnet-20240229"
      },
      "gemini": {
        "api_key_encrypted": "...",
        "model": "gemini-pro"
      }
    }
  },
  "character_settings": {
    "name": "アイ",
    "personality": "気だるげなダウナー系理系お姉さん",
    "user_title": "後輩くん",
    "response_style": "casual"
  },
  "platform_settings": {
    "macos": {
      "window_position": {"x": 100, "y": 100},
      "always_on_top": true,
      "animation_enabled": true
    },
    "windows": {
      "ssp_integration": true,
      "notification_enabled": true
    }
  }
}
```

---

## 週次進捗目標

### Week 1 (現在)
- [ ] C#版SHIORIの現状分析完了
- [ ] .NET Core移行の技術調査
- [ ] MacUkagakaの主要バグ修正
- [ ] 共通設定フォーマットの仕様策定

### Week 2
- [ ] .NET Core版SHIORIの基本実装
- [ ] MacUkagakaとの通信テスト
- [ ] 設定管理システムの実装
- [ ] 基本的なAI応答機能のテスト

### Week 3-4 (Phase 2開始)
- [ ] ChatGPT APIの完全統合
- [ ] Claude/Gemini APIの統合
- [ ] プロンプト管理システム
- [ ] ユーザー設定UI

---

## 成功指標

### 技術指標
- [ ] C#版SHIORIの100%移植完了
- [ ] MacUkagakaでのAI応答成功率95%以上
- [ ] 応答時間5秒以内
- [ ] メモリ使用量100MB以下

### 機能指標
- [ ] 既存のAI何かちゃんと同等の会話機能
- [ ] 3つのAIサービスの切り替え機能
- [ ] 設定の永続化機能
- [ ] 安定した長時間動作

### ユーザー指標
- [ ] 直感的な設定変更UI
- [ ] エラー時の適切なメッセージ表示
- [ ] 既存ユーザーの移行しやすさ
- [ ] 新規ユーザーの使いやすさ

---

## リスク対策

### 高リスク項目
1. **API仕様変更**: 複数サービス対応でリスク分散
2. **.NET Core互換性**: 段階的移行と十分なテスト
3. **macOS権限問題**: 事前調査と適切な権限要求

### 対策
- 定期的な動作確認
- 複数の代替案の準備
- 早期のユーザーフィードバック

### 緊急時対応
- バックアップ実装の準備
- 段階的ロールバック計画
- 問題発生時の迅速な対応

---

## 次回レビュー予定

**日程**: 1週間後
**レビュー項目**:
- [ ] Phase 1の進捗確認
- [ ] 技術的課題の解決状況
- [ ] 次フェーズの詳細計画
- [ ] リスク評価の更新

**参加者**:
- 開発チーム
- テスター
- ユーザー代表（可能であれば）

このロードマップに従って、既存のAI何かちゃんの機能を段階的にmacOS版に移植し、両プラットフォームで一貫した高品質な体験を提供することを目指します。
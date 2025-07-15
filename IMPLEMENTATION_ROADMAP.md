# MacUkagaka 実装ロードマップ

## プロジェクト概要

既存のAI搭載Windows版「何かちゃん」をmacOS版MacUkagakaに統合し、両プラットフォームで共通のAI機能を提供する。

## 全体戦略

### Phase 1: 基盤整備（1-2週間）
- 既存C#版SHIORIの.NET Core対応
- MacUkagakaの安定化
- 共通設定フォーマットの策定

### Phase 2: AI統合（2-3週間）
- ChatGPT/Claude/Gemini APIの統合
- 共通API管理システムの構築
- プロンプト管理システムの実装

### Phase 3: 機能拡張（2-3週間）
- 高度なsurfaces.txt対応
- アニメーション機能
- 設定永続化

### Phase 4: 最適化・拡張（1-2週間）
- パフォーマンス最適化
- 複数ゴースト対応
- テスト・デバッグ

---

## Phase 1: 基盤整備

### 1.1 既存C#版SHIORIの.NET Core対応

**目標**: 既存のC#版SHIORIをmacOSで実行可能にする

**現状分析**:
- `ChatGPT.csx`: C#スクリプトファイル
- `Rosalind.CSharp.exe`: .NET Framework向け実行ファイル
- `SHIOLINK.dll`: Windows専用DLL

**実装計画**:

#### 1.1.1 .NET Core移行
```csharp
// 新しいプロジェクト構造
MacUkagaka.SHIORI/
├── MacUkagaka.SHIORI.csproj
├── Program.cs
├── AIServices/
│   ├── IAIService.cs
│   ├── ChatGPTService.cs
│   ├── ClaudeService.cs
│   └── GeminiService.cs
├── Models/
│   ├── SHIORIRequest.cs
│   ├── SHIORIResponse.cs
│   └── AIRequest.cs
└── Utils/
    ├── ConfigManager.cs
    └── SakuraScriptBuilder.cs
```

#### 1.1.2 設定ファイル統合
```json
// config.json
{
  "ai_settings": {
    "default_service": "chatgpt",
    "chatgpt": {
      "api_key": "",
      "model": "gpt-4",
      "temperature": 0.7
    },
    "claude": {
      "api_key": "",
      "model": "claude-3-sonnet-20240229"
    },
    "gemini": {
      "api_key": "",
      "model": "gemini-pro"
    }
  },
  "character_settings": {
    "name": "アイ",
    "personality": "気だるげなダウナー系理系お姉さん",
    "call_user": "後輩くん"
  }
}
```

#### 1.1.3 Swift側の.NET Core対応
```swift
// SHIORIClient.swift の更新
private func startDotNetCoreShiori() throws {
    let exePath = "\(ghostPath)/MacUkagaka.SHIORI.dll"
    
    process = Process()
    process?.executableURL = URL(fileURLWithPath: "/usr/local/share/dotnet/dotnet")
    process?.arguments = [exePath]
    // ... 既存の設定
}
```

### 1.2 MacUkagakaの安定化

**目標**: 現在のMacUkagakaの不具合修正と機能強化

#### 1.2.1 SHIORI通信の改善
```swift
// 改善点
- 非同期通信への対応
- タイムアウト処理の強化
- エラーハンドリングの改善
- リトライ機能の追加
```

#### 1.2.2 Surface描画の改善
```swift
// 改善点
- 画像キャッシュシステム
- 画像読み込みの非同期化
- メモリ使用量の最適化
- 複数解像度対応
```

### 1.3 共通設定フォーマットの策定

**目標**: Windows版とmacOS版で設定を共有可能にする

#### 1.3.1 設定ファイル構造
```
ghost/master/
├── config.json          # 新しい共通設定
├── descript.txt         # 既存の伺か設定
├── shiori_config.json   # SHIORI固有設定
└── user_settings.json   # ユーザー設定
```

---

## Phase 2: AI統合

### 2.1 ChatGPT/Claude/Gemini APIの統合

**目標**: 既存のAI機能をmacOS版に移植

#### 2.1.1 API抽象化レイヤー
```csharp
public interface IAIService
{
    Task<string> GenerateResponseAsync(string prompt, AIContext context);
    Task<bool> ValidateApiKeyAsync();
    AIServiceInfo GetServiceInfo();
}

public class AIServiceManager
{
    private readonly Dictionary<string, IAIService> _services;
    
    public async Task<string> GenerateResponseAsync(string serviceName, string prompt)
    {
        // サービス選択とレスポンス生成
    }
}
```

#### 2.1.2 各AIサービスの実装
```csharp
public class ChatGPTService : IAIService
{
    public async Task<string> GenerateResponseAsync(string prompt, AIContext context)
    {
        // ChatGPT API呼び出し
        // ストリーミング対応
        // エラーハンドリング
    }
}

public class ClaudeService : IAIService
{
    public async Task<string> GenerateResponseAsync(string prompt, AIContext context)
    {
        // Claude API呼び出し
        // Anthropic API対応
    }
}

public class GeminiService : IAIService
{
    public async Task<string> GenerateResponseAsync(string prompt, AIContext context)
    {
        // Gemini API呼び出し
        // Google AI Studio対応
    }
}
```

### 2.2 共通API管理システムの構築

**目標**: APIキーの管理とサービス切り替えを統一

#### 2.2.1 設定管理
```csharp
public class ConfigManager
{
    public AISettings LoadAISettings()
    {
        // config.jsonから設定を読み込み
    }
    
    public void SaveAISettings(AISettings settings)
    {
        // 設定を保存
    }
    
    public bool ValidateApiKey(string service, string apiKey)
    {
        // APIキーの検証
    }
}
```

#### 2.2.2 Swift側の設定連携
```swift
// 設定管理クラス
class ConfigurationManager {
    func loadAISettings() -> AISettings? {
        // config.jsonの読み込み
    }
    
    func saveAISettings(_ settings: AISettings) {
        // 設定の保存
    }
}
```

### 2.3 プロンプト管理システムの実装

**目標**: キャラクターの性格とAI応答の一貫性を保つ

#### 2.3.1 プロンプトテンプレート
```json
{
  "system_prompt": "あなたは「アイ」という名前のダウナー系理系お姉さんです。",
  "personality_traits": [
    "気だるげ",
    "理系",
    "皮肉屋",
    "知的"
  ],
  "response_patterns": {
    "greeting": "はあ...後輩くん、お疲れ様",
    "question": "んー、それはね...",
    "farewell": "お疲れ様でした"
  }
}
```

#### 2.3.2 動的プロンプト生成
```csharp
public class PromptBuilder
{
    public string BuildPrompt(string userInput, ConversationContext context)
    {
        // システムプロンプト + 性格設定 + 文脈 + ユーザー入力
        // を組み合わせて最終プロンプトを生成
    }
}
```

---

## Phase 3: 機能拡張

### 3.1 高度なsurfaces.txt対応

**目標**: 複雑な画像合成とアニメーション対応

#### 3.1.1 surfaces.txtパーサーの拡張
```swift
struct SurfaceDefinition {
    let id: Int
    let elements: [SurfaceElement]
    let collisions: [CollisionArea]
    let animations: [AnimationSequence]
}

struct SurfaceElement {
    let type: ElementType // base, overlay, add, multiply
    let imagePath: String
    let position: CGPoint
    let blendMode: BlendMode
}

class SurfaceParser {
    func parse(_ surfaceText: String) -> [SurfaceDefinition] {
        // 複雑なsurfaces.txt構文の解析
        // ブレンドモード対応
        // 条件分岐対応
    }
}
```

#### 3.1.2 画像合成エンジン
```swift
class SurfaceRenderer {
    func renderSurface(_ definition: SurfaceDefinition) -> NSImage {
        // Core Graphicsを使用した画像合成
        // 各種ブレンドモードの実装
        // パフォーマンス最適化
    }
}
```

### 3.2 アニメーション機能

**目標**: まばたき、口パク、身体の動きなどのアニメーション

#### 3.2.1 アニメーションシステム
```swift
class AnimationManager {
    private var activeAnimations: [AnimationSequence] = []
    private var animationTimer: Timer?
    
    func startAnimation(_ animation: AnimationSequence) {
        // アニメーションの開始
    }
    
    func stopAnimation(_ animationId: String) {
        // アニメーションの停止
    }
    
    func updateAnimations() {
        // フレーム更新処理
    }
}

struct AnimationSequence {
    let id: String
    let frames: [AnimationFrame]
    let duration: TimeInterval
    let repeatCount: Int
}

struct AnimationFrame {
    let surfaceId: Int
    let duration: TimeInterval
    let easing: EasingType
}
```

#### 3.2.2 標準アニメーション
```swift
// 標準的なアニメーション
- まばたき（blink）
- 口パク（lip_sync）
- 待機アニメーション（idle）
- 感情表現（emotion）
```

### 3.3 設定永続化

**目標**: ユーザー設定とウィンドウ位置の保存

#### 3.3.1 設定管理
```swift
class PersistentSettings {
    func saveWindowPosition(_ position: CGPoint) {
        // ウィンドウ位置の保存
    }
    
    func loadWindowPosition() -> CGPoint? {
        // ウィンドウ位置の読み込み
    }
    
    func saveUserPreferences(_ preferences: UserPreferences) {
        // ユーザー設定の保存
    }
}

struct UserPreferences {
    var selectedAIService: String
    var balloonDisplayTime: TimeInterval
    var enableAnimations: Bool
    var volume: Float
}
```

---

## Phase 4: 最適化・拡張

### 4.1 パフォーマンス最適化

**目標**: メモリ使用量の削減とCPU使用率の改善

#### 4.1.1 メモリ最適化
```swift
- 画像キャッシュシステムの実装
- 不要な画像の自動解放
- Surface描画の最適化
- メモリプールの活用
```

#### 4.1.2 CPU最適化
```swift
- 非同期処理の活用
- バックグラウンドでの画像処理
- アニメーション処理の最適化
- 不要な再描画の削減
```

### 4.2 複数ゴースト対応

**目標**: 複数のゴーストの同時実行

#### 4.2.1 ゴースト管理システム
```swift
class GhostRepository {
    private var activeGhosts: [String: GhostManager] = [:]
    
    func loadGhost(_ ghostPath: String) -> GhostManager? {
        // ゴーストの読み込み
    }
    
    func switchGhost(_ ghostId: String) {
        // ゴーストの切り替え
    }
    
    func removeGhost(_ ghostId: String) {
        // ゴーストの削除
    }
}
```

---

## 開発スケジュール

### Week 1-2: Phase 1 基盤整備
- [ ] C#版SHIORIの.NET Core移行
- [ ] MacUkagakaの安定化
- [ ] 共通設定フォーマットの実装

### Week 3-4: Phase 2 AI統合（前半）
- [ ] API抽象化レイヤーの実装
- [ ] ChatGPTサービスの統合
- [ ] 基本的なAI応答機能

### Week 5-6: Phase 2 AI統合（後半）
- [ ] Claude/Geminiサービスの統合
- [ ] プロンプト管理システム
- [ ] 設定管理システム

### Week 7-8: Phase 3 機能拡張（前半）
- [ ] surfaces.txt完全対応
- [ ] 基本的な画像合成機能
- [ ] アニメーション基盤

### Week 9-10: Phase 3 機能拡張（後半）
- [ ] アニメーション機能の実装
- [ ] 設定永続化機能
- [ ] UI/UX改善

### Week 11-12: Phase 4 最適化・拡張
- [ ] パフォーマンス最適化
- [ ] 複数ゴースト対応
- [ ] 総合テスト・デバッグ

---

## 技術的課題と解決策

### 課題1: C#とSwift間の通信
**解決策**: 
- JSON形式での設定共有
- 標準入出力を使用した安定した通信
- エラーハンドリングの強化

### 課題2: AI API利用料金の管理
**解決策**:
- API使用量の監視
- レート制限の実装
- ローカルキャッシュの活用

### 課題3: macOSの権限管理
**解決策**:
- 適切な権限要求の実装
- サンドボックス対応
- 署名とnotarization

### 課題4: 既存ゴーストとの互換性
**解決策**:
- 段階的な対応レベル
- フォールバック機能
- 互換性テストの実施

---

## 成功指標

### 技術指標
- [ ] 既存C#版SHIORIの100%移植
- [ ] 3つのAIサービスの完全統合
- [ ] アニメーション機能の実装
- [ ] メモリ使用量50%削減

### 機能指標
- [ ] Windows版と同等の機能実現
- [ ] 安定した24時間連続動作
- [ ] 1秒以内のAI応答時間
- [ ] 直感的な設定変更UI

### ユーザー指標
- [ ] 既存ユーザーの移行率80%
- [ ] 新規macOSユーザーの獲得
- [ ] 満足度調査での高評価
- [ ] コミュニティでの活発な利用

---

## リスクと対策

### 高リスク
- **API仕様変更**: 複数サービス対応でリスク分散
- **Apple審査**: 事前の技術調査と段階的実装
- **パフォーマンス**: 早期プロトタイプでの検証

### 中リスク
- **互換性問題**: 十分なテストと段階的移行
- **メモリリーク**: 継続的な監視と最適化
- **セキュリティ**: 適切な権限管理と暗号化

### 低リスク
- **UI/UXの改善**: ユーザーフィードバックによる改善
- **ドキュメント**: 継続的な更新と改善

この実装ロードマップに従って、既存のAI何かちゃんの機能を完全にmacOS版に移植し、さらに拡張された機能を提供することを目指します。
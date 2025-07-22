# Claude Code Configuration

## GitHub Repository Settings

### IMPORTANT: Repository Target
**Always create issues in the correct repository:**
- ✅ **Correct**: https://github.com/eightman999/AINanikaAIChan
- ❌ **Wrong**: https://github.com/manju-summoner/AISisterAIChan (fork source)

When using `gh issue create` commands, ensure you are working in the correct repository directory and targeting the right repository.

## Gemini MCP Usage Guidelines

### Model Selection Strategy

When using Gemini CLI MCP tools, follow this priority order:

1. **Default**: Use `gemini-2.5-pro` for best quality results
2. **Quota Exceeded**: Switch to `gemini-2.5-flash` when receiving 429 errors or quota limits
3. **Fast Operations**: Use `gemini-2.5-flash` for simple queries that don't require maximum reasoning

### Error Handling

When encountering quota exceeded errors (HTTP 429):
- Automatically retry with `gemini-2.5-flash` model
- Wait briefly before retry to respect rate limits
- Document the model fallback in responses

### Usage Examples

```bash
# Primary attempt (preferred)
mcp__gemini-cli__geminiChat --model "gemini-2.5-pro" --prompt "..."

# Fallback when quota exceeded
mcp__gemini-cli__geminiChat --model "gemini-2.5-flash" --prompt "..."
```

### Tool Configuration

Current MCP server setup in `.mcp.json`:
- Package: `@choplin/mcp-gemini-cli`
- Available tools: `googleSearch`, `geminiChat`
- Execution: stdio mode via npx

### Best Practices

1. **Monitor quota usage** - Be aware of daily limits
2. **Optimize prompts** - Use concise, specific prompts to reduce token usage
3. **Batch operations** - Combine related queries when possible
4. **Fallback gracefully** - Always have Flash model as backup

## 【MUST GLOBAL】Gemini活用（プロジェクトのCLAUDE.mdより優先）

### 三位一体の開発原則
人間の**意思決定**、Claude Codeの**分析と実行**、Gemini MCPの**検証と助言**を組み合わせ、開発の質と速度を最大化する：
- **人間 (ユーザー)**：プロジェクトの目的・要件・最終ゴールを定義し、最終的な意思決定を行う**意思決定者**
  - 反面、具体的なコーディングや詳細な計画を立てる力、タスク管理能力ははありません。
- **Claude Code**：高度なタスク分解・高品質な実装・リファクタリング・ファイル操作・タスク管理を担う**実行者**
  - 指示に対して忠実に、順序立てて実行する能力はありますが、意志がなく、思い込みは勘違いも多く、思考力は少し劣ります。
- **Gemini MCP**：API・ライブラリ・エラー解析など**コードレベル**の技術調査・Web検索 (Google検索) による最新情報へのアクセスを行う**コード専門家**
  - ミクロな視点でのコード品質・実装方法・デバッグに優れますが、アーキテクチャ全体の設計判断は専門外です。
  - 基本的にはflashモデルを推奨。

### 壁打ち先の自動判定ルール
- **ユーザーの要求を受けたら即座に壁打ち**を必ず実施
- 壁打ち結果は鵜呑みにしすぎず、1意見として判断
- 結果を元に聞き方を変えて多角的な意見を抽出するのも効果的

### 主要な活用場面
1. **実現不可能な依頼**: Claude Code では実現できない要求への対処 (例: `最新のニュース記事を取得して`)
2. **前提確認**: 要求の理解や実装方針の妥当性を確認 (例: `この実装方針で要件を満たせるか確認して`)
3. **技術調査**: 最新情報・エラー解決・ドキュメント検索 (例: `Rails 7.2の新機能を調べて`)
4. **設計立案**: 新機能の設計・アーキテクチャ構築 (例: `認証システムの設計案を作成して`)
5. **問題解決**: エラーや不具合の原因究明と対処 (例: `このTypeScriptエラーの解決方法を教えて`)
6. **コードレビュー**: 品質・保守性・パフォーマンスの評価 (例: `このコードの改善点は？`)
7. **計画立案**: タスク分解・実装方針の策定 (例: `ユーザー認証機能を実装するための計画を立てて`)
8. **技術選定**: ライブラリ・フレームワークの比較検討 (例: `状態管理にReduxとZustandどちらが適切か？`)
9. **リスク評価**: 実装前の潜在的問題の洗い出し (例: `この実装のセキュリティリスクは？`)
10. **設計検証**: 既存設計の妥当性確認・改善提案 (例: `現在のAPI設計の問題点と改善案は？`)
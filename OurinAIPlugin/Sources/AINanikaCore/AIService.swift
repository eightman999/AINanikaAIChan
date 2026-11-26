//  © eightman 2005-2025
//  Furin-lab All Rights Reserved.
//  AIサービス抽象インターフェース+ファクトリ

import Foundation

/// 会話メッセージ(チャット形式API用)
public struct ChatMessage: Equatable {
    public let role: String // "system" | "user" | "assistant"
    public let content: String

    public init(role: String, content: String) {
        self.role = role
        self.content = content
    }
}

/// AI生成リクエストのコンテキスト
public struct GenerationContext {
    /// システムプロンプト(persona+現在状態)
    public var systemPrompt: String
    /// 直近の会話履歴(このターンのユーザー入力を含む)
    public var history: [ChatMessage]

    public init(systemPrompt: String, history: [ChatMessage]) {
        self.systemPrompt = systemPrompt
        self.history = history
    }
}

/// AIサービス共通インターフェース
public protocol AIService {
    /// 与えられたコンテキストから応答テキストを生成する。
    /// 実装はバックグラウンドスレッドで呼ばれる前提(SHIORIリクエスト内で同期待ちしない)。
    func generate(_ context: GenerationContext, maxTokens: Int, timeoutSeconds: Double) async throws -> String
}

public enum AIServiceFactory {
    /// 設定に応じたAIサービスを生成する。apiKeyが空の場合はnil(オフライン動作)
    public static func make(configuration: PluginConfiguration) -> AIService? {
        guard !configuration.apiKey.isEmpty || configuration.provider == .custom else { return nil }
        switch configuration.provider {
        case .openai:
            return OpenAICompatibleService(
                apiKey: configuration.apiKey,
                model: configuration.model.isEmpty ? "gpt-4o-mini" : configuration.model,
                baseUrl: "https://api.openai.com/v1"
            )
        case .custom:
            return OpenAICompatibleService(
                apiKey: configuration.apiKey,
                model: configuration.model.isEmpty ? "local-model" : configuration.model,
                baseUrl: configuration.baseUrl.isEmpty ? "http://localhost:1234/v1" : configuration.baseUrl
            )
        case .anthropic:
            return AnthropicService(
                apiKey: configuration.apiKey,
                model: configuration.model.isEmpty ? "claude-3-5-haiku-latest" : configuration.model
            )
        case .gemini:
            return GeminiService(
                apiKey: configuration.apiKey,
                model: configuration.model.isEmpty ? "gemini-1.5-flash" : configuration.model
            )
        }
    }
}

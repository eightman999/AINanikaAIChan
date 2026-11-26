//  © eightman 2005-2025
//  Furin-lab All Rights Reserved.
//  プラグイン設定(ai_config.json)

import Foundation

/// AI接続プロバイダ種別
public enum AIProviderKind: String, Codable, CaseIterable {
    case openai
    case anthropic
    case gemini
    case custom // OpenAI互換のカスタムエンドポイント(LM Studio/Ollama等)
}

/// ai_config.json の内容
public struct PluginConfiguration: Codable, Equatable {
    public var provider: AIProviderKind
    public var apiKey: String
    /// モデル名。空なら各プロバイダ既定値
    public var model: String
    /// customプロバイダ用ベースURL(例: http://localhost:1234/v1)
    public var baseUrl: String
    public var maxTokens: Int
    /// LLM呼び出しのタイムアウト秒(SHIORI watchdogとは無関係・バックグラウンド実行)
    public var timeoutSeconds: Double
    /// 入力受付直後に返す即時応答スクリプト
    public var ackScript: String
    /// 生成失敗時に返すスクリプト
    public var errorScript: String
    /// プロンプトへ渡す会話履歴の最大ターン数
    public var historyLimit: Int
    /// キャラクター設定ファイル(persona.md)のパス。空ならload dir基準で探索
    public var personaPath: String
    /// 応答に含めたすぎる長文を\n区切りに整形する
    public var splitLongReply: Bool

    enum CodingKeys: String, CodingKey {
        case provider, apiKey, model
        case baseUrl = "baseUrl"
        case maxTokens
        case timeoutSeconds
        case ackScript
        case errorScript
        case historyLimit
        case personaPath
        case splitLongReply
    }

    public init() {
        provider = .openai
        apiKey = ""
        model = ""
        baseUrl = ""
        maxTokens = 300
        timeoutSeconds = 30
        ackScript = "\\h\\s[0]……\\e"
        errorScript = "\\h\\s[0]ごめんなさい、うまく考えられなかったです\\e"
        historyLimit = 10
        personaPath = ""
        splitLongReply = true
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        var fallback = PluginConfiguration()
        if let raw = try c.decodeIfPresent(String.self, forKey: .provider),
           let kind = AIProviderKind(rawValue: raw.lowercased()) {
            provider = kind
        } else {
            provider = fallback.provider
        }
        apiKey = try c.decodeIfPresent(String.self, forKey: .apiKey) ?? ""
        model = try c.decodeIfPresent(String.self, forKey: .model) ?? ""
        baseUrl = try c.decodeIfPresent(String.self, forKey: .baseUrl) ?? ""
        maxTokens = try c.decodeIfPresent(Int.self, forKey: .maxTokens) ?? 300
        timeoutSeconds = try c.decodeIfPresent(Double.self, forKey: .timeoutSeconds) ?? 30
        ackScript = try c.decodeIfPresent(String.self, forKey: .ackScript) ?? fallback.ackScript
        errorScript = try c.decodeIfPresent(String.self, forKey: .errorScript) ?? fallback.errorScript
        historyLimit = try c.decodeIfPresent(Int.self, forKey: .historyLimit) ?? 10
        personaPath = try c.decodeIfPresent(String.self, forKey: .personaPath) ?? ""
        splitLongReply = try c.decodeIfPresent(Bool.self, forKey: .splitLongReply) ?? true
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(provider.rawValue, forKey: .provider)
        try c.encode(apiKey, forKey: .apiKey)
        try c.encode(model, forKey: .model)
        try c.encode(baseUrl, forKey: .baseUrl)
        try c.encode(maxTokens, forKey: .maxTokens)
        try c.encode(timeoutSeconds, forKey: .timeoutSeconds)
        try c.encode(ackScript, forKey: .ackScript)
        try c.encode(errorScript, forKey: .errorScript)
        try c.encode(historyLimit, forKey: .historyLimit)
        try c.encode(personaPath, forKey: .personaPath)
        try c.encode(splitLongReply, forKey: .splitLongReply)
    }

    public static func load(from directory: URL) -> PluginConfiguration? {
        let url = directory.appendingPathComponent("ai_config.json")
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(PluginConfiguration.self, from: data)
    }

    public func write(to directory: URL) throws {
        let url = directory.appendingPathComponent("ai_config.json")
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(self)
        try data.write(to: url, options: [.atomic])
    }
}

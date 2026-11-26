//  © eightman 2005-2025
//  Furin-lab All Rights Reserved.
//  Anthropic Messages API(旧ClaudeService.csの現代化版)

import Foundation

struct AnthropicService: AIService {
    let apiKey: String
    let model: String

    static let apiVersion = "2023-06-01"

    struct RequestBody: Encodable {
        let model: String
        let max_tokens: Int
        let system: String?
        let messages: [Message]
        struct Message: Encodable {
            let role: String
            let content: String
        }
    }

    struct ResponseBody: Decodable {
        struct ContentBlock: Decodable {
            let type: String?
            let text: String?
        }
        let content: [ContentBlock]?

        var joinedText: String? {
            let texts = (content ?? []).compactMap { $0.type == "text" ? $0.text : nil }
            let joined = texts.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
            return joined.isEmpty ? nil : joined
        }
    }

    func generate(_ context: GenerationContext, maxTokens: Int, timeoutSeconds: Double) async throws -> String {
        guard let url = URL(string: "https://api.anthropic.com/v1/messages") else {
            throw AIError.invalidConfiguration
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = timeoutSeconds
        request.addValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.addValue(Self.apiVersion, forHTTPHeaderField: "anthropic-version")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")

        // Anthropicはassistant開始/交互制約が緩いが、user連続は許可されるためそのまま渡す
        let messages = context.history.map { RequestBody.Message(role: $0.role == "assistant" ? "assistant" : "user", content: $0.content) }
        let system = context.systemPrompt.isEmpty ? nil : context.systemPrompt
        request.httpBody = try JSONEncoder().encode(
            RequestBody(model: model, max_tokens: maxTokens, system: system, messages: messages)
        )

        let (data, response) = try await Self.session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw AIError.networkError }
        guard (200..<300).contains(http.statusCode) else {
            throw AIError.httpError(status: http.statusCode, body: String(data: data, encoding: .utf8)?.prefix(200).description ?? "")
        }
        let body = try JSONDecoder().decode(ResponseBody.self, from: data)
        guard let text = body.joinedText else { throw AIError.emptyResponse }
        return text
    }

    /// テスト差し替え可能なセッション
    static var session = URLSession.shared
}

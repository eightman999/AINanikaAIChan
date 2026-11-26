//  © eightman 2005-2025
//  Furin-lab All Rights Reserved.
//  OpenAI互換Chat Completions API(OpenAI + LM Studio/Ollama等カスタムエンドポイント)

import Foundation

struct OpenAICompatibleService: AIService {
    let apiKey: String
    let model: String
    let baseUrl: String

    struct RequestBody: Encodable {
        let model: String
        let messages: [Message]
        let max_tokens: Int
        struct Message: Encodable {
            let role: String
            let content: String
        }
    }

    struct ResponseBody: Decodable {
        struct Choice: Decodable {
            struct Message: Decodable {
                let content: String?
            }
            let message: Message
        }
        let choices: [Choice]?

        var firstText: String? {
            choices?.first?.message.content
        }
    }

    func generate(_ context: GenerationContext, maxTokens: Int, timeoutSeconds: Double) async throws -> String {
        guard let url = URL(string: baseUrl.trimmingCharacters(in: CharacterSet(charactersIn: "/")) + "/chat/completions") else {
            throw AIError.invalidConfiguration
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = timeoutSeconds
        if !apiKey.isEmpty {
            request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        }
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")

        var messages: [RequestBody.Message] = []
        if !context.systemPrompt.isEmpty {
            messages.append(.init(role: "system", content: context.systemPrompt))
        }
        for turn in context.history {
            messages.append(.init(role: turn.role, content: turn.content))
        }
        request.httpBody = try JSONEncoder().encode(RequestBody(model: model, messages: messages, max_tokens: maxTokens))

        let (data, response) = try await Self.session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw AIError.networkError }
        guard (200..<300).contains(http.statusCode) else {
            throw AIError.httpError(status: http.statusCode, body: String(data: data, encoding: .utf8)?.prefix(200).description ?? "")
        }
        let body = try JSONDecoder().decode(ResponseBody.self, from: data)
        guard let text = body.firstText?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty else {
            throw AIError.emptyResponse
        }
        return text
    }

    /// テスト差し替え可能なセッション
    static var session: URLSession = {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 60
        return URLSession(configuration: config)
    }()
}

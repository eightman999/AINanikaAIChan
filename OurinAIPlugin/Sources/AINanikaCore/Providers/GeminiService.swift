//  © eightman 2005-2025
//  Furin-lab All Rights Reserved.
//  Google Gemini API(geminicli.py / GeminiService.cs と同一エンドポイント)

import Foundation

struct GeminiService: AIService {
    let apiKey: String
    let model: String

    struct RequestBody: Encodable {
        let contents: [Content]
        let systemInstruction: SystemInstruction?
        struct Part: Encodable {
            let text: String
        }
        struct Content: Encodable {
            let role: String // "user" | "model"
            let parts: [Part]
        }
        struct SystemInstruction: Encodable {
            let parts: [Part]
        }
    }

    struct ResponseBody: Decodable {
        struct Candidate: Decodable {
            struct Content: Decodable {
                struct Part: Decodable {
                    let text: String?
                }
                let parts: [Part]?
            }
            let content: Content?
        }
        let candidates: [Candidate]?

        var firstText: String? {
            let texts = candidates?.first?.content?.parts?.compactMap { $0.text } ?? []
            let joined = texts.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
            return joined.isEmpty ? nil : joined
        }
    }

    func generate(_ context: GenerationContext, maxTokens: Int, timeoutSeconds: Double) async throws -> String {
        var components = URLComponents(string: "https://generativelanguage.googleapis.com/v1beta/models/\(model):generateContent")
        components?.queryItems = [URLQueryItem(name: "key", value: apiKey)]
        guard let url = components?.url else { throw AIError.invalidConfiguration }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = timeoutSeconds
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")

        let contents = context.history.map { turn in
            RequestBody.Content(role: turn.role == "assistant" ? "model" : "user",
                                parts: [.init(text: turn.content)])
        }
        let system = context.systemPrompt.isEmpty
            ? nil
            : RequestBody.SystemInstruction(parts: [.init(text: context.systemPrompt)])
        request.httpBody = try JSONEncoder().encode(RequestBody(contents: contents, systemInstruction: system))

        let (data, response) = try await Self.session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw AIError.networkError }
        guard (200..<300).contains(http.statusCode) else {
            throw AIError.httpError(status: http.statusCode, body: String(data: data, encoding: .utf8)?.prefix(200).description ?? "")
        }
        let body = try JSONDecoder().decode(ResponseBody.self, from: data)
        guard let text = body.firstText else { throw AIError.emptyResponse }
        return text
    }

    /// テスト差し替え可能なセッション
    static var session = URLSession.shared
}

//  © eightman 2005-2025
//  Furin-lab All Rights Reserved.
//  AI Provider単体テスト(URLProtocolモック)

import XCTest
@testable import AINanikaCore

/// URLProtocolでHTTP応答をスタブ化するモック
final class MockURLProtocol: URLProtocol {
    static var handler: ((URLRequest) -> (Int, Data))?
    static var lastRequest: URLRequest?
    static var lastBody: Data?

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        Self.lastRequest = request
        // httpBodyはURLProtocolからはbodyStreamになることがあるため読み出す
        if let body = request.httpBody {
            Self.lastBody = body
        } else if let stream = request.httpBodyStream {
            stream.open()
            var data = Data()
            let bufferSize = 4096
            let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)
            defer { buffer.deallocate() }
            while stream.hasBytesAvailable {
                let read = stream.read(buffer, maxLength: bufferSize)
                if read <= 0 { break }
                data.append(buffer, count: read)
            }
            stream.close()
            Self.lastBody = data
        }
        let (status, data) = Self.handler?(request) ?? (200, Data())
        let response = HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: "HTTP/1.1", headerFields: ["Content-Type": "application/json"])!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: data)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}

class ProviderTestBase: XCTestCase {
    private var savedOpenAI: URLSession!
    private var savedAnthropic: URLSession!
    private var savedGemini: URLSession!

    override func setUp() {
        super.setUp()
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        let mockSession = URLSession(configuration: config)
        savedOpenAI = OpenAICompatibleService.session
        savedAnthropic = AnthropicService.session
        savedGemini = GeminiService.session
        OpenAICompatibleService.session = mockSession
        AnthropicService.session = mockSession
        GeminiService.session = mockSession
    }

    override func tearDown() {
        OpenAICompatibleService.session = savedOpenAI
        AnthropicService.session = savedAnthropic
        GeminiService.session = savedGemini
        MockURLProtocol.lastRequest = nil
        MockURLProtocol.lastBody = nil
        super.tearDown()
    }
}

final class OpenAICompatibleServiceTests: ProviderTestBase {
    private let context = GenerationContext(
        systemPrompt: "あなたはゴーストです",
        history: [ChatMessage(role: "user", content: "こんにちは")]
    )

    func testSuccessfulGeneration() async throws {
        MockURLProtocol.handler = { _ in
            (200, #"{"choices":[{"message":{"role":"assistant","content":"やっほー！"}}]}"#.data(using: .utf8)!)
        }
        let service = OpenAICompatibleService(apiKey: "sk-test", model: "gpt-4o-mini", baseUrl: "https://api.openai.com/v1")
        let text = try await service.generate(context, maxTokens: 100, timeoutSeconds: 5)
        XCTAssertEqual(text, "やっほー！")

        // リクエスト内容の検証
        XCTAssertEqual(MockURLProtocol.lastRequest?.url?.absoluteString, "https://api.openai.com/v1/chat/completions")
        XCTAssertEqual(MockURLProtocol.lastRequest?.value(forHTTPHeaderField: "Authorization"), "Bearer sk-test")
        let body = try XCTUnwrap(MockURLProtocol.lastBody)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])
        XCTAssertEqual(json["model"] as? String, "gpt-4o-mini")
        let messages = try XCTUnwrap(json["messages"] as? [[String: Any]])
        XCTAssertEqual(messages.first?["role"] as? String, "system")
    }

    func testCustomBaseUrlForLocalLLM() async throws {
        MockURLProtocol.handler = { _ in
            (200, #"{"choices":[{"message":{"content":"local!"}}]}"#.data(using: .utf8)!)
        }
        let service = OpenAICompatibleService(apiKey: "", model: "llama3", baseUrl: "http://localhost:1234/v1")
        let text = try await service.generate(context, maxTokens: 50, timeoutSeconds: 5)
        XCTAssertEqual(text, "local!")
        XCTAssertEqual(MockURLProtocol.lastRequest?.url?.host, "localhost")
        XCTAssertNil(MockURLProtocol.lastRequest?.value(forHTTPHeaderField: "Authorization"))
    }

    func testHttpErrorThrows() async {
        MockURLProtocol.handler = { _ in (401, #"{"error":"bad key"}"#.data(using: .utf8)!) }
        let service = OpenAICompatibleService(apiKey: "bad", model: "gpt-4o-mini", baseUrl: "https://api.openai.com/v1")
        do {
            _ = try await service.generate(context, maxTokens: 50, timeoutSeconds: 5)
            XCTFail("should throw")
        } catch let AIError.httpError(status, _) {
            XCTAssertEqual(status, 401)
        } catch {
            XCTFail("unexpected error \(error)")
        }
    }
}

final class AnthropicServiceTests: ProviderTestBase {
    private let context = GenerationContext(
        systemPrompt: "キャラ設定",
        history: [ChatMessage(role: "user", content: "元気？")]
    )

    func testRequestFormatAndParsing() async throws {
        MockURLProtocol.handler = { _ in
            (200, #"{"content":[{"type":"text","text":"元気だよ！"}]}"#.data(using: .utf8)!)
        }
        let service = AnthropicService(apiKey: "ak-test", model: "claude-3-5-haiku-latest")
        let text = try await service.generate(context, maxTokens: 100, timeoutSeconds: 5)
        XCTAssertEqual(text, "元気だよ！")

        XCTAssertEqual(MockURLProtocol.lastRequest?.value(forHTTPHeaderField: "x-api-key"), "ak-test")
        XCTAssertEqual(MockURLProtocol.lastRequest?.value(forHTTPHeaderField: "anthropic-version"), "2023-06-01")
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: XCTUnwrap(MockURLProtocol.lastBody)) as? [String: Any])
        XCTAssertEqual(json["system"] as? String, "キャラ設定")
        XCTAssertEqual(json["max_tokens"] as? Int, 100)
    }

    func testMultipleTextBlocksJoined() throws {
        let body = AnthropicService.ResponseBody(
            content: [.init(type: "text", text: "あ"),
                      .init(type: "tool_use", text: nil),
                      .init(type: "text", text: "い")]
        )
        XCTAssertEqual(body.joinedText, "あ\nい")
    }
}

final class GeminiServiceTests: ProviderTestBase {
    private let context = GenerationContext(
        systemPrompt: "設定",
        history: [
            ChatMessage(role: "user", content: "おはよう"),
            ChatMessage(role: "assistant", content: "おはよー"),
            ChatMessage(role: "user", content: "今日の予定は？")
        ]
    )

    func testEndpointAndRoleMapping() async throws {
        MockURLProtocol.handler = { _ in
            (200, #"{"candidates":[{"content":{"parts":[{"text":"朝会があるよ"}]}}]}"#.data(using: .utf8)!)
        }
        let service = GeminiService(apiKey: "g-key", model: "gemini-1.5-flash")
        let text = try await service.generate(context, maxTokens: 100, timeoutSeconds: 5)
        XCTAssertEqual(text, "朝会があるよ")

        let url = try XCTUnwrap(MockURLProtocol.lastRequest?.url)
        XCTAssertEqual(url.host, "generativelanguage.googleapis.com")
        XCTAssertTrue(url.path.contains("gemini-1.5-flash:generateContent"))
        XCTAssertTrue(url.query?.contains("key=g-key") ?? false)

        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: XCTUnwrap(MockURLProtocol.lastBody)) as? [String: Any])
        let contents = try XCTUnwrap(json["contents"] as? [[String: Any]])
        XCTAssertEqual(contents.count, 3)
        // assistant → model へ変換される
        XCTAssertEqual(contents[1]["role"] as? String, "model")
        XCTAssertNotNil(json["systemInstruction"])
    }

    func testEmptyCandidatesThrows() async {
        MockURLProtocol.handler = { _ in (200, #"{"candidates":[]}"#.data(using: .utf8)!) }
        let service = GeminiService(apiKey: "g-key", model: "gemini-1.5-flash")
        do {
            _ = try await service.generate(context, maxTokens: 10, timeoutSeconds: 5)
            XCTFail("should throw")
        } catch {
            // AIError.emptyResponse 期待
        }
    }
}

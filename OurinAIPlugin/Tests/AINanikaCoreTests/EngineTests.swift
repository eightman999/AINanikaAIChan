//  © eightman 2005-2025
//  Furin-lab All Rights Reserved.
//  AINanikaEngineの非同期応答ループ検証

import XCTest
@testable import AINanikaCore

/// 即時応答するモックAIサービス
final class MockAIService: AIService {
    let response: String
    let delay: TimeInterval
    private(set) var callCount = 0
    private let lock = NSLock()

    init(response: String = "モック応答だよ", delay: TimeInterval = 0.2) {
        self.response = response
        self.delay = delay
    }

    func generate(_ context: GenerationContext, maxTokens: Int, timeoutSeconds: Double) async throws -> String {
        lock.lock(); callCount += 1; lock.unlock()
        try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
        return response
    }
}

final class AINanikaEngineTests: XCTestCase {
    private var tempDir: URL!

    override func setUp() {
        super.setUp()
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempDir)
        super.tearDown()
    }

    private func makeEngine(service: AIService?, ackScript: String? = nil) -> AINanikaEngine {
        var config = PluginConfiguration()
        if let ackScript { config.ackScript = ackScript }
        return AINanikaEngine(
            configuration: config,
            dataDirectory: tempDir,
            persona: "テスト用キャラ",
            aiService: service
        )
    }

    func testVersionRequest() {
        let engine = makeEngine(service: nil)
        let response = engine.handle(requestText: "GET SHIORI/3.0\r\nSender: Test\r\nID: Version\r\n\r\n")
        XCTAssertTrue(response.contains("Value: \(AINanikaEngine.versionString)"))
    }

    func testUnknownEventReturns204() {
        let engine = makeEngine(service: nil)
        let response = engine.handle(requestText: "GET SHIORI/3.0\r\nID: OnSomethingElse\r\n\r\n")
        XCTAssertTrue(response.contains("204 No Content"))
    }

    func testBootGreeting() {
        let engine = makeEngine(service: nil)
        let response = engine.handle(requestText: "GET SHIORI/3.0\r\nID: OnBoot\r\n\r\n")
        XCTAssertTrue(response.contains("200 OK"))
        XCTAssertTrue(response.contains("\\e"))
    }

    /// 核心: OnCommunicateは即時ACKを返し、LLM完了後OnSecondChangeで応答が届く
    func testAsyncReplyFlow() throws {
        let service = MockAIService(response: "生成完了の台詞", delay: 0.3)
        let engine = makeEngine(service: service, ackScript: "\\h\\s[0]考え中……\\e")

        // ACKは即座に返る(watchdog安全)
        let start = Date()
        let ack = engine.handle(requestText: "GET SHIORI/3.0\r\nID: OnCommunicate\r\nReference0: ねえ\r\n\r\n")
        let elapsed = Date().timeIntervalSince(start)
        XCTAssertLessThan(elapsed, 0.1, "ACK must be immediate (watchdog safety)")
        XCTAssertTrue(ack.contains("考え中……"))

        // 直後のOnSecondChangeではまだ未完了
        let early = engine.handle(requestText: "GET SHIORI/3.0\r\nID: OnSecondChange\r\n\r\n")
        XCTAssertTrue(early.contains("204"))

        // 生成完了を待つ
        Thread.sleep(forTimeInterval: 0.6)

        // OnSecondChangeで完成スクリプトを受け取る
        let reply = engine.handle(requestText: "GET SHIORI/3.0\r\nID: OnSecondChange\r\n\r\n")
        XCTAssertTrue(reply.contains("生成完了の台詞"), "got: \(reply)")
        XCTAssertEqual(service.callCount, 1)

        // キューは空になり、以降は204
        let empty = engine.handle(requestText: "GET SHIORI/3.0\r\nID: OnSecondChange\r\n\r\n")
        XCTAssertTrue(empty.contains("204"))
    }

    func testGenerationFailureDeliversErrorScript() throws {
        final class FailingService: AIService {
            func generate(_ context: GenerationContext, maxTokens: Int, timeoutSeconds: Double) async throws -> String {
                throw AIError.networkError
            }
        }
        var config = PluginConfiguration()
        config.errorScript = "\\h\\s[0]エラー台詞\\e"
        let engine = AINanikaEngine(configuration: config, dataDirectory: tempDir, persona: nil, aiService: FailingService())

        _ = engine.handle(requestText: "GET SHIORI/3.0\r\nID: OnCommunicate\r\nReference0: テスト\r\n\r\n")
        Thread.sleep(forTimeInterval: 0.3)
        let reply = engine.handle(requestText: "GET SHIORI/3.0\r\nID: OnSecondChange\r\n\r\n")
        XCTAssertTrue(reply.contains("エラー台詞"))
    }

    func testNoServiceFallsBackLocally() throws {
        let engine = makeEngine(service: nil)
        let ack = engine.handle(requestText: "GET SHIORI/3.0\r\nID: OnTalk\r\nReference0: お話ししよう\r\n\r\n")
        // AI無しでもフォールバック台詞がOnSecondChangeで届く(graceful degradation)
        Thread.sleep(forTimeInterval: 0.2)
        let reply = engine.handle(requestText: "GET SHIORI/3.0\r\nID: OnSecondChange\r\n\r\n")
        XCTAssertTrue(ack.contains("200") || reply.contains("200"))
        XCTAssertFalse(reply.contains("400"))
    }

    func testClickUpdatesStateAndCelebrates() {
        let engine = makeEngine(service: nil)
        let refs = "Reference0: 0\r\nReference1: 100\r\nReference2: 100"
        for i in 0..<49 {
            _ = engine.handle(requestText: "GET SHIORI/3.0\r\nID: OnMouseClick\r\n\(refs)\r\n\r\n")
            _ = i
        }
        let fiftieth = engine.handle(requestText: "GET SHIORI/3.0\r\nID: OnMouseClick\r\n\(refs)\r\n\r\n")
        XCTAssertTrue(fiftieth.contains("50回目"), "got: \(fiftieth)")
    }

    func testHistoryPersistsAcrossEngineInstances() {
        let service = MockAIService(response: "記憶確認", delay: 0)
        let engine1 = makeEngine(service: service)
        _ = engine1.handle(requestText: "GET SHIORI/3.0\r\nID: OnCommunicate\r\nReference0: 覚えておいて\r\n\r\n")
        Thread.sleep(forTimeInterval: 0.3)
        _ = engine1.handle(requestText: "GET SHIORI/3.0\r\nID: OnSecondChange\r\n\r\n")

        // 新しいインスタンスでも履歴が読める(transcript.jsonl永続化)
        let history = ConversationHistory(limit: 10, dataDirectory: tempDir)
        XCTAssertEqual(history.turns.first?.text, "覚えておいて")
    }
}

//  © eightman 2005-2025
//  Furin-lab All Rights Reserved.
//  OurinAIPlugin 単体テスト

import XCTest
@testable import AINanikaCore

final class WireCodecTests: XCTestCase {
    func testParseStandardRequest() {
        let text = "GET SHIORI/3.0\r\nSender: Ourin\r\nID: OnCommunicate\r\nReference0: こんにちは\r\n\r\n"
        let request = WireCodec.parse(text)
        XCTAssertNotNil(request)
        XCTAssertEqual(request?.method, "GET")
        XCTAssertEqual(request?.id, "OnCommunicate")
        XCTAssertEqual(request?.reference(0), "こんにちは")
        XCTAssertEqual(request?.charset, "UTF-8")
    }

    func testParseKeepsReferenceGaps() {
        let text = "GET SHIORI/3.0\r\nID: OnMouseClick\r\nReference0: 0\r\nReference4: 100\r\nReference5: 200\r\n\r\n"
        let request = WireCodec.parse(text)
        XCTAssertEqual(request?.references["Reference0"], "0")
        XCTAssertNil(request?.reference(1))
        XCTAssertEqual(request?.reference(4), "100")
    }

    func testParseRejectsGarbage() {
        XCTAssertNil(WireCodec.parse("hello world"))
        XCTAssertNil(WireCodec.parse(""))
    }

    func testOkResponseFormat() {
        let wire = WireCodec.okResponse(value: "\\h\\s[0]テスト\\e")
        XCTAssertTrue(wire.hasSuffix("\r\n\r\n"))
        XCTAssertTrue(wire.contains("Value: \\h\\s[0]テスト\\e"))
        XCTAssertTrue(wire.hasPrefix("SHIORI/3.0 200 OK"))
    }

    func testOkResponseSanitizesNewlines() {
        // 台詞中の生改行はSakuraScriptの\nエスケープへ変換される(ヘッダ破壊防止)
        let wire = WireCodec.okResponse(value: "1行目\n2行目")
        XCTAssertTrue(wire.contains("1行目\\n2行目"))
        XCTAssertFalse(wire.contains("\n2"))
    }

    func testNoContentResponse() {
        XCTAssertEqual(WireCodec.noContentResponse(), "SHIORI/3.0 204 No Content\r\n\r\n")
    }
}

final class SakuraScriptBuilderTests: XCTestCase {
    func testSimple() {
        XCTAssertEqual(SakuraScriptBuilder.simple("あ"), "\\h\\s[0]あ\\e")
    }

    func testWithSurface() {
        XCTAssertEqual(SakuraScriptBuilder.withSurface("あ", surface: 12), "\\h\\s[12]あ\\e")
    }
}

final class CharacterStateTests: XCTestCase {
    func testUpdateOnClickConsecutive() {
        var state = CharacterState()
        let base = Date()
        state.updateOnClick(at: base)
        state.updateOnClick(at: base.addingTimeInterval(1.0))
        XCTAssertEqual(state.consecutiveClickCount, 2)
        state.updateOnClick(at: base.addingTimeInterval(10))
        XCTAssertEqual(state.consecutiveClickCount, 1)
        XCTAssertEqual(state.clickCount, 3)
    }

    func testBootCountAndHistoryPrune() {
        var state = CharacterState()
        let old = Calendar.current.date(byAdding: .day, value: -40, to: Date())!
        state.clickHistory = [old]
        state.updateOnBoot()
        XCTAssertEqual(state.totalBootCount, 2)
        XCTAssertTrue(state.clickHistory.isEmpty)
    }

    func testCodableRoundTripWithDefaults() {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let data = try! encoder.encode(CharacterState())
        let restored = try! decoder.decode(CharacterState.self, from: data)
        XCTAssertEqual(restored.totalBootCount, 1)
        XCTAssertEqual(restored.emotion.mood, 0.0)
    }
}

final class StateStoreTests: XCTestCase {
    private var tempDir: URL!

    override func setUp() {
        super.setUp()
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempDir)
        super.tearDown()
    }

    func testSaveLoadRoundTrip() {
        let store = StateStore(dataDirectory: tempDir)
        var state = store.load()
        state.emotion.mood = 0.5
        state.clickCount = 7
        store.save(state)

        let reloaded = StateStore(dataDirectory: tempDir).load()
        XCTAssertEqual(reloaded.clickCount, 7)
        XCTAssertEqual(reloaded.emotion.mood, 0.5, accuracy: 0.0001)
    }

    func testUpdateIsAtomic() {
        let store = StateStore(dataDirectory: tempDir)
        _ = store.update { $0.clickCount = 3 }
        _ = store.update { $0.emotion.affection = 0.2 }
        XCTAssertEqual(store.load().clickCount, 3)
        XCTAssertEqual(store.load().emotion.affection, 0.2, accuracy: 0.0001)
    }
}

final class DateTimeManagerTests: XCTestCase {
    func makeDate(_ month: Int, _ day: Int, hour: Int = 12) -> Date? {
        var components = DateComponents()
        components.year = 2026
        components.month = month
        components.day = day
        components.hour = hour
        return Calendar.current.date(from: components)
    }

    func testTimeOfDayBoundaries() {
        XCTAssertEqual(DateTimeManager.currentTimeOfDay(now: makeDate(6, 15, hour: 5)!), .morning)
        XCTAssertEqual(DateTimeManager.currentTimeOfDay(now: makeDate(6, 15, hour: 10)!), .afternoon)
        XCTAssertEqual(DateTimeManager.currentTimeOfDay(now: makeDate(6, 15, hour: 18)!), .evening)
        XCTAssertEqual(DateTimeManager.currentTimeOfDay(now: makeDate(6, 15, hour: 22)!), .night)
        XCTAssertEqual(DateTimeManager.currentTimeOfDay(now: makeDate(6, 15, hour: 3)!), .lateNight)
    }

    func testSeasonalEvents() {
        XCTAssertEqual(DateTimeManager.currentSeason(now: makeDate(12, 24)!), .christmas)
        XCTAssertEqual(DateTimeManager.currentSeason(now: makeDate(1, 3)!), .newYear)
        XCTAssertEqual(DateTimeManager.currentSeason(now: makeDate(2, 14)!), .valentines)
        XCTAssertEqual(DateTimeManager.currentSeason(now: makeDate(7, 15)!), .summer)
    }

    func testTimeSinceLastAccess() {
        let now = makeDate(6, 15)!
        XCTAssertEqual(DateTimeManager.timeSinceLastAccess(now.addingTimeInterval(-3600 * 48), now: now), "2日ぶりですね")
        XCTAssertEqual(DateTimeManager.timeSinceLastAccess(now.addingTimeInterval(-300), now: now), "お帰りなさい")
    }
}

final class PromptBuilderTests: XCTestCase {
    func testSystemPromptContainsPersonaAndState() {
        var state = CharacterState()
        state.emotion.mood = -0.8
        state.clickCount = 120
        let prompt = PromptBuilder.systemPrompt(persona: "あなたは猫耳メイドです。", state: state)
        XCTAssertTrue(prompt.contains("猫耳メイド"))
        XCTAssertTrue(prompt.contains("機嫌: 悪い"))
        XCTAssertTrue(prompt.contains("累計クリック数: 120"))
    }

    func testDefaultPersonaWhenEmpty() {
        let prompt = PromptBuilder.systemPrompt(persona: nil, state: CharacterState())
        XCTAssertTrue(prompt.contains("AI何かちゃん"))
    }

    func testShapeReplyEscapesNewlines() {
        XCTAssertEqual(PromptBuilder.shapeReply("a\nb", enabled: true), "a\\nb")
        XCTAssertEqual(PromptBuilder.shapeReply("a\nb", enabled: false), "a\nb")
    }
}

final class PluginConfigurationTests: XCTestCase {
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

    func testLoadMissingReturnsNil() {
        XCTAssertNil(PluginConfiguration.load(from: tempDir))
    }

    func testPartialJSONFillsDefaults() throws {
        let json = """
        {"provider": "gemini", "apiKey": "TEST"}
        """
        try json.write(to: tempDir.appendingPathComponent("ai_config.json"), atomically: true, encoding: .utf8)
        let config = PluginConfiguration.load(from: tempDir)
        XCTAssertEqual(config?.provider, .gemini)
        XCTAssertEqual(config?.apiKey, "TEST")
        XCTAssertEqual(config?.maxTokens, 300)
        XCTAssertEqual(config?.historyLimit, 10)
    }
}

final class ConversationHistoryTests: XCTestCase {
    private var tempDir: URL!

    override func setUp() {
        super.setUp()
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempDir)
        super.tearDown()
    }

    func testRingBufferLimit() {
        let history = ConversationHistory(limit: 3, dataDirectory: nil)
        for i in 0..<6 { history.addUser("m\(i)") }
        let texts = history.turns.map(\.text)
        XCTAssertEqual(texts, ["m3", "m4", "m5"])
    }

    func testPersistenceAcrossInstances() {
        let a = ConversationHistory(limit: 10, dataDirectory: tempDir)
        a.addUser("こんにちは")
        a.addAssistant("やっほー")

        let b = ConversationHistory(limit: 10, dataDirectory: tempDir)
        XCTAssertEqual(b.turns.count, 2)
        XCTAssertEqual(b.turns.first?.role, "user")
        XCTAssertEqual(b.turns.last?.text, "やっほー")
    }
}

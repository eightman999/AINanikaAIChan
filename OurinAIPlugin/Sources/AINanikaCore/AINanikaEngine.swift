//  © eightman 2005-2025
//  Furin-lab All Rights Reserved.
//  SHIORIイベント処理コア(非同期応答ループの中核)

import Foundation

/// ペンディング応答(OnSecondChangeで配送される)
public struct PendingReply: Equatable {
    let script: String
    let createdAt: Date
}

/// SHIORIリクエストを処理し、LLM生成はバックグラウンドで実行して
/// 次のOnSecondChangeで完成スクリプトを返す「watchdog安全」なエンジン。
public final class AINanikaEngine {
    private let configuration: PluginConfiguration
    private let stateStore: StateStore
    private let history: ConversationHistory
    private let persona: String?
    private let aiService: AIService?

    /// OnSecondChangeで配送待ちの応答(直列アクセス)
    private var pendingReplies: [PendingReply] = []
    /// 進行中の生成数(ACK多重防止用)
    private var inFlightCount = 0
    /// 生成完了時に感情・状態へ与えるフィードバック用のロック
    private let lock = NSLock()
    private let maxPending = 4

    public static let versionString = "AINanikaSHIORI/1.0"

    public init(configuration: PluginConfiguration,
                dataDirectory: URL?,
                persona: String?,
                aiService: AIService?) {
        self.configuration = configuration
        self.stateStore = StateStore(dataDirectory: dataDirectory ?? FileManager.default.temporaryDirectory.appendingPathComponent("ainanika-state"))
        self.history = ConversationHistory(limit: configuration.historyLimit, dataDirectory: dataDirectory)
        self.persona = persona
        self.aiService = aiService
    }

    /// 設定+ディレクトリから構築(load時)
    public convenience init(loadDirectory: URL) {
        let configuration = PluginConfiguration.load(from: loadDirectory) ?? PluginConfiguration()
        // persona.md: 明示パス or load dir or master dir(親)
        var personaText: String?
        let candidates = [
            configuration.personaPath.isEmpty ? nil : URL(fileURLWithPath: configuration.personaPath),
            loadDirectory.appendingPathComponent("persona.md"),
            loadDirectory.deletingLastPathComponent().appendingPathComponent("persona.md")
        ]
        for url in candidates.compactMap({ $0 }) {
            if let text = try? String(contentsOf: url, encoding: .utf8), !text.isEmpty {
                personaText = text
                break
            }
        }
        let service = AIServiceFactory.make(configuration: configuration)
        // ghost/master/data をデータ保存先とする(load dirの親がmaster想定)
        let masterDir = loadDirectory.deletingLastPathComponent()
        self.init(configuration: configuration,
                  dataDirectory: masterDir.appendingPathComponent("data"),
                  persona: personaText,
                  aiService: service)
    }

    /// SHIORIワイヤ形式のリクエストを処理する。必ず数百ms以内に返る。
    public func handle(requestText: String) -> String {
        guard let request = WireCodec.parse(requestText) else {
            return WireCodec.badRequestResponse()
        }
        switch request.id {
        case "Version":
            return WireCodec.okResponse(value: Self.versionString)

        case "OnBoot", "OnFirstBoot":
            return handleBoot(firstBoot: request.id == "OnFirstBoot")

        case "OnClose":
            return handleClose()

        case "OnCommunicate":
            return handleUserInput(request.reference(0) ?? "")

        case "OnTalk":
            return handleUserInput(request.reference(0) ?? "")

        case "OnUserInput":
            // Reference1に入力値(IDはcommunicatebox等の識別子)
            return handleUserInput(request.reference(1) ?? "")

        case "OnMouseClick":
            return handleClick(references: request.references)

        case "OnSecondChange":
            return handleSecondChange()

        case "OnSurfaceChange", "OnNotifyOther", "OnOtherGhostTalk":
            return WireCodec.noContentResponse()

        default:
            // 未対応イベントは黙って返す=ネイティブ挙動(YAYA等)を妨げない
            return WireCodec.noContentResponse()
        }
    }

    // MARK: - イベント処理

    private func handleBoot(firstBoot: Bool) -> String {
        let state = stateStore.update { $0.updateOnBoot() }
        let greeting = DateTimeManager.greetingForTimeOfDay()
        var message: String

        if firstBoot {
            message = "初めまして！AI何かちゃんです。\\nこれからよろしくね。"
        } else if let lastBoot = state.lastBootTime, DateTimeManager.currentSeason() == .christmas {
            _ = lastBoot
            message = "🎄メリークリスマス！\\n今日も一緒に過ごしましょう。"
        } else if DateTimeManager.currentSeason() == .newYear {
            message = "🎍あけましておめでとう！\\n今年もよろしくお願いします。"
        } else if state.totalBootCount > 1, let last = state.lastBootTime {
            let away = DateTimeManager.timeSinceLastAccess(last, now: Date())
            message = "\(greeting)。\(away)。"
        } else {
            message = "\(greeting)!"
        }
        if let seasonal = DateTimeManager.seasonalMessage(), Bool.random() {
            message += "\\n\(seasonal)"
        }
        history.addAssistant(SakuraScriptBuilder.plaintext(message))
        return WireCodec.okResponse(value: SakuraScriptBuilder.simple(message))
    }

    private func handleClose() -> String {
        let messages = ["また会いましょうね！", "お疲れさまでした、またね！", "バイバイ、また遊びに来てね。"]
        let message = messages.randomElement()!
        history.addAssistant(message)
        return WireCodec.okResponse(value: SakuraScriptBuilder.simple(message))
    }

    /// ユーザー入力受付: 即時ACKを返し、LLM生成はバックグラウンドへ投げる
    private func handleUserInput(_ text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return WireCodec.noContentResponse()
        }
        history.addUser(trimmed)

        lock.lock()
        let alreadyBusy = inFlightCount > 0
        lock.unlock()

        if alreadyBusy {
            // 応答中の重複入力は静かに受付のみ行う(次回まとめて応答)
            return WireCodec.noContentResponse()
        }
        startGeneration(userMessage: trimmed)
        // 即時ACK(設定可能)
        return WireCodec.okResponse(value: configuration.ackScript)
    }

    /// バックグラウンドでLLM呼び出しを実行し、結果をペンディングキューへ積む
    private func startGeneration(userMessage: String) {
        guard let service = aiService else {
            // AI未設定: ローカルの時間帯応じた会話で代替(graceful degradation)
            enqueue(PendingReply(script: fallbackScript(for: userMessage), createdAt: Date()))
            return
        }
        lock.lock()
        inFlightCount += 1
        lock.unlock()

        let state = stateStore.load()
        let context = GenerationContext(
            systemPrompt: PromptBuilder.systemPrompt(persona: persona, state: state),
            history: history.turns.map { ChatMessage(role: $0.role, content: $0.text) }
        )
        let maxTokens = configuration.maxTokens
        let timeout = configuration.timeoutSeconds

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            // LLM呼び出しはここで完了を待つ(SHIORIリクエストスレッドとは別)
            var generated: Result<String, Error>
            do {
                let text = try blockingGenerate(service: service, context: context, maxTokens: maxTokens, timeout: timeout)
                generated = .success(text)
            } catch {
                generated = .failure(error)
            }

            guard let self else { return }
            self.lock.lock()
            self.inFlightCount -= 1
            self.lock.unlock()

            switch generated {
            case .success(let text):
                let shaped = PromptBuilder.shapeReply(text, enabled: self.configuration.splitLongReply)
                self.history.addAssistant(text)
                self.stateStore.update {
                    // 会話できたので親愛度をわずかに上げる
                    $0.emotion.affection = min(1.0, $0.emotion.affection + 0.01)
                }
                self.enqueue(PendingReply(script: SakuraScriptBuilder.simple(shaped), createdAt: Date()))
            case .failure:
                self.enqueue(PendingReply(script: self.configuration.errorScript, createdAt: Date()))
            }
        }
    }

    /// OnSecondChange: ペンディング応答があれば1件返す
    private func handleSecondChange() -> String {
        lock.lock()
        defer { lock.unlock() }
        guard !pendingReplies.isEmpty else { return WireCodec.noContentResponse() }
        let reply = pendingReplies.removeFirst()
        return WireCodec.okResponse(value: reply.script)
    }

    private func handleClick(references: [String: String]) -> String {
        let surface = Int(references["Reference3"] ?? references["Reference0"] ?? "0") ?? 0
        let x = Int(references["Reference4"] ?? references["Reference1"] ?? "0") ?? 0
        let y = Int(references["Reference5"] ?? references["Reference2"] ?? "0") ?? 0

        let region = ClickRegion.from(x: x, y: y, surfaceId: surface)
        let now = Date()

        let state = stateStore.update { state in
            state.updateOnClick(at: now)
            switch region {
            case .head:
                state.emotion.mood = min(1.0, state.emotion.mood + 0.1)
                state.emotion.affection = min(1.0, state.emotion.affection + 0.05)
            case .body:
                state.emotion.mood = max(-1.0, state.emotion.mood - 0.02)
            case .other:
                break
            }
        }

        // 記念クリック最優先
        if state.clickCount % 50 == 0 && state.clickCount > state.lastCelebratedClickCount {
            stateStore.update { $0.lastCelebratedClickCount = state.clickCount }
            let script = "\\w[500]\\h\\s[10]やったー！通算\(state.clickCount)回目のクリック、ありがとう！\\e"
            return WireCodec.okResponse(value: script)
        }

        let mood = state.emotion.mood
        let response = ClickReactions.response(region: region, mood: mood)
        return WireCodec.okResponse(value: response)
    }

    // MARK: - ユーティリティ

    private func enqueue(_ reply: PendingReply) {
        lock.lock()
        defer { lock.unlock() }
        pendingReplies.append(reply)
        // 溢れたら最古を破棄
        if pendingReplies.count > maxPending {
            pendingReplies.removeFirst(pendingReplies.count - maxPending)
        }
    }

    /// AI未設定/オフライン時のフォールバック会話
    private func fallbackScript(for userMessage: String) -> String {
        let greeting = DateTimeManager.greetingForTimeOfDay()
        let responses = [
            "\(greeting)!今日もよろしくね。",
            "うんうん、そうなんだ。",
            "AIサービスが未設定みたい。ai_config.jsonを確認してみてね。",
            "何か話しかけられた気がして嬉しいな。"
        ]
        return SakuraScriptBuilder.simple(responses.randomElement()!)
    }
}

private extension SakuraScriptBuilder {
    /// 台詞部分だけを抜き出す簡易処理(\e等のタグを除去)
    static func plaintext(_ script: String) -> String {
        script.replacingOccurrences(of: "\\e", with: "")
    }
}

/// asyncなAI生成を同期文脈(DispatchQueue)から呼ぶためのブリッジ
private func blockingGenerate(service: AIService, context: GenerationContext, maxTokens: Int, timeout: Double) throws -> String {
    final class Box: @unchecked Sendable {
        var result: Result<String, Error>?
    }
    let box = Box()
    let semaphore = DispatchSemaphore(value: 0)
    Task.detached(priority: .userInitiated) {
        do {
            box.result = .success(try await service.generate(context, maxTokens: maxTokens, timeoutSeconds: timeout))
        } catch {
            box.result = .failure(error)
        }
        semaphore.signal()
    }
    semaphore.wait()
    switch box.result {
    case .success(let text): return text
    case .failure(let error): throw error
    case nil: throw AIError.networkError
    }
}

//  © eightman 2005-2025
//  Furin-lab All Rights Reserved.
//  純粋なSwift実装のSHIORIエンジン（C#版からの移行）

import Foundation
import AppKit

/// SHIORI プロトコルのリクエスト構造
struct SHIORIRequest {
    let version: String
    let method: String
    let id: String
    let references: [String: String]
    
    static func parse(_ requestText: String) -> SHIORIRequest? {
        let lines = requestText.components(separatedBy: .newlines)
        guard !lines.isEmpty else { return nil }
        
        let firstLine = lines[0].trimmingCharacters(in: .whitespaces)
        let parts = firstLine.components(separatedBy: " ")
        guard parts.count >= 3 else { return nil }
        
        let method = parts[0]
        let version = parts[1]
        
        var id = ""
        var references: [String: String] = [:]
        
        for line in lines.dropFirst() {
            let trimmedLine = line.trimmingCharacters(in: .whitespaces)
            if trimmedLine.isEmpty { break }
            
            let colonRange = trimmedLine.range(of: ": ")
            guard let range = colonRange else { continue }
            
            let key = String(trimmedLine[..<range.lowerBound])
            let value = String(trimmedLine[range.upperBound...])
            
            if key == "ID" {
                id = value
            } else if key.hasPrefix("Reference") {
                references[key] = value
            }
        }
        
        return SHIORIRequest(version: version, method: method, id: id, references: references)
    }
    
    func getReference(_ index: Int) -> String? {
        return references["Reference\(index)"]
    }
}

/// SHIORI プロトコルのレスポンス構造
struct SHIORIResponse {
    let statusCode: Int
    let statusText: String
    let value: String
    
    init(value: String, statusCode: Int = 200, statusText: String = "OK") {
        self.value = value
        self.statusCode = statusCode
        self.statusText = statusText
    }
    
    func toString() -> String {
        return """
        SHIORI/3.0 \(statusCode) \(statusText)\r
        Content-Type: text/plain\r
        Value: \(value)\r
        \r

        """
    }
}

/// SakuraScript 生成ユーティリティ
struct SakuraScriptBuilder {
    static func simple(_ text: String) -> String {
        return "\\h\\s[0]\(text)\\e"
    }
    
    static func withSurface(_ text: String, surface: Int) -> String {
        return "\\h\\s[\(surface)]\(text)\\e"
    }
    
    /// アニメーションを伴う会話（開始サーフェスと終了サーフェスを指定）
    static func animatedTalk(_ text: String, startSurface: Int, endSurface: Int) -> String {
        return "\\s[\(startSurface)]\\h\(text)\\s[\(endSurface)]\\e"
    }
    
    /// ユーザーに選択肢を提示する
    static func choice(_ text: String, options: [String]) -> String {
        let choiceScripts = options.map { "\\q[\(\($0)),OnTalk,\"\($0)\"]" }.joined(separator: " ")
        return "\\h\(text) \(choiceScripts)\\e"
    }
    
    /// 特定の場所にバルーンを表示する
    static func balloonOffset(_ text: String, x: Int, y: Int, scope: Int = 0) -> String {
        let scopePrefix = scope == 0 ? "\\h" : "\\u"
        return "\\p[\(scope)]\\b[\(x),\(y)]\(scopePrefix)\(text)\\e"
    }
}

/// AIサービスの抽象インターフェース
protocol AIServiceProtocol {
    func generateResponse(prompt: String) async throws -> String
}

/// クリックされた体の部位
enum ClickRegion {
    case head
    case body
    case other
    
    /// 座標から部位を判定します。
    /// surfaceIdや座標の範囲は、実際のキャラクターのサーフェス定義に合わせて調整してください。
    static func from(x: Int, y: Int, surfaceId: Int) -> ClickRegion {
        // 例：サーフェス0番での判定（実際のキャラクター画像サイズに合わせて調整）
        if surfaceId == 0 {
            if (50..<200).contains(x) && (50..<150).contains(y) {
                return .head
            } else if (50..<200).contains(x) && (150..<400).contains(y) {
                return .body
            }
        }
        // 他のサーフェスIDでの判定もここに追加できます。
        return .other
    }
}

/// キャラクターの感情状態
struct EmotionState: Codable {
    /// 機嫌の良し悪し (-1.0: 不機嫌 ～ 1.0: ご機嫌)
    var mood: Double = 0.0
    /// ユーザーへの親愛度 (0.0 ～ 1.0)
    var affection: Double = 0.0
    
    /// 時間経過による機嫌の自然な平常化
    mutating func naturalMoodDecay() {
        mood *= 0.99 // 機嫌が少しずつ平常値(0.0)に近づく
    }
}

/// キャラクターの全状態を保持する構造体
struct CharacterState: Codable {
    // クリック関連の状態
    var clickCount: Int = 0
    var lastClickTime: Date? = nil
    var consecutiveClickCount: Int = 0
    
    // 感情モデル
    var emotion: EmotionState = EmotionState()
    
    // ユーザー習慣学習用
    var clickHistory: [Date] = []
    
    // 記念クリックの追跡
    var lastCelebratedClickCount: Int = 0
    
    // アプリ起動履歴
    var lastBootTime: Date? = nil
    var totalBootCount: Int = 0
    
    // 初回セットアップ日時
    var firstLaunchDate: Date? = nil
    
    /// 初期化時に初回起動日時を設定
    init() {
        let now = Date()
        self.firstLaunchDate = now
        self.lastBootTime = now
        self.totalBootCount = 1
    }
}

/// 時間帯の分類
enum TimeOfDay: String, CaseIterable {
    case morning = "朝"
    case afternoon = "昼"
    case evening = "夕方"
    case night = "夜"
    case lateNight = "深夜"
}

/// 季節とイベントの分類
enum Season: String, CaseIterable {
    case spring = "春"
    case summer = "夏"
    case autumn = "秋"
    case winter = "冬"
    case newYear = "お正月"
    case christmas = "クリスマス"
}

/// 簡単な状態管理クラス
class SimpleStateManager {
    static let shared = SimpleStateManager()
    private let userDefaults = UserDefaults.standard
    private let stateKey = "characterState_v2"
    
    private init() {}
    
    func saveState(_ state: CharacterState) {
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(state)
            userDefaults.set(data, forKey: stateKey)
        } catch {
            print("Error saving state: \(error)")
        }
    }
    
    func loadState() -> CharacterState {
        guard let data = userDefaults.data(forKey: stateKey) else {
            return CharacterState()
        }
        
        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            return try decoder.decode(CharacterState.self, from: data)
        } catch {
            print("Error loading state: \(error)")
            return CharacterState()
        }
    }
}

/// 日時判定ヘルパー
class DateTimeHelper {
    static func getCurrentTimeOfDay() -> TimeOfDay {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<10: return .morning
        case 10..<17: return .afternoon
        case 17..<20: return .evening
        case 20..<24: return .night
        default: return .lateNight
        }
    }
    
    static func getCurrentSeason() -> Season {
        let month = Calendar.current.component(.month, from: Date())
        let day = Calendar.current.component(.day, from: Date())
        
        if month == 12 && day >= 20 && day <= 25 { return .christmas }
        if month == 1 && day >= 1 && day <= 7 { return .newYear }
        
        switch month {
        case 3...5: return .spring
        case 6...8: return .summer
        case 9...11: return .autumn
        default: return .winter
        }
    }
    
    static func getGreeting() -> String {
        switch getCurrentTimeOfDay() {
        case .morning: return "おはよう"
        case .afternoon: return "こんにちは"
        case .evening: return "こんばんは"
        case .night: return "お疲れさま"
        case .lateNight: return "夜更かしですね"
        }
    }
}

/// 純粋Swift実装のSHIORIエンジン
class SwiftSHIORI {
    private var aiService: AIServiceProtocol?
    private let startTime = Date()
    
    init(aiService: AIServiceProtocol? = nil) {
        self.aiService = aiService
    }
    
    /// SHIORI リクエストを処理してレスポンスを返す
    func processRequest(_ requestText: String) async -> String {
        print("[SwiftSHIORI] Processing request: \(requestText.prefix(100))...")
        
        guard let request = SHIORIRequest.parse(requestText) else {
            print("[SwiftSHIORI] ERROR: Failed to parse request")
            return SHIORIResponse(value: "", statusCode: 400, statusText: "Bad Request").toString()
        }
        
        print("[SwiftSHIORI] Parsed request ID: \(request.id)")
        let value: String
        
        switch request.id {
        case "Version":
            value = "SwiftSHIORI 1.0.0"
            
        case "OnBoot":
            // 状態を読み込んでブート時更新
            var state = SimpleStateManager.shared.loadState()
            let now = Date()
            state.lastBootTime = now
            state.totalBootCount += 1
            state.emotion.naturalMoodDecay()
            
            // 時間帯に応じた挨拶
            let greeting = DateTimeHelper.getGreeting()
            let timeOfDay = DateTimeHelper.getCurrentTimeOfDay()
            let season = DateTimeHelper.getCurrentSeason()
            
            var bootMessage: String
            
            // 季節の挨拶を優先
            if season == .christmas {
                bootMessage = "🎄 メリークリスマス！\\nクリスマスですね。楽しい時間を過ごしましょう。"
            } else if season == .newYear {
                bootMessage = "🎍 あけましておめでとうございます！\\n新年もよろしくお願いします。"
            } else {
                // 時間帯による挨拶
                switch timeOfDay {
                case .morning:
                    bootMessage = "おはよう！\\n良い朝ですね。今日も頑張りましょう。"
                case .afternoon:
                    bootMessage = "こんにちは！\\n午後もよろしくお願いします。"
                case .evening:
                    bootMessage = "こんばんは！\\n夕方の時間ですね。お疲れさまです。"
                case .night:
                    bootMessage = "こんばんは！\\n夜の時間を一緒に過ごしましょう。"
                case .lateNight:
                    bootMessage = "夜更かしですね！\\n無理しないでくださいね。"
                }
            }
            
            value = SakuraScriptBuilder.simple(bootMessage)
            SimpleStateManager.shared.saveState(state)
            
        case "OnClose":
            let closeMessages = [
                "また会いましょうね！さようなら！",
                "お疲れさまでした！また今度！",
                "バイバイ！また遊びに来てください。"
            ]
            value = SakuraScriptBuilder.simple(closeMessages.randomElement()!)
            
        case "OnMouseClick":
            // 状態を読み込み
            var state = SimpleStateManager.shared.loadState()
            
            // クリック情報の取得
            let surfaceId = Int(request.getReference(0) ?? "0") ?? 0
            let x = Int(request.getReference(1) ?? "0") ?? 0
            let y = Int(request.getReference(2) ?? "0") ?? 0
            let now = Date()
            
            // 状態を更新
            state.clickCount += 1
            if let lastTime = state.lastClickTime, now.timeIntervalSince(lastTime) < 2.0 {
                state.consecutiveClickCount += 1
            } else {
                state.consecutiveClickCount = 1
            }
            state.lastClickTime = now
            state.clickHistory.append(now)
            
            // クリック部位判定
            let region = ClickRegion.from(x: x, y: y, surfaceId: surfaceId)
            
            // 感情の更新
            switch region {
            case .head:
                state.emotion.mood = min(1.0, state.emotion.mood + 0.1)
                state.emotion.affection = min(1.0, state.emotion.affection + 0.05)
            case .body:
                state.emotion.mood = max(-1.0, state.emotion.mood - 0.02)
            case .other:
                break
            }
            
            // 時間帯と季節の取得
            let timeOfDay = DateTimeHelper.getCurrentTimeOfDay()
            let season = DateTimeHelper.getCurrentSeason()
            
            // レスポンス決定
            // 記念クリック（最優先）
            if state.clickCount % 50 == 0 && state.clickCount > state.lastCelebratedClickCount {
                state.lastCelebratedClickCount = state.clickCount
                value = "\\w[500]\\h\\s[10]やったー！\\n通算\(state.clickCount)回目のクリック、ありがとう！\\e"
            }
            // 季節イベント
            else if season == .christmas {
                value = "\\s[0]メリークリスマス🎄\\n何かプレゼントくれるの？\\e"
            }
            else if season == .newYear {
                value = "\\s[0]あけましておめでとう🎍\\n今年もよろしくね！\\e"
            }
            // 連続クリック
            else if state.consecutiveClickCount >= 5 {
                state.consecutiveClickCount = 0
                if let service = aiService {
                    do {
                        let prompt = "ユーザーが連続で私をクリックしています。簡潔に面白く反応してください。"
                        let response = try await service.generateResponse(prompt: prompt)
                        value = SakuraScriptBuilder.withSurface(response, surface: 12)
                    } catch {
                        value = "\\s[12]わわっ！びっくりした！\\e"
                    }
                } else {
                    value = "\\s[12]わわっ！びっくりした！\\e"
                }
            }
            // 通常のクリック（部位と感情状態による分岐）
            else {
                value = getClickResponse(region: region, emotion: state.emotion, timeOfDay: timeOfDay)
            }
            
            // 効果音を再生（オプション）
            playClickSound()
            
            // 状態を保存
            SimpleStateManager.shared.saveState(state)
            
        case "OnSecondChange":
            // 頻繁なイベントなので空のレスポンスを返す
            value = ""
            
        case "OnTalk":
            let state = SimpleStateManager.shared.loadState()
            let timeOfDay = DateTimeHelper.getCurrentTimeOfDay()
            
            if let prompt = request.getReference(0), let service = aiService {
                do {
                    // 状態情報を含めたAIプロンプト
                    let contextPrompt = """
                    ユーザーからのメッセージ: \(prompt)
                    現在の時間帯: \(timeOfDay.rawValue)
                    キャラクターの機嫌: \(state.emotion.mood)
                    ユーザーへの親愛度: \(state.emotion.affection)
                    
                    上記を踏まえて、キャラクターらしく簡潔に返答してください。
                    """
                    let response = try await service.generateResponse(prompt: contextPrompt)
                    value = SakuraScriptBuilder.simple(response)
                } catch {
                    value = SakuraScriptBuilder.simple("申し訳ありません。AIサービスでエラーが発生しました。")
                }
            } else {
                // AIサービスがない場合の時間帯応じた会話
                let greeting = DateTimeHelper.getGreeting()
                let talkResponses = [
                    "\(greeting)！今日はどんなことがありましたか？",
                    "何かお話ししましょうか？",
                    "最近どうですか？何か面白いことはありましたか？",
                    getTimeBasedResponse(timeOfDay: timeOfDay)
                ]
                value = SakuraScriptBuilder.simple(talkResponses.randomElement()!)
            }
            
        default:
            value = ""
        }
        
        let response = SHIORIResponse(value: value).toString()
        print("[SwiftSHIORI] Returning response with value: '\(value)'")
        print("[SwiftSHIORI] Full response: \(response.prefix(200))...")
        return response
    }
    
    /// クリック反応を生成
    private func getClickResponse(region: ClickRegion, emotion: EmotionState, timeOfDay: TimeOfDay) -> String {
        // 感情状態による分岐
        if emotion.mood < -0.5 {
            return getGrumpyResponse(region: region, timeOfDay: timeOfDay)
        } else if emotion.mood > 0.5 {
            return getHappyResponse(region: region, timeOfDay: timeOfDay)
        } else {
            return getNeutralResponse(region: region, timeOfDay: timeOfDay)
        }
    }
    
    /// 機嫌が良い時の反応
    private func getHappyResponse(region: ClickRegion, timeOfDay: TimeOfDay) -> String {
        switch region {
        case .head:
            let responses = [
                "えへへ〜！なでてくれてありがとう〜！\\s[10]",
                "とっても気持ちいいよ〜！\\s[11]",
                "もっともっと〜！\\s[10]"
            ]
            return SakuraScriptBuilder.simple(responses.randomElement()!)
            
        case .body:
            let responses = [
                "きゃー！くすぐったいよ〜！\\s[12]",
                "えへへ、そんなところ撫でちゃだめ〜！\\s[13]"
            ]
            return SakuraScriptBuilder.simple(responses.randomElement()!)
            
        case .other:
            let timeGreeting = getTimeBasedResponse(timeOfDay: timeOfDay)
            return SakuraScriptBuilder.simple("今日もいい天気！\(timeGreeting)")
        }
    }
    
    /// 通常の機嫌の時の反応
    private func getNeutralResponse(region: ClickRegion, timeOfDay: TimeOfDay) -> String {
        switch region {
        case .head:
            let responses = [
                "なでなで、ありがとう。\\s[0]",
                "そこを撫でられると嬉しいな。\\s[1]",
                "もっと撫でてほしいな。\\s[2]"
            ]
            return SakuraScriptBuilder.simple(responses.randomElement()!)
            
        case .body:
            let responses = [
                "何か用事かな？",
                "そこはちょっとくすぐったいかも。\\s[5]"
            ]
            return SakuraScriptBuilder.simple(responses.randomElement()!)
            
        case .other:
            let timeGreeting = getTimeBasedResponse(timeOfDay: timeOfDay)
            return SakuraScriptBuilder.simple(timeGreeting)
        }
    }
    
    /// 機嫌が悪い時の反応
    private func getGrumpyResponse(region: ClickRegion, timeOfDay: TimeOfDay) -> String {
        switch region {
        case .head:
            let responses = [
                "んっ、今はあんまり気分じゃないかも…。\\s[6]",
                "ちょっと疑わしい気分。\\s[7]"
            ]
            return SakuraScriptBuilder.simple(responses.randomElement()!)
            
        case .body:
            return SakuraScriptBuilder.simple("やめてよ、今はあんまり触らないで。\\s[8]")
            
        case .other:
            return SakuraScriptBuilder.simple("ふん、今はあんまりお話ししたくない気分。\\s[9]")
        }
    }
    
    /// 時間帯に応じたメッセージ
    private func getTimeBasedResponse(timeOfDay: TimeOfDay) -> String {
        switch timeOfDay {
        case .morning:
            return "朝の時間ですね。今日も頑張りましょう。"
        case .afternoon:
            return "昼間の時間ですね。午後もよろしく。"
        case .evening:
            return "夕方の時間ですね。お疲れさまでした。"
        case .night:
            return "夜の時間ですね。ゆっくりしましょう。"
        case .lateNight:
            return "深夜ですね。早めに寝た方がいいですよ。"
        }
    }
    
    /// クリック音の再生（オプション）
    private func playClickSound() {
        // システムサウンドを再生（簡易版）
        NSSound(named: "Ping")?.play()
    }
}

/// 簡単なChatGPT AIサービス実装の例
class ChatGPTService: AIServiceProtocol {
    private let apiKey: String
    private let model: String
    
    init(apiKey: String, model: String = "gpt-3.5-turbo") {
        self.apiKey = apiKey
        self.model = model
    }
    
    func generateResponse(prompt: String) async throws -> String {
        // ChatGPT API呼び出しの実装（簡略版）
        guard !apiKey.isEmpty else {
            return "APIキーが設定されていません。"
        }
        
        let url = URL(string: "https://api.openai.com/v1/chat/completions")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let payload: [String: Any] = [
            "model": model,
            "messages": [
                ["role": "user", "content": prompt]
            ],
            "max_tokens": 150
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)
        
        let (data, _) = try await URLSession.shared.data(for: request)
        
        // レスポンスのパース（簡略版）
        if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
           let choices = json["choices"] as? [[String: Any]],
           let firstChoice = choices.first,
           let message = firstChoice["message"] as? [String: Any],
           let content = message["content"] as? String {
            return content.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        
        return "応答を取得できませんでした。"
    }
}
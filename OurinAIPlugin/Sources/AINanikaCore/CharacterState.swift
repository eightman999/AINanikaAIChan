//  © eightman 2005-2025
//  Furin-lab All Rights Reserved.
//  キャラクターの全状態を保持する構造体(旧CharacterState.swiftから移植)

import Foundation

/// キャラクターの全状態
struct CharacterState: Codable, Equatable {
    // クリック関連の状態
    var clickCount: Int = 0
    var lastClickTime: Date? = nil
    var consecutiveClickCount: Int = 0

    // 感情モデル
    var emotion = EmotionState()

    // ユーザー習慣学習用
    var clickHistory: [Date] = []

    // 記念クリックの追跡
    var lastCelebratedClickCount: Int = 0

    // 起動履歴
    var lastBootTime: Date? = nil
    var totalBootCount: Int = 0

    // 初回セットアップ日時
    var firstLaunchDate: Date? = nil

    /// 新規状態を作成(初回起動日時を記録)
    init() {
        let now = Date()
        self.firstLaunchDate = now
        self.lastBootTime = now
        self.totalBootCount = 1
    }

    /// デコード用イニシャライザ(デフォルト値で欠損フィールドを補完)
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        clickCount = try c.decodeIfPresent(Int.self, forKey: .clickCount) ?? 0
        lastClickTime = try c.decodeIfPresent(Date.self, forKey: .lastClickTime)
        consecutiveClickCount = try c.decodeIfPresent(Int.self, forKey: .consecutiveClickCount) ?? 0
        emotion = try c.decodeIfPresent(EmotionState.self, forKey: .emotion) ?? EmotionState()
        clickHistory = try c.decodeIfPresent([Date].self, forKey: .clickHistory) ?? []
        lastCelebratedClickCount = try c.decodeIfPresent(Int.self, forKey: .lastCelebratedClickCount) ?? 0
        lastBootTime = try c.decodeIfPresent(Date.self, forKey: .lastBootTime)
        totalBootCount = try c.decodeIfPresent(Int.self, forKey: .totalBootCount) ?? 0
        firstLaunchDate = try c.decodeIfPresent(Date.self, forKey: .firstLaunchDate)
    }

    /// 起動時に呼び出して状態を更新
    mutating func updateOnBoot(now: Date = Date()) {
        lastBootTime = now
        totalBootCount += 1
        emotion.naturalMoodDecay()
        // 30日以上前のクリック履歴を削除
        if let cutoff = Calendar.current.date(byAdding: .day, value: -30, to: now) {
            clickHistory = clickHistory.filter { $0 > cutoff }
        }
    }

    /// クリックイベント時に呼び出して状態を更新
    mutating func updateOnClick(at date: Date = Date()) {
        clickCount += 1
        if let lastTime = lastClickTime, date.timeIntervalSince(lastTime) < 2.0 {
            consecutiveClickCount += 1
        } else {
            consecutiveClickCount = 1
        }
        lastClickTime = date
        clickHistory.append(date)
    }

    /// ユーザーが普段よく利用する時間帯かどうか(習慣学習)
    func isUsualTimeForUser(at date: Date = Date()) -> Bool {
        guard clickHistory.count >= 10 else { return false }
        let currentHour = Calendar.current.component(.hour, from: date)
        let sameHourClicks = clickHistory.filter { clickDate in
            let hour = Calendar.current.component(.hour, from: clickDate)
            return abs(hour - currentHour) <= 1
        }
        return Double(sameHourClicks.count) / Double(clickHistory.count) >= 0.3
    }
}

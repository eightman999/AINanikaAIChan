//  © eightman 2005-2025
//  Furin-lab All Rights Reserved.
//  プロジェクト共通の型定義

import Foundation

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
    case valentines = "バレンタイン"
    case whiteDays = "ホワイトデー"
    case halloween = "ハロウィン"
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
    
    /// アプリ起動時に呼び出して状態を更新
    mutating func updateOnBoot() {
        let now = Date()
        self.lastBootTime = now
        self.totalBootCount += 1
        
        // 時間経過による感情の自然変化
        self.emotion.naturalMoodDecay()
        
        // 古いクリック履歴を削除（30日以上前）
        let thirtyDaysAgo = Calendar.current.date(byAdding: .day, value: -30, to: now) ?? now
        self.clickHistory = self.clickHistory.filter { $0 > thirtyDaysAgo }
    }
    
    /// クリックイベント時に呼び出して状態を更新
    mutating func updateOnClick(at date: Date) {
        clickCount += 1
        
        // 連続クリック判定（2秒以内）
        if let lastTime = lastClickTime, date.timeIntervalSince(lastTime) < 2.0 {
            consecutiveClickCount += 1
        } else {
            consecutiveClickCount = 1
        }
        
        lastClickTime = date
        clickHistory.append(date)
    }
    
    /// ユーザーが通常よく利用する時間帯かどうかを判定
    func isUsualTimeForUser() -> Bool {
        guard clickHistory.count >= 10 else { return false } // 最低10回のクリック履歴が必要
        
        let now = Date()
        let currentHour = Calendar.current.component(.hour, from: now)
        
        // 過去のクリック履歴から同じ時間帯（±1時間）のクリックを集計
        let sameHourClicks = clickHistory.filter { clickDate in
            let clickHour = Calendar.current.component(.hour, from: clickDate)
            return abs(clickHour - currentHour) <= 1
        }
        
        // 全クリックの30%以上がこの時間帯なら「いつもの時間」と判定
        return Double(sameHourClicks.count) / Double(clickHistory.count) >= 0.3
    }
}

/// AIサービスの抽象インターフェース
protocol AIServiceProtocol {
    func generateResponse(prompt: String) async throws -> String
}
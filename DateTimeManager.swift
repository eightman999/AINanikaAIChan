//  © eightman 2005-2025
//  Furin-lab All Rights Reserved.
//  日時に基づいた判定を行うマネージャークラス

import Foundation

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

/// 日時に関する判定を行うマネージャークラス
class DateTimeManager {
    
    /// 現在の時間帯を取得
    static func getCurrentTimeOfDay() -> TimeOfDay {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<10:  return .morning     // 5時〜9時台：朝
        case 10..<17: return .afternoon   // 10時〜16時台：昼
        case 17..<20: return .evening     // 17時〜19時台：夕方
        case 20..<24: return .night       // 20時〜23時台：夜
        default:      return .lateNight   // 0時〜4時台：深夜
        }
    }
    
    /// 現在の季節またはイベントを取得
    static func getCurrentSeason() -> Season {
        let month = Calendar.current.component(.month, from: Date())
        let day = Calendar.current.component(.day, from: Date())
        
        // 特別イベントを優先的に判定
        if month == 12 && day >= 20 && day <= 25 { return .christmas }
        if month == 1 && day >= 1 && day <= 7 { return .newYear }
        if month == 2 && day == 14 { return .valentines }
        if month == 3 && day == 14 { return .whiteDays }
        if month == 10 && day == 31 { return .halloween }
        
        // 通常の季節判定
        switch month {
        case 3...5: return .spring   // 3月〜5月：春
        case 6...8: return .summer   // 6月〜8月：夏
        case 9...11: return .autumn  // 9月〜11月：秋
        default: return .winter      // 12月〜2月：冬
        }
    }
    
    /// 時間帯に応じた挨拶を取得
    static func getGreetingForTimeOfDay() -> String {
        switch getCurrentTimeOfDay() {
        case .morning:
            return "おはよう"
        case .afternoon:
            return "こんにちは"
        case .evening:
            return "こんばんは"
        case .night:
            return "お疲れさま"
        case .lateNight:
            return "夜更かしですね"
        }
    }
    
    /// 季節・イベントに応じた特別メッセージを取得
    static func getSeasonalMessage() -> String? {
        switch getCurrentSeason() {
        case .christmas:
            return "メリークリスマス🎄"
        case .newYear:
            return "あけましておめでとうございます🎍"
        case .valentines:
            return "今日はバレンタインデーですね💝"
        case .whiteDays:
            return "ホワイトデーですね🤍"
        case .halloween:
            return "ハッピーハロウィン🎃"
        case .spring:
            return "桜の季節ですね🌸"
        case .summer:
            return "暑い日が続きますね☀️"
        case .autumn:
            return "紅葉が美しい季節ですね🍁"
        case .winter:
            return "寒い日が続きますね❄️"
        }
    }
    
    /// 時間帯に応じたアドバイスを取得
    static func getTimeAdvice() -> String? {
        let timeOfDay = getCurrentTimeOfDay()
        let hour = Calendar.current.component(.hour, from: Date())
        
        switch timeOfDay {
        case .morning:
            if hour < 6 {
                return "早起きですね！"
            }
            return "朝の時間を大切にしてくださいね。"
            
        case .afternoon:
            return "午後も頑張りましょう。"
            
        case .evening:
            return "一日お疲れさまでした。"
            
        case .night:
            if hour >= 23 {
                return "そろそろ休む時間ですね。"
            }
            return "夜の時間をゆっくり過ごしてください。"
            
        case .lateNight:
            return "夜更かしは体に良くないですよ。早めに寝てくださいね。"
        }
    }
    
    /// 最後のアクセスからの経過時間を計算
    static func getTimeSinceLastAccess(_ lastTime: Date) -> String {
        let timeInterval = Date().timeIntervalSince(lastTime)
        let days = Int(timeInterval / (24 * 60 * 60))
        let hours = Int((timeInterval.truncatingRemainder(dividingBy: 24 * 60 * 60)) / (60 * 60))
        let minutes = Int((timeInterval.truncatingRemainder(dividingBy: 60 * 60)) / 60)
        
        if days > 0 {
            return "\(days)日ぶりですね"
        } else if hours > 0 {
            return "\(hours)時間ぶりですね"
        } else if minutes > 10 {
            return "\(minutes)分ぶりですね"
        } else {
            return "お帰りなさい"
        }
    }
    
    /// 今日が特別な日（土日、祝日など）かを判定
    static func isSpecialDay() -> Bool {
        let weekday = Calendar.current.component(.weekday, from: Date())
        return weekday == 1 || weekday == 7 // 日曜日(1) または 土曜日(7)
    }
    
    /// 週末の判定に応じたメッセージ
    static func getWeekendMessage() -> String? {
        if isSpecialDay() {
            return "今日は休日ですね。ゆっくり過ごしてください。"
        } else {
            let weekday = Calendar.current.component(.weekday, from: Date())
            switch weekday {
            case 2: return "月曜日、新しい週の始まりですね。" // 月曜日
            case 6: return "金曜日、一週間お疲れさまでした。" // 金曜日
            default: return nil
            }
        }
    }
}
//  © eightman 2005-2025
//  Furin-lab All Rights Reserved.
//  日時に基づいた判定を行うマネージャ(旧DateTimeManager.swiftから移植)

import Foundation

enum DateTimeManager {
    /// 現在の時間帯を取得
    static func currentTimeOfDay(now: Date = Date()) -> TimeOfDay {
        let hour = Calendar.current.component(.hour, from: now)
        switch hour {
        case 5..<10:  return .morning
        case 10..<17: return .afternoon
        case 17..<20: return .evening
        case 20..<24: return .night
        default:      return .lateNight
        }
    }

    /// 現在の季節またはイベントを取得
    static func currentSeason(now: Date = Date()) -> Season {
        let month = Calendar.current.component(.month, from: now)
        let day = Calendar.current.component(.day, from: now)

        if month == 12 && (20...25).contains(day) { return .christmas }
        if month == 1 && (1...7).contains(day) { return .newYear }
        if month == 2 && day == 14 { return .valentines }
        if month == 3 && day == 14 { return .whiteDays }
        if month == 10 && day == 31 { return .halloween }

        switch month {
        case 3...5: return .spring
        case 6...8: return .summer
        case 9...11: return .autumn
        default: return .winter
        }
    }

    /// 時間帯に応じた挨拶
    static func greetingForTimeOfDay(_ time: TimeOfDay? = nil) -> String {
        switch time ?? currentTimeOfDay() {
        case .morning:   return "おはよう"
        case .afternoon: return "こんにちは"
        case .evening:   return "こんばんは"
        case .night:     return "お疲れさま"
        case .lateNight: return "夜更かしですね"
        }
    }

    /// 季節・イベントに応じた特別メッセージ
    static func seasonalMessage(for season: Season? = nil) -> String? {
        switch season ?? currentSeason() {
        case .christmas: return "メリークリスマス🎄"
        case .newYear:   return "あけましておめでとうございます🎍"
        case .valentines: return "今日はバレンタインデーですね💝"
        case .whiteDays: return "ホワイトデーですね🤍"
        case .halloween: return "ハッピーハロウィン🎃"
        case .spring:    return "桜の季節ですね🌸"
        case .summer:    return "暑い日が続きますね☀️"
        case .autumn:    return "紅葉が美しい季節ですね🍁"
        case .winter:    return "寒い日が続きますね❄️"
        }
    }

    /// 最後のアクセスからの経過時間のあいさつ
    static func timeSinceLastAccess(_ lastTime: Date, now: Date = Date()) -> String {
        let interval = now.timeIntervalSince(lastTime)
        let days = Int(interval / 86400)
        let hours = Int(interval.truncatingRemainder(dividingBy: 86400) / 3600)
        let minutes = Int(interval.truncatingRemainder(dividingBy: 3600) / 60)

        if days > 0 { return "\(days)日ぶりですね" }
        if hours > 0 { return "\(hours)時間ぶりですね" }
        if minutes > 10 { return "\(minutes)分ぶりですね" }
        return "お帰りなさい"
    }
}

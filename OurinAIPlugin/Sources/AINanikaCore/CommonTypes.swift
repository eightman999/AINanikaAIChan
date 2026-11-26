//  © eightman 2005-2025
//  Furin-lab All Rights Reserved.
//  プロジェクト共通の型定義(旧ルートCommonTypes.swiftから移植)

import Foundation

/// キャラクターの感情状態
struct EmotionState: Codable, Equatable {
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
enum TimeOfDay: String, CaseIterable, Codable {
    case morning = "朝"
    case afternoon = "昼"
    case evening = "夕方"
    case night = "夜"
    case lateNight = "深夜"
}

/// 季節とイベントの分類
enum Season: String, CaseIterable, Codable {
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
enum ClickRegion: Equatable {
    case head
    case body
    case other

    /// 座標から部位を判定する。
    /// サーフェス0番(本体立ち絵)を想定したヒューリスティック判定。
    static func from(x: Int, y: Int, surfaceId: Int) -> ClickRegion {
        if surfaceId == 0 {
            if (50..<200).contains(x) && (50..<150).contains(y) {
                return .head
            } else if (50..<200).contains(x) && (150..<400).contains(y) {
                return .body
            }
        }
        return .other
    }
}

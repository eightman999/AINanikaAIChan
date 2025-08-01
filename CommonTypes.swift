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


/// AIサービスの抽象インターフェース
protocol AIServiceProtocol {
    func generateResponse(prompt: String) async throws -> String
}
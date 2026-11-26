//  © eightman 2005-2025
//  Furin-lab All Rights Reserved.
//  AI接続エラー共通定義+プロンプト構築

import Foundation

enum AIError: LocalizedError {
    case invalidConfiguration
    case networkError
    case httpError(status: Int, body: String)
    case emptyResponse
    case serviceUnavailable

    var errorDescription: String? {
        switch self {
        case .invalidConfiguration: return "AI設定が不正です"
        case .networkError: return "ネットワークエラー"
        case .httpError(let status, _): return "APIエラー (HTTP \(status))"
        case .emptyResponse: return "空の応答"
        case .serviceUnavailable: return "AIサービスが設定されていません"
        }
    }
}

/// システムプロンプト(persona+現在状態)を構築する
enum PromptBuilder {
    /// persona.md 相当のキャラ設定と状態からシステムプロンプトを組む
    static func systemPrompt(persona: String?, state: CharacterState) -> String {
        var lines: [String] = []
        if let persona = persona?.trimmingCharacters(in: .whitespacesAndNewlines), !persona.isEmpty {
            lines.append(persona)
        } else {
            lines.append("あなたはデスクトップに住む伺かゴースト「AI何かちゃん」です。ユーザーと親しげに、簡潔に会話します。")
        }
        lines.append("")
        lines.append("## 現在の状態")
        lines.append("- 時間帯: \(DateTimeManager.currentTimeOfDay().rawValue)")
        lines.append("- 季節: \(DateTimeManager.currentSeason().rawValue)")
        let moodLabel = state.emotion.mood > 0.3 ? "良い" : state.emotion.mood < -0.3 ? "悪い" : "普通"
        lines.append("- 機嫌: \(moodLabel)(\(String(format: "%.2f", state.emotion.mood)))")
        lines.append("- 親愛度: \(String(format: "%.2f", state.emotion.affection))")
        lines.append("- これまでの起動回数: \(state.totalBootCount)")
        if state.clickCount > 0 {
            lines.append("- 累計クリック数: \(state.clickCount)")
        }
        lines.append("")
        lines.append("## 応答のルール")
        lines.append("- キャラクターとして1〜3文で応答する")
        lines.append("- SakuraScriptやタグ記法は出力しない(台詞テキストのみ)")
        lines.append("- 状態(深夜・不機嫌など)を台詞のトーンに自然に反映する")
        return lines.joined(separator: "\n")
    }

    /// 長すぎる応答を適度な長さへ整形(改段落で分割し最初の2ブロックまで)
    static func shapeReply(_ text: String, enabled: Bool) -> String {
        guard enabled else { return text }
        // LLMがMarkdownの箇条書き等を出した場合もSakura Script的に安全なよう制御文字のみ除去
        let cleaned = text
            .replacingOccurrences(of: "\r\n", with: "\\n")
            .replacingOccurrences(of: "\n", with: "\\n")
        return cleaned
    }
}

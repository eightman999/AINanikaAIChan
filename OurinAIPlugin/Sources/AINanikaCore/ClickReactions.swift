//  © eightman 2005-2025
//  Furin-lab All Rights Reserved.
//  クリック反応(ローカル・LLM不使用)

import Foundation

enum ClickReactions {
    /// 感情状態と部位に応じた即時反応台詞(SakuraScript)
    static func response(region: ClickRegion, mood: Double) -> String {
        switch mood {
        case ..<(-0.3):
            return grumpy(region: region)
        case 0.3...:
            return happy(region: region)
        default:
            return neutral(region: region)
        }
    }

    private static func happy(region: ClickRegion) -> String {
        let script: String
        switch region {
        case .head:
            let responses = ["えへへ〜、なでてくれてありがとう〜！\\s[10]", "とっても気持ちいいよ〜！\\s[11]", "もっともっと〜！\\s[10]"]
            script = responses.randomElement()!
        case .body:
            let responses = ["きゃー！くすぐったいよ〜！\\s[12]", "えへへ、そんなところ撫でちゃだめ〜！\\s[13]"]
            script = responses.randomElement()!
        case .other:
            script = "今日もいい天気だね！"
        }
        return SakuraScriptBuilder.simple(script)
    }

    private static func neutral(region: ClickRegion) -> String {
        let script: String
        switch region {
        case .head:
            let responses = ["なでなで、ありがとう。\\s[0]", "そこを撫でられると嬉しいな。", "もっと撫でてほしいな。"]
            script = responses.randomElement()!
        case .body:
            let responses = ["何か用事かな？", "そこはちょっとくすぐったいかも。\\s[5]"]
            script = responses.randomElement()!
        case .other:
            script = DateTimeManager.greetingForTimeOfDay()
        }
        return SakuraScriptBuilder.simple(script)
    }

    private static func grumpy(region: ClickRegion) -> String {
        let script: String
        switch region {
        case .head:
            let responses = ["んっ、今はあんまり気分じゃないかも…\\s[6]", "ちょっと疑わしい気分。\\s[7]"]
            script = responses.randomElement()!
        case .body:
            script = "やめてよ、今はあんまり触らないで。\\s[8]"
        case .other:
            script = "ふん、今はあんまりお話ししたくない気分。\\s[9]"
        }
        return SakuraScriptBuilder.simple(script)
    }
}

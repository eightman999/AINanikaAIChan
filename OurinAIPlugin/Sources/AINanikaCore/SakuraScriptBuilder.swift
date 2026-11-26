//  © eightman 2005-2025
//  Furin-lab All Rights Reserved.
//  SakuraScript 生成ユーティリティ(旧SwiftSHIORI.swiftから移植)

import Foundation

enum SakuraScriptBuilder {
    /// 標準の一人称スコープ+サーフェス0で喋る
    static func simple(_ text: String) -> String {
        "\\h\\s[0]\(text)\\e"
    }

    /// サーフェスを指定して喋る
    static func withSurface(_ text: String, surface: Int) -> String {
        "\\h\\s[\(surface)]\(text)\\e"
    }

    /// アニメーションを伴う会話
    static func animatedTalk(_ text: String, startSurface: Int, endSurface: Int) -> String {
        "\\s[\(startSurface)]\\h\(text)\\s[\(endSurface)]\\e"
    }

    /// 選択肢を提示する
    static func choice(_ text: String, options: [String]) -> String {
        let choiceScripts = options.map { "\\q[\($0),OnTalk,\"\($0)\"]" }.joined(separator: " ")
        return "\\h\(text) \(choiceScripts)\\e"
    }
}

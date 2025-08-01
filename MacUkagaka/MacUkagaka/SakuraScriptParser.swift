//  © eightman 2005-2025
//  Furin-lab All Rights Reserved.
//  SakuraScriptを解析して実行可能なアクションに変換する。

import Foundation

/// SakuraScriptの字句解析で得られるトークン。
public struct SakuraScriptToken {
    /// SakuraScriptに現れるトークン種別。
    public enum TokenType {
        case text(String)
        case scopeSwitch(Int)
        case surfaceChange(Int)
        case lineBreak
        case wait(Int)
        case choice(String, String)
        case anchor(Int)
        case scriptEnd
    }
    
    public let type: TokenType
}

/// 解析されたトークンから生成され、UIで実行されるアクション。
public struct SakuraScriptAction {
    /// 実行可能なアクションの種類。
    public enum ActionType {
        case displayText(String, scope: Int)
        case changeSurface(Int, scope: Int)
        case wait(Int)
        case showChoices([(String, String)])
        case end
    }
    
    public let type: ActionType
}

public class SakuraScriptParser {
    /// 現在のスコープ(0は\h、1は\u)。
    private var currentScope: Int = 0
    
    /// SakuraScriptParserを初期化
    public init() {}
    
    /// SakuraScript文字列を実行可能なアクションに変換する。
    public func parse(_ script: String) -> [SakuraScriptAction] {
        let tokens = tokenize(script)
        return generateActions(from: tokens)
    }
    
    /// スクリプトをトークン列に分割する。
    private func tokenize(_ script: String) -> [SakuraScriptToken] {
        var tokens: [SakuraScriptToken] = []
        var index = script.startIndex
        
        while index < script.endIndex {
            if script[index] == "\\" {
                let (token, nextIndex) = parseControlCode(script, from: index)
                if let token = token {
                    tokens.append(token)
                }
                index = nextIndex
            } else {
                let (text, nextIndex) = parseText(script, from: index)
                if !text.isEmpty {
                    tokens.append(SakuraScriptToken(type: .text(text)))
                }
                index = nextIndex
            }
        }
        
        return tokens
    }
    
    /// 「\\」から始まる制御コードを解析する。
    private func parseControlCode(_ script: String, from index: String.Index) -> (SakuraScriptToken?, String.Index) {
        guard index < script.endIndex else {
            return (nil, index)
        }
        
        let nextIndex = script.index(after: index)
        guard nextIndex < script.endIndex else {
            return (nil, script.endIndex)
        }
        
        let controlChar = script[nextIndex]
        
        switch controlChar {
        case "h":
            return (SakuraScriptToken(type: .scopeSwitch(0)), script.index(after: nextIndex))
        case "u":
            return (SakuraScriptToken(type: .scopeSwitch(1)), script.index(after: nextIndex))
        case "s":
            let (surfaceId, endIndex) = parseNumericParameter(script, from: nextIndex)
            return (SakuraScriptToken(type: .surfaceChange(surfaceId)), endIndex)
        case "n":
            return (SakuraScriptToken(type: .lineBreak), script.index(after: nextIndex))
        case "_":
            if nextIndex < script.endIndex && script.index(after: nextIndex) < script.endIndex {
                let afterUnderscore = script.index(after: nextIndex)
                if script[afterUnderscore] == "w" {
                    let (waitTime, endIndex) = parseNumericParameter(script, from: afterUnderscore)
                    return (SakuraScriptToken(type: .wait(waitTime)), endIndex)
                }
            }
            return (nil, script.index(after: nextIndex))
        case "q":
            let (choice, endIndex) = parseChoiceParameter(script, from: nextIndex)
            return (SakuraScriptToken(type: .choice(choice.0, choice.1)), endIndex)
        case "i":
            let (anchorId, endIndex) = parseNumericParameter(script, from: nextIndex)
            return (SakuraScriptToken(type: .anchor(anchorId)), endIndex)
        case "e":
            return (SakuraScriptToken(type: .scriptEnd), script.index(after: nextIndex))
        default:
            return (nil, script.index(after: nextIndex))
        }
    }
    
    /// 次の制御コードまでのテキストを取得する。
    private func parseText(_ script: String, from index: String.Index) -> (String, String.Index) {
        var text = ""
        var currentIndex = index
        
        while currentIndex < script.endIndex {
            let char = script[currentIndex]
            if char == "\\" {
                break
            }
            text.append(char)
            currentIndex = script.index(after: currentIndex)
        }
        
        return (text, currentIndex)
    }
    
    /// 「[123]」のような数値を解析する。
    private func parseNumericParameter(_ script: String, from index: String.Index) -> (Int, String.Index) {
        var currentIndex = script.index(after: index)
        
        guard currentIndex < script.endIndex && script[currentIndex] == "[" else {
            return (0, currentIndex)
        }
        
        currentIndex = script.index(after: currentIndex)
        var numberString = ""
        
        while currentIndex < script.endIndex && script[currentIndex] != "]" {
            numberString.append(script[currentIndex])
            currentIndex = script.index(after: currentIndex)
        }
        
        if currentIndex < script.endIndex {
            currentIndex = script.index(after: currentIndex)
        }
        
        return (Int(numberString) ?? 0, currentIndex)
    }
    
    /// 「[Text,id]」形式の選択肢パラメータを解析する。
    private func parseChoiceParameter(_ script: String, from index: String.Index) -> ((String, String), String.Index) {
        var currentIndex = script.index(after: index)
        
        guard currentIndex < script.endIndex && script[currentIndex] == "[" else {
            return (("", ""), currentIndex)
        }
        
        currentIndex = script.index(after: currentIndex)
        var parameterString = ""
        
        while currentIndex < script.endIndex && script[currentIndex] != "]" {
            parameterString.append(script[currentIndex])
            currentIndex = script.index(after: currentIndex)
        }
        
        if currentIndex < script.endIndex {
            currentIndex = script.index(after: currentIndex)
        }
        
        let parts = parameterString.components(separatedBy: ",")
        let text = parts.first ?? ""
        let id = parts.count > 1 ? parts[1] : ""
        
        return ((text, id), currentIndex)
    }
    
    /// トークン列からアクションシーケンスを生成する。
    private func generateActions(from tokens: [SakuraScriptToken]) -> [SakuraScriptAction] {
        var actions: [SakuraScriptAction] = []
        var currentText = ""
        var currentScope = 0
        var pendingChoices: [(String, String)] = []
        
        for token in tokens {
            switch token.type {
            case .text(let text):
                currentText += text
            case .scopeSwitch(let scope):
                if !currentText.isEmpty {
                    actions.append(SakuraScriptAction(type: .displayText(currentText, scope: currentScope)))
                    currentText = ""
                }
                currentScope = scope
            case .surfaceChange(let surface):
                if !currentText.isEmpty {
                    actions.append(SakuraScriptAction(type: .displayText(currentText, scope: currentScope)))
                    currentText = ""
                }
                actions.append(SakuraScriptAction(type: .changeSurface(surface, scope: currentScope)))
            case .lineBreak:
                currentText += "\n"
            case .wait(let time):
                if !currentText.isEmpty {
                    actions.append(SakuraScriptAction(type: .displayText(currentText, scope: currentScope)))
                    currentText = ""
                }
                actions.append(SakuraScriptAction(type: .wait(time)))
            case .choice(let text, let id):
                pendingChoices.append((text, id))
            case .anchor(_):
                break
            case .scriptEnd:
                if !currentText.isEmpty {
                    actions.append(SakuraScriptAction(type: .displayText(currentText, scope: currentScope)))
                }
                if !pendingChoices.isEmpty {
                    actions.append(SakuraScriptAction(type: .showChoices(pendingChoices)))
                    pendingChoices.removeAll()
                }
                actions.append(SakuraScriptAction(type: .end))
            }
        }
        
        if !currentText.isEmpty {
            actions.append(SakuraScriptAction(type: .displayText(currentText, scope: currentScope)))
        }
        
        if !pendingChoices.isEmpty {
            actions.append(SakuraScriptAction(type: .showChoices(pendingChoices)))
        }
        
        return actions
    }
}
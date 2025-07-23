//  © eightman 2005-2025
//  Furin-lab All Rights Reserved.
//  ゴーストのリソースを読み込み、SHIORIエンジンと通信するクラス。

import Foundation

// MARK: - Swift SHIORI Implementation
// Temporary inline implementation - should be moved to separate file when Xcode project is properly configured

/// SHIORI プロトコルのリクエスト構造
struct SHIORIRequest {
    let version: String
    let method: String
    let id: String
    let references: [String: String]
    let securityLevel: String

    static func parse(_ requestText: String) -> SHIORIRequest? {
        print("[SHIORIRequest] Parsing request: \"\(requestText.prefix(200))\"")
        
        let lines = requestText.components(separatedBy: .newlines)
        guard !lines.isEmpty else { 
            print("[SHIORIRequest] ERROR: Empty request")
            return nil 
        }
        
        let firstLine = lines[0].trimmingCharacters(in: .whitespaces)
        print("[SHIORIRequest] First line: \"\(firstLine)\"")
        
        let parts = firstLine.components(separatedBy: " ")
        print("[SHIORIRequest] First line parts: \(parts)")
        
        // SHIORI request format: "GET SHIORI/3.0" or "NOTIFY SHIORI/3.0"
        guard parts.count >= 2 else { 
            print("[SHIORIRequest] ERROR: Invalid first line format")
            return nil 
        }
        
        let method = parts[0]
        let version = parts[1] // This should be "SHIORI/3.0"
        
        var id = ""
        var references: [String: String] = [:]
        var securityLevel = "external"
        var remoteGroup = ""
        
        for (index, line) in lines.dropFirst().enumerated() {
            let trimmedLine = line.trimmingCharacters(in: .whitespaces)
            if trimmedLine.isEmpty { 
                print("[SHIORIRequest] Found empty line at index \(index + 1), stopping header parsing")
                break 
            }
            
            print("[SHIORIRequest] Processing header line: \"\(trimmedLine)\"")
            
            let colonRange = trimmedLine.range(of: ": ")
            guard let range = colonRange else { 
                print("[SHIORIRequest] WARNING: No colon found in line: \"\(trimmedLine)\"")
                continue 
            }
            
            let key = String(trimmedLine[..<range.lowerBound])
            let value = String(trimmedLine[range.upperBound...])
            
            print("[SHIORIRequest] Parsed header - Key: \"\(key)\", Value: \"\(value)\"")
            
            if key == "ID" {
                id = value
            } else if key.hasPrefix("Reference") {
                references[key] = value
            } else if key == "SecurityLevel" {
                securityLevel = value
            } else if key == "App-Group-ID" {
                remoteGroup = value
            }
        }
        
        let evaluated = Self.evaluateSecurityLevel(requested: securityLevel, remoteGroup: remoteGroup)
        print("[SHIORIRequest] Successfully parsed - Method: \"\(method)\", Version: \"\(version)\", ID: \"\(id)\", References: \(references.count), SecurityLevel: \"\(evaluated)\"")
        return SHIORIRequest(version: version, method: method, id: id, references: references, securityLevel: evaluated)
    }

    /// Returns the effective security level based on the remote App Group.
    private static func evaluateSecurityLevel(requested: String, remoteGroup: String) -> String {
        return remoteGroup == SharedFMO.groupID ? requested : "external"
    }
    
    func getReference(_ index: Int) -> String? {
        return references["Reference\(index)"]
    }
}

/// SHIORI プロトコルのレスポンス構造
struct SHIORIResponse {
    let statusCode: Int
    let statusText: String
    let value: String
    
    init(value: String, statusCode: Int = 200, statusText: String = "OK") {
        self.value = value
        self.statusCode = statusCode
        self.statusText = statusText
    }
    
    func toString() -> String {
        return """
        SHIORI/3.0 \(statusCode) \(statusText)\r
        Content-Type: text/plain\r
        Value: \(value)\r
        \r

        """
    }
}

/// SakuraScript 生成ユーティリティ
struct SakuraScriptBuilder {
    static func simple(_ text: String) -> String {
        return "\\h\\s[0]\(text)\\e"
    }
    
    static func withSurface(_ text: String, surface: Int) -> String {
        return "\\h\\s[\(surface)]\(text)\\e"
    }
}



// MARK: - GhostManager Implementation

protocol GhostManagerDelegate: AnyObject {
    func ghostManager(_ manager: GhostManager, didReceiveScript script: String)
    func ghostManager(_ manager: GhostManager, didEncounterError error: Error)
}

class GhostManager {
    /// スクリプトとエラー通知用のデリゲート。
    weak var delegate: GhostManagerDelegate?

    /// ゴーストリソースのルートパス。
    private let ghostPath: String

    /// `descript.txt`から解析した情報。
    private var ghostInfo: GhostInfo?

    /// SHIORIエンジンとの通信に使用するクライアント。
    private var shioriClient: SHIORIClient?
    
    /// 純粋Swift実装のSHIORIエンジン（代替オプション）。
    private var swiftSHIORI: SwiftSHIORI?
    
    /// Swift SHIORI を使用するかどうかのフラグ。
    private let useSwiftSHIORI: Bool

    /// `OnSecondChange`イベント用のタイマー。
    private var randomTalkTimer: Timer?
    
    /// `descript.txt`から取得した情報。
    struct GhostInfo {
        /// ゴーストの表示名。
        let name: String
        /// メインキャラの名前（通常はさくら）。
        let sakuraName: String
        /// サブキャラの名前（通常はうにゅう）。
        let keroName: String
        /// SHIORI実行ファイルのパス。
        let shioriPath: String
        /// ゴーストが使用する文字コード。
        let charset: String
    }
    
    /// ゴーストの読み込み・実行で発生する可能性のあるエラー。
    enum GhostError: Error {
        /// `descript.txt` が見つからない。
        case descriptNotFound
        /// SHIORI 実行ファイルが見つからない。
        case shioriNotFound
        /// `descript.txt` に指定された文字コードが不正。
        case invalidCharset
        /// 必要な構成要素が不足して初期化に失敗。
        case initializationFailed
        /// バンドル内のリソースが見つからない。
        case bundleResourceNotFound
    }
    
    // デフォルトイニシャライザ - AINanikaAIChanを読み込む
    init(useSwiftSHIORI: Bool = false) throws {
        self.useSwiftSHIORI = useSwiftSHIORI
        self.ghostPath = try Self.getDefaultGhostPath()
        self.ghostInfo = try loadGhostInfo()
        
        if useSwiftSHIORI {
            // Use the comprehensive SwiftSHIORI from SwiftSHIORI.swift
            self.swiftSHIORI = SwiftSHIORI()
            self.shioriClient = nil
        } else {
            self.shioriClient = SHIORIClient(ghostPath: ghostPath, shioriPath: ghostInfo!.shioriPath)
            self.swiftSHIORI = nil
        }
    }
    
    // UkagakaDirectoryManagerを使用するイニシャライザ
    init(directoryManager: UkagakaDirectoryManager, useSwiftSHIORI: Bool = false) throws {
        self.useSwiftSHIORI = useSwiftSHIORI
        
        // ドキュメントディレクトリからゴーストパスを取得（フォールバック付き）
        guard let availableGhostName = directoryManager.getAvailableGhostName() else {
            throw GhostError.bundleResourceNotFound
        }
        
        self.ghostPath = directoryManager.getGhostDirectoryURL(ghostName: availableGhostName).path
        self.ghostInfo = try loadGhostInfo()
        
        if useSwiftSHIORI {
            // Use the comprehensive SwiftSHIORI from SwiftSHIORI.swift
            self.swiftSHIORI = SwiftSHIORI()
            self.shioriClient = nil
        } else {
            self.shioriClient = SHIORIClient(ghostPath: ghostPath, shioriPath: ghostInfo!.shioriPath)
            self.swiftSHIORI = nil
        }
    }
    
    // 既存のイニシャライザ（後方互換性のため）
    init(ghostPath: String, useSwiftSHIORI: Bool = false) throws {
        self.useSwiftSHIORI = useSwiftSHIORI
        self.ghostPath = ghostPath
        self.ghostInfo = try loadGhostInfo()
        
        if useSwiftSHIORI {
            // Use the comprehensive SwiftSHIORI from SwiftSHIORI.swift
            self.swiftSHIORI = SwiftSHIORI()
            self.shioriClient = nil
        } else {
            self.shioriClient = SHIORIClient(ghostPath: ghostPath, shioriPath: ghostInfo!.shioriPath)
            self.swiftSHIORI = nil
        }
    }
    
    /// Returns the default path to the bundled ghost resources.
    private static func getDefaultGhostPath() throws -> String {
        // 配布時: アプリケーションバンドル内のリソース（カスタムビルドスクリプトによりコピーされたリソース）
        guard let bundleResourceURL = Bundle.main.resourceURL else {
            throw GhostError.bundleResourceNotFound
        }
        
        let ghostPath = bundleResourceURL.appendingPathComponent("ghost").path
        if FileManager.default.fileExists(atPath: ghostPath) {
            return ghostPath
        }
        
        // 開発時: プロジェクトルートからの相対パス（フォールバック）
        let currentPath = FileManager.default.currentDirectoryPath
        let developmentGhostPath = "\(currentPath)/AINanikaAIChan/ghost"
        if FileManager.default.fileExists(atPath: developmentGhostPath) {
            return developmentGhostPath
        }
        
        throw GhostError.bundleResourceNotFound
    }
    
    /// SHIORI を起動し `OnBoot` を送信。
    func start() throws {
        print("Attempting to send OnBoot request to SHIORI...")
        
        if useSwiftSHIORI {
            // Swift SHIORI を使用
            print("Using Swift SHIORI implementation")
            Task {
                do {
                    let requestText = """
                    GET SHIORI/3.0\r
                    ID: OnBoot\r
                    Reference0: MacUkagaka\r
                    Reference1: 1.0.0\r
                    Reference2: macOS\r
                    \r

                    """
                    let responseText = await self.swiftSHIORI!.processRequest(requestText)
                    let bootScript = self.parseResponseValue(responseText)
                    
                    print("OnBoot request completed. Script length: \(bootScript.count)")
                    print("Boot script content: '\(bootScript)'")
                    
                    DispatchQueue.main.async {
                        if !bootScript.isEmpty {
                            print("Sending boot script to delegate")
                            self.delegate?.ghostManager(self, didReceiveScript: bootScript)
                        } else {
                            print("Boot script is empty")
                        }
                        
                        print("Starting random talk timer")
                        self.startRandomTalk()
                        print("GhostManager started successfully")
                    }
                } catch {
                    print("Error with Swift SHIORI: \(error)")
                    DispatchQueue.main.async {
                        self.delegate?.ghostManager(self, didEncounterError: error)
                    }
                }
            }
        } else {
            // C# SHIORI クライアントを使用
            guard let shiori = shioriClient else {
                throw GhostError.initializationFailed
            }
            
            print("Using C# SHIORI client")
            do {
                try shiori.start()
                
                let bootScript = try shiori.request(event: "OnBoot", references: [
                    "MacUkagaka",
                    "1.0.0",
                    "macOS"
                ])
                
                print("OnBoot request completed. Script length: \(bootScript.count)")
                print("Boot script content: '\(bootScript)'")
                
                if !bootScript.isEmpty {
                    print("Sending boot script to delegate")
                    delegate?.ghostManager(self, didReceiveScript: bootScript)
                } else {
                    print("Boot script is empty")
                }
                
                print("Starting random talk timer")
                startRandomTalk()
                print("GhostManager started successfully")
            } catch {
                print("Error sending OnBoot request to SHIORI: \(error)")
                delegate?.ghostManager(self, didEncounterError: error)
                throw error
            }
        }
    }
    
    /// `OnClose` を送信して SHIORI を終了。
    func shutdown() {
        randomTalkTimer?.invalidate()
        randomTalkTimer = nil
        
        if let shiori = shioriClient {
            do {
                _ = try shiori.request(event: "OnClose", references: [])
            } catch {
                print("Shutdown request failed: \(error)")
            }
            shiori.stop()
        }
    }
    
    /// マウスクリックを SHIORI に通知。
    func handleMouseClick(surfaceId: Int, x: Int, y: Int, button: Int) {
        if useSwiftSHIORI {
            // Swift SHIORI を使用
            Task {
                do {
                    let requestText = """
                    GET SHIORI/3.0\r
                    ID: OnMouseClick\r
                    Reference0: \(surfaceId)\r
                    Reference1: \(x)\r
                    Reference2: \(y)\r
                    Reference3: \(button)\r
                    \r

                    """
                    let responseText = await self.swiftSHIORI!.processRequest(requestText)
                    let script = self.parseResponseValue(responseText)
                    
                    DispatchQueue.main.async {
                        if !script.isEmpty {
                            self.delegate?.ghostManager(self, didReceiveScript: script)
                        }
                    }
                } catch {
                    DispatchQueue.main.async {
                        self.delegate?.ghostManager(self, didEncounterError: error)
                    }
                }
            }
        } else {
            // C# SHIORI クライアントを使用
            guard let shiori = shioriClient else { return }
            
            do {
                let script = try shiori.request(event: "OnMouseClick", references: [
                    String(surfaceId),
                    String(x),
                    String(y),
                    String(button)
                ])
                
                if !script.isEmpty {
                    delegate?.ghostManager(self, didReceiveScript: script)
                }
            } catch {
                delegate?.ghostManager(self, didEncounterError: error)
            }
        }
    }
    
    /// `OnSecondChange` をポーリング。
    func handleSecondChange() {
        if useSwiftSHIORI {
            // Swift SHIORI を使用
            Task {
                do {
                    let requestText = """
                    GET SHIORI/3.0\r
                    ID: OnSecondChange\r
                    \r

                    """
                    let responseText = await self.swiftSHIORI!.processRequest(requestText)
                    let script = self.parseResponseValue(responseText)
                    
                    DispatchQueue.main.async {
                        if !script.isEmpty {
                            self.delegate?.ghostManager(self, didReceiveScript: script)
                        }
                    }
                } catch {
                    // OnSecondChange のエラーは無視（ログのみ）
                    print("OnSecondChange error: \(error)")
                }
            }
        } else {
            // C# SHIORI クライアントを使用
            guard let shiori = shioriClient else { return }
            
            do {
                let script = try shiori.request(event: "OnSecondChange", references: [])
                if !script.isEmpty {
                    delegate?.ghostManager(self, didReceiveScript: script)
                }
            } catch {
                delegate?.ghostManager(self, didEncounterError: error)
            }
        }
    }
    
    /// SHIORI レスポンスから Value 部分を抽出する。
    private func parseResponseValue(_ response: String) -> String {
        // \r\n と \n の両方に対応するため、まず\rを削除してから分割
        let normalizedResponse = response.replacingOccurrences(of: "\r", with: "")
        let lines = normalizedResponse.components(separatedBy: .newlines)
        var inValueSection = false
        var value = ""
        
        for line in lines {
            if line.hasPrefix("Value: ") {
                value = String(line.dropFirst(7))
                inValueSection = true
            } else if inValueSection && line.isEmpty {
                break
            } else if inValueSection {
                value += "\n" + line
            }
        }
        
        return value.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    /// `descript.txt` を読み込み、ゴースト情報を返す。
    private func loadGhostInfo() throws -> GhostInfo {
        let descriptPath = "\(ghostPath)/descript.txt"
        
        guard FileManager.default.fileExists(atPath: descriptPath) else {
            throw GhostError.descriptNotFound
        }
        
        let content = try String(contentsOfFile: descriptPath, encoding: .utf8)
        var name = "Unknown Ghost"
        var sakuraName = "さくら"
        var keroName = "うにゅう"
        var charset = "UTF-8"
        
        for line in content.components(separatedBy: .newlines) {
            let parts = line.components(separatedBy: ",")
            if parts.count >= 2 {
                let key = parts[0].trimmingCharacters(in: .whitespaces)
                let value = parts[1].trimmingCharacters(in: .whitespaces)
                
                switch key {
                case "name":
                    name = value
                case "sakura.name":
                    sakuraName = value
                case "kero.name":
                    keroName = value
                case "charset":
                    charset = value
                default:
                    break
                }
            }
        }
        
        // .NET SHIORIの実行ファイルパスを解決
        let resolvedSHIORIPath = try resolveSHIORIPath()
        
        return GhostInfo(
            name: name,
            sakuraName: sakuraName,
            keroName: keroName,
            shioriPath: resolvedSHIORIPath,
            charset: charset
        )
    }
    
    /// 同梱 .NET SHIORI の実行パスを解決。
    private func resolveSHIORIPath() throws -> String {
        // 配布時: アプリケーションバンドル内のSHIORIパス（カスタムビルドスクリプトによりコピーされたリソース）
        guard let bundleResourceURL = Bundle.main.resourceURL else {
            throw GhostError.shioriNotFound
        }
        
        let shioriPath = bundleResourceURL.appendingPathComponent("shiori/MacUkagaka.SHIORI").path
        if FileManager.default.fileExists(atPath: shioriPath) {
            return shioriPath
        }
        
        // 開発時: プロジェクトルートからの相対パス（フォールバック）
        let currentPath = FileManager.default.currentDirectoryPath
        let developmentSHIORIPath = "\(currentPath)/AINanikaAIChan/shiori/MacUkagaka.SHIORI"
        if FileManager.default.fileExists(atPath: developmentSHIORIPath) {
            return developmentSHIORIPath
        }
        
        throw GhostError.shioriNotFound
    }
    
    /// `handleSecondChange` を繰り返し呼び出すタイマーを開始。
    private func startRandomTalk() {
        randomTalkTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            self.handleSecondChange()
        }
    }
}

extension GhostManager {
    /// 読み込まれたゴーストの名前。
    var name: String {
        return ghostInfo?.name ?? "Unknown"
    }
    
    /// スコープ0(\h)で使用する名前。
    var sakuraName: String {
        return ghostInfo?.sakuraName ?? "さくら"
    }
    
    /// スコープ1(\u)で使用する名前。
    var keroName: String {
        return ghostInfo?.keroName ?? "うにゅう"
    }

    /// ゴーストのルートディレクトリパスを返す。
    var path: String {
        return ghostPath
    }
}
//  © eightman 2005-2025
//  Furin-lab All Rights Reserved.
//  Loads ghost resources and communicates with the SHIORI engine.

import Foundation

protocol GhostManagerDelegate: AnyObject {
    func ghostManager(_ manager: GhostManager, didReceiveScript script: String)
    func ghostManager(_ manager: GhostManager, didEncounterError error: Error)
}

class GhostManager {
    weak var delegate: GhostManagerDelegate?
    private let ghostPath: String
    private var ghostInfo: GhostInfo?
    private var shioriClient: SHIORIClient?
    private var randomTalkTimer: Timer?
    
    struct GhostInfo {
        let name: String
        let sakuraName: String
        let keroName: String
        let shioriPath: String
        let charset: String
    }
    
    enum GhostError: Error {
        case descriptNotFound
        case shioriNotFound
        case invalidCharset
        case initializationFailed
        case bundleResourceNotFound
    }
    
    // デフォルトイニシャライザ - AINanikaAIChanを読み込む
    init() throws {
        self.ghostPath = try Self.getDefaultGhostPath()
        self.ghostInfo = try loadGhostInfo()
        self.shioriClient = SHIORIClient(ghostPath: ghostPath, shioriPath: ghostInfo!.shioriPath)
    }
    
    // 既存のイニシャライザ（後方互換性のため）
    init(ghostPath: String) throws {
        self.ghostPath = ghostPath
        self.ghostInfo = try loadGhostInfo()
        self.shioriClient = SHIORIClient(ghostPath: ghostPath, shioriPath: ghostInfo!.shioriPath)
    }
    
    // デフォルトゴーストパスの取得
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
    
    func start() throws {
        guard let shiori = shioriClient else {
            throw GhostError.initializationFailed
        }
        
        try shiori.start()
        
        let bootScript = try shiori.request(event: "OnBoot", references: [
            "MacUkagaka",
            "1.0.0",
            "macOS"
        ])
        
        if !bootScript.isEmpty {
            delegate?.ghostManager(self, didReceiveScript: bootScript)
        }
        
        startRandomTalk()
    }
    
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
    
    func handleMouseClick(surfaceId: Int, x: Int, y: Int, button: Int) {
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
    
    func handleSecondChange() {
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
    
    // .NET SHIORIの実行ファイルパスを解決
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
    
    private func startRandomTalk() {
        randomTalkTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            self.handleSecondChange()
        }
    }
}

extension GhostManager {
    var name: String {
        return ghostInfo?.name ?? "Unknown"
    }
    
    var sakuraName: String {
        return ghostInfo?.sakuraName ?? "さくら"
    }
    
    var keroName: String {
        return ghostInfo?.keroName ?? "うにゅう"
    }
}
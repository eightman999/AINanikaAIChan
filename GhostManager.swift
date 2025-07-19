//  © eightman 2005-2025
//  Furin-lab All Rights Reserved.
//  ゴーストのリソースを読み込み、SHIORIエンジンと通信するクラス。

import Foundation

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
    
    /// `OnSecondChange` をポーリング。
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
}
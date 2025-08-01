//  © eightman 2005-2025
//  Furin-lab All Rights Reserved.
//  MacUkagakaライブラリの公開API定義

import Foundation
import Cocoa

// MARK: - Public API

/// MacUkagakaライブラリの主要なクラスを公開
public typealias MacUkagakaAppDelegate = AppDelegate
public typealias MacUkagakaCharacterWindowController = CharacterWindowController
public typealias MacUkagakaGhostManager = GhostManager
public typealias MacUkagakaSHIORIClient = SHIORIClient
public typealias MacUkagakaSakuraScriptParser = SakuraScriptParser
public typealias MacUkagakaSSTPTransport = SSTPTransport
public typealias MacUkagakaSharedFMO = SharedFMO

/// MacUkagakaライブラリの設定とヘルパー
public struct MacUkagakaLibrary {
    
    /// ライブラリバージョン
    public static let version = "1.0.0"
    
    /// リソースパスの取得
    public static func getResourcePath() -> String? {
        guard let bundlePath = Bundle.module.resourcePath else { return nil }
        return bundlePath + "/AINanikaAIChan"
    }
    
    /// MacUkagakaアプリケーションを初期化
    public static func initializeApplication() -> NSApplication {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        return app
    }
}
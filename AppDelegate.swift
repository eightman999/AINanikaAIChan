//  © eightman 2005-2025
//  Furin-lab All Rights Reserved.
//  ゴーストマネージャーとウィンドウを初期化するmacOSアプリのデリゲート。

import Cocoa
import Foundation
import MacUkagaka

/// アプリケーション固有のエラータイプ
enum AppError: LocalizedError {
    case initializationFailed(component: String, underlyingError: Error)
    case dependencyMissing(component: String, missing: String)
    case shioriConversionFailed(underlyingError: Error)
    
    var errorDescription: String? {
        switch self {
        case .initializationFailed(let component, let underlyingError):
            return "\(component)の初期化に失敗しました。原因: \(underlyingError.localizedDescription)"
        case .dependencyMissing(let component, let missing):
            return "\(component)を初期化できませんでした。必要なコンポーネント「\(missing)」が見つかりません。"
        case .shioriConversionFailed(let underlyingError):
            return "SHIORI変換処理中にエラーが発生しました。原因: \(underlyingError.localizedDescription)"
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    // MARK: - Properties
    
    /// ゴーストのリソース管理とスクリプト処理を担当する。
    var ghostManager: MacUkagakaGhostManager?
    /// キャラクターを表示するメインウィンドウ。
    var characterWindow: MacUkagakaCharacterWindowController?
    /// Ukagakaディレクトリの管理を担当する。
    var directoryManager: UkagakaDirectoryManager?
    /// SHIORIコードの変換とキャッシュを担当する。
    var shioriConverterManager: SHIORIConverterManager?
    
    // MARK: - Application Lifecycle
    
    /// アプリ起動後に呼び出されるエントリーポイント。
    func applicationDidFinishLaunching(_ notification: Notification) {
        print("applicationDidFinishLaunching called")
        
        do {
            // 1. アプリ基本設定
            setupApplication()
            
            // 2. コアマネージャーの初期化
            try initializeCoreManagers()
            
            // 3. ゴーストのロードとウィンドウ表示
            try loadGhostAndShowWindow()
            
            // 4. 非同期でSHIORIキャッシュ変換処理を開始
            performInitialSHIORIConversion()
            
        } catch let appError as AppError {
            presentError(appError, title: "アプリケーション起動エラー", message: "アプリケーションの起動に失敗しました。")
            NSApp.terminate(self)
        } catch {
            presentError(error, title: "予期せぬエラー", message: "アプリケーションの起動中に予期せぬエラーが発生しました。")
            NSApp.terminate(self)
        }
    }
    
    /// アプリ終了時に呼び出される。
    func applicationWillTerminate(_ notification: Notification) {
        ghostManager?.shutdown()
    }
    
    /// ウィンドウがなくてもアプリを終了させない。
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false
    }
    
    /// セキュアコーディングをサポートすることを宣言。
    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        return true
    }
    
    // MARK: - Initialization Methods
    
    /// アプリの基本設定を行う。
    private func setupApplication() {
        print("setupApplication called")
        // LSUIElement = false の場合は .regular を使用
        NSApp.setActivationPolicy(.regular)
    }
    
    /// コアマネージャー（ディレクトリ管理、SHIORI変換）を初期化する。
    private func initializeCoreManagers() throws {
        print("--- コアマネージャーの初期化を開始 ---")
        
        // 1. UkagakaDirectoryManagerの初期化（同期処理）
        do {
            directoryManager = try UkagakaDirectoryManager()
            print("UkagakaDirectoryManager: 初期化成功")
        } catch {
            throw AppError.initializationFailed(component: "UkagakaDirectoryManager", underlyingError: error)
        }
        
        // 2. デフォルトゴーストの確保（内蔵ゴーストのフォールバック）
        guard let directoryManager = directoryManager else {
            throw AppError.dependencyMissing(component: "DefaultGhost", missing: "UkagakaDirectoryManager")
        }
        
        do {
            try directoryManager.ensureDefaultGhostExists()
            print("Default ghost availability ensured")
        } catch {
            throw AppError.initializationFailed(component: "DefaultGhost", underlyingError: error)
        }
        
        // 3. SHIORIConverterManagerの初期化（同期処理だが、内部で非同期処理を持つ）
        shioriConverterManager = SHIORIConverterManager(directoryManager: directoryManager)
        print("SHIORIConverterManager: 初期化成功")
        
        print("--- コアマネージャーの初期化が完了 ---")
    }
    
    /// ゴーストマネージャーを初期化してウィンドウを表示する。
    private func loadGhostAndShowWindow() throws {
        print("--- ゴーストのロードとウィンドウ表示を開始 ---")
        
        guard let directoryManager = directoryManager else {
            throw AppError.dependencyMissing(component: "GhostManager", missing: "UkagakaDirectoryManager")
        }
        
        // Swift SHIORI を試す（C# SHIORI で問題が発生している場合）
        let useSwiftSHIORI = true // デバッグ用: Swift SHIORI を使用
        
        do {
            // UkagakaDirectoryManagerを使用してフォールバック対応のGhostManagerを作成
            ghostManager = try MacUkagakaGhostManager()
            ghostManager?.delegate = self
            print("GhostManager initialized with UkagakaDirectoryManager and SwiftSHIORI: \(useSwiftSHIORI)")
            
            // StateManagerの初期化（アプリ起動時の状態更新）
            // SimpleStateManagerがSwiftSHIORI.swiftに統合されているので、ここでは直接の初期化は不要
            // SwiftSHIORI内のOnBootで状態更新が行われる
            
            // GhostManagerを開始
            try ghostManager?.start()
            print("GhostManager started")
            
        } catch {
            throw AppError.initializationFailed(component: "GhostManager", underlyingError: error)
        }
        
        // CharacterWindowControllerを作成
        guard let ghostManager = ghostManager else {
            throw AppError.dependencyMissing(component: "CharacterWindowController", missing: "GhostManager")
        }
        
        characterWindow = CharacterWindowController(ghostManager: ghostManager)
        print("CharacterWindowController created")
        
        // ウィンドウを表示
        if let window = characterWindow?.window {
            print("Window exists: frame=\(window.frame), isVisible=\(window.isVisible), level=\(window.level)")
            
            window.orderFront(nil)
            print("Window orderFront called")
            
            window.center()
            print("Window centered")
            print("Window isVisible after orderFront: \(window.isVisible)")
        } else {
            print("ERROR: Window is nil!")
            throw AppError.initializationFailed(component: "CharacterWindow", underlyingError: NSError(domain: "WindowError", code: 1, userInfo: [NSLocalizedDescriptionKey: "ウィンドウの作成に失敗しました"]))
        }
        
        print("--- ゴーストのロードとウィンドウ表示が完了 ---")
    }
    
    // MARK: - Asynchronous Operations
    
    /// アプリ起動時のSHIORI変換処理を非同期で実行する。
    private func performInitialSHIORIConversion() {
        print("--- 初期SHIORI変換処理を開始（非同期）---")
        
        guard let shioriConverterManager = shioriConverterManager else {
            print("SHIORIConverterManagerが初期化されていません。初期変換をスキップします。")
            return
        }
        
        // バックグラウンドキューで非同期実行
        Task {
            await shioriConverterManager.initializeOnStartup()
            print("--- 初期SHIORI変換処理が完了 ---")
        }
    }
    
    // MARK: - Error Handling
    
    /// エラーを表示する共通メソッド。
    private func presentError(_ error: Error, title: String, message: String) {
        let alert = NSAlert()
        alert.alertStyle = .critical
        alert.messageText = title
        alert.informativeText = "\(message)\n\n詳細: \(error.localizedDescription)"
        alert.runModal()
    }
    
    /// エラーを表示してアプリを終了する（既存メソッドの互換性維持）。
    private func showErrorAndExit(_ message: String) {
        let alert = NSAlert()
        alert.alertStyle = .critical
        alert.messageText = "エラー"
        alert.informativeText = message
        alert.runModal()
        NSApp.terminate(nil)
    }
}

// MARK: - GhostManagerDelegate

extension AppDelegate: GhostManagerDelegate {
    /// ゴーストからさくらスクリプトを受信したときに呼ばれる。
    func ghostManager(_ manager: MacUkagakaGhostManager, didReceiveScript script: String) {
        print("[AppDelegate] Received script from GhostManager: '\(script)'")
        DispatchQueue.main.async {
            print("[AppDelegate] Dispatching script to CharacterWindow: '\(script)'")
            self.characterWindow?.processScript(script)
        }
    }
    
    /// ゴーストでエラーが発生したときに呼ばれる。
    func ghostManager(_ manager: MacUkagakaGhostManager, didEncounterError error: Error) {
        DispatchQueue.main.async {
            self.showErrorAndExit("ゴーストエラー: \(error)")
        }
    }
}
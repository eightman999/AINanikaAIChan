//  © eightman 2005-2025
//  Furin-lab All Rights Reserved.
//  Swift Package版でゴーストを起動するmacOSアプリのデリゲート。

import Cocoa
import Foundation

public class AppDelegate: NSObject, NSApplicationDelegate {
    /// ゴーストのリソース管理とスクリプト処理を担当する。
    var ghostManager: GhostManager?
    /// キャラクターを表示するメインウィンドウ。
    var characterWindow: CharacterWindowController?
    
    /// アプリ起動後に呼び出されるエントリーポイント。
    public func applicationDidFinishLaunching(_ notification: Notification) {
        setupApplication()
        loadGhost()
    }
    
    /// アプリ終了時に呼び出される。
    public func applicationWillTerminate(_ notification: Notification) {
        ghostManager?.shutdown()
    }
    
    /// ウィンドウがなくてもアプリを終了させない。
    public func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false
    }
    
    /// アプリの基本設定を行う。
    private func setupApplication() {
        NSApp.setActivationPolicy(.accessory)
    }
    
    /// ゴーストマネージャーを初期化してウィンドウを表示する。
    private func loadGhost() {
        do {
            // デフォルトのAINanikaAIChanゴーストを読み込む
            ghostManager = try GhostManager()
            ghostManager?.delegate = self
            
            characterWindow = CharacterWindowController(ghostManager: ghostManager!)
            characterWindow?.showWindow(nil)
            
            try ghostManager?.start()
        } catch {
            showErrorAndExit("ゴーストの初期化に失敗しました: \(error)")
        }
    }
    
    
    /// エラーを表示してアプリを終了する。
    private func showErrorAndExit(_ message: String) {
        let alert = NSAlert()
        alert.alertStyle = .critical
        alert.messageText = "エラー"
        alert.informativeText = message
        alert.runModal()
        NSApp.terminate(nil)
    }
}

extension AppDelegate: GhostManagerDelegate {
    /// ゴーストからさくらスクリプトを受信したときに呼ばれる。
    public func ghostManager(_ manager: GhostManager, didReceiveScript script: String) {
        DispatchQueue.main.async {
            self.characterWindow?.processScript(script)
        }
    }
    
    /// ゴーストでエラーが発生したときに呼ばれる。
    public func ghostManager(_ manager: GhostManager, didEncounterError error: Error) {
        DispatchQueue.main.async {
            self.showErrorAndExit("ゴーストエラー: \(error)")
        }
    }
}
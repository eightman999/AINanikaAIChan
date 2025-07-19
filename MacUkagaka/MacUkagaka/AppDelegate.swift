//  © eightman 2005-2025
//  Furin-lab All Rights Reserved.
//  macOS app delegate for the Swift package build.

import Cocoa
import Foundation

class AppDelegate: NSObject, NSApplicationDelegate {
    var ghostManager: GhostManager?
    var characterWindow: CharacterWindowController?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        setupApplication()
        loadGhost()
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        ghostManager?.shutdown()
    }
    
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false
    }
    
    private func setupApplication() {
        NSApp.setActivationPolicy(.accessory)
    }
    
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
    func ghostManager(_ manager: GhostManager, didReceiveScript script: String) {
        DispatchQueue.main.async {
            self.characterWindow?.processScript(script)
        }
    }
    
    func ghostManager(_ manager: GhostManager, didEncounterError error: Error) {
        DispatchQueue.main.async {
            self.showErrorAndExit("ゴーストエラー: \(error)")
        }
    }
}
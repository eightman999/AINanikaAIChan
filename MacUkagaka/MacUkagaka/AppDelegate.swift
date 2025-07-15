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
        let ghostPath = findGhostPath()
        
        guard let path = ghostPath else {
            showErrorAndExit("ゴーストが見つかりません")
            return
        }
        
        do {
            ghostManager = try GhostManager(ghostPath: path)
            ghostManager?.delegate = self
            
            characterWindow = CharacterWindowController(ghostManager: ghostManager!)
            characterWindow?.showWindow(nil)
            
            try ghostManager?.start()
        } catch {
            showErrorAndExit("ゴーストの初期化に失敗しました: \(error)")
        }
    }
    
    private func findGhostPath() -> String? {
        let currentPath = FileManager.default.currentDirectoryPath
        let possiblePaths = [
            "\(currentPath)/ghost/master",
            "\(currentPath)/../ghost/master",
            "\(currentPath)/../../ghost/master"
        ]
        
        for path in possiblePaths {
            if FileManager.default.fileExists(atPath: path) {
                return path
            }
        }
        
        return nil
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
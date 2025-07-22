//  © eightman 2005-2025
//  Furin-lab All Rights Reserved.
//  キャラクターの状態の永続化を管理するクラス

import Foundation

/// キャラクターの状態をUserDefaultsに保存・読み込みするシングルトンクラス
class StateManager {
    static let shared = StateManager()
    
    private let userDefaults = UserDefaults.standard
    private let characterStateKey = "characterState_v1" // バージョン付きでキー名を管理
    
    /// 現在の状態（メモリキャッシュ）
    private var currentState: CharacterState?
    
    private init() {
        // 初期化時に状態を読み込む
        self.currentState = loadState()
    }
    
    /// 現在の状態を取得（メモリキャッシュから）
    func getCurrentState() -> CharacterState {
        if let state = currentState {
            return state
        } else {
            let newState = loadState()
            self.currentState = newState
            return newState
        }
    }
    
    /// 状態を更新してメモリとUserDefaultsの両方に保存
    func updateState(_ state: CharacterState) {
        self.currentState = state
        saveState(state)
    }
    
    /// 状態をUserDefaultsに保存
    private func saveState(_ state: CharacterState) {
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601 // 日時のエンコード形式を統一
            let data = try encoder.encode(state)
            userDefaults.set(data, forKey: characterStateKey)
            
            // 即座に同期して確実に保存
            userDefaults.synchronize()
            
            print("StateManager: Character state saved successfully")
        } catch {
            print("StateManager: Error saving character state: \(error)")
        }
    }
    
    /// 状態をUserDefaultsから読み込み
    private func loadState() -> CharacterState {
        guard let data = userDefaults.data(forKey: characterStateKey) else {
            print("StateManager: No saved state found, creating new character state")
            // 保存されたデータがない場合は、初期状態を返す
            return CharacterState()
        }
        
        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601 // 日時のデコード形式を統一
            let state = try decoder.decode(CharacterState.self, from: data)
            print("StateManager: Character state loaded successfully")
            print("StateManager: Total clicks: \(state.clickCount), Affection: \(state.emotion.affection), Mood: \(state.emotion.mood)")
            return state
        } catch {
            print("StateManager: Error loading character state: \(error)")
            // デコードに失敗した場合も、安全な初期状態を返す
            print("StateManager: Creating new character state due to load error")
            return CharacterState()
        }
    }
    
    /// アプリ起動時に呼び出す状態更新メソッド
    func updateOnBoot() {
        var state = getCurrentState()
        state.updateOnBoot()
        updateState(state)
        print("StateManager: State updated on boot. Total boots: \(state.totalBootCount)")
    }
    
    /// クリック時に呼び出す状態更新メソッド
    func updateOnClick() -> CharacterState {
        var state = getCurrentState()
        state.updateOnClick(at: Date())
        updateState(state)
        return state
    }
    
    /// 感情状態を更新するメソッド
    func updateEmotion(moodChange: Double, affectionChange: Double) {
        var state = getCurrentState()
        
        // 感情値の範囲を制限
        state.emotion.mood = max(-1.0, min(1.0, state.emotion.mood + moodChange))
        state.emotion.affection = max(0.0, min(1.0, state.emotion.affection + affectionChange))
        
        updateState(state)
        
        print("StateManager: Emotion updated - Mood: \(state.emotion.mood), Affection: \(state.emotion.affection)")
    }
    
    /// デバッグ用：状態をリセット
    func resetState() {
        let newState = CharacterState()
        updateState(newState)
        print("StateManager: Character state has been reset")
    }
    
    /// 状態の統計情報を取得
    func getStateStats() -> String {
        let state = getCurrentState()
        let daysSinceFirst = state.firstLaunchDate.map { 
            Calendar.current.dateComponents([.day], from: $0, to: Date()).day ?? 0
        } ?? 0
        
        return """
        === Character State Statistics ===
        Total Clicks: \(state.clickCount)
        Total App Launches: \(state.totalBootCount)
        Days Since First Launch: \(daysSinceFirst)
        Current Mood: \(String(format: "%.2f", state.emotion.mood))
        Affection Level: \(String(format: "%.2f", state.emotion.affection))
        Click History Count: \(state.clickHistory.count)
        Usual Time User: \(state.isUsualTimeForUser())
        """
    }
}
//  © eightman 2005-2025
//  Furin-lab All Rights Reserved.
//  状態の永続化管理(ghost/data/state.json、旧StateManager.swiftのファイル永続化版)

import Foundation

/// CharacterStateをJSONファイルへ永続化するマネージャ。
/// スレッド安全性のため内部直列キューで読み書きする。
final class StateStore {
    private let fileURL: URL
    private let queue = DispatchQueue(label: "jp.ourin.ainanika.statestore")
    private var cachedState: CharacterState?

    init(dataDirectory: URL) {
        let dir = dataDirectory
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        self.fileURL = dir.appendingPathComponent("state.json")
    }

    /// 現在の状態を取得(未保存なら新規作成)
    func load() -> CharacterState {
        queue.sync {
            if let cached = cachedState { return cached }
            guard let data = try? Data(contentsOf: fileURL),
                  let state = try? Self.decoder().decode(CharacterState.self, from: data) else {
                let fresh = CharacterState()
                cachedState = fresh
                return fresh
            }
            cachedState = state
            return state
        }
    }

    /// 状態を保存
    func save(_ state: CharacterState) {
        queue.sync {
            guard let data = try? Self.encoder().encode(state) else { return }
            try? data.write(to: fileURL, options: [.atomic, .completeFileProtection])
            cachedState = state
        }
    }

    /// 状態を更新して保存
    func update(_ transform: (inout CharacterState) -> Void) -> CharacterState {
        queue.sync {
            var state = cachedState ?? loadUnlocked()
            transform(&state)
            if let data = try? Self.encoder().encode(state) {
                try? data.write(to: fileURL, options: [.atomic, .completeFileProtection])
            }
            cachedState = state
            return state
        }
    }

    /// 状態をリセット
    func reset() {
        queue.sync {
            let fresh = CharacterState()
            if let data = try? Self.encoder().encode(fresh) {
                try? data.write(to: fileURL, options: [.atomic, .completeFileProtection])
            }
            cachedState = fresh
        }
    }

    private func loadUnlocked() -> CharacterState {
        guard let data = try? Data(contentsOf: fileURL),
              let state = try? Self.decoder().decode(CharacterState.self, from: data) else {
            return CharacterState()
        }
        return state
    }

    private static func encoder() -> JSONEncoder {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        e.outputFormatting = [.sortedKeys]
        return e
    }

    private static func decoder() -> JSONDecoder {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }
}

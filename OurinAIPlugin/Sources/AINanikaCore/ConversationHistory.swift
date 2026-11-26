//  © eightman 2005-2025
//  Furin-lab All Rights Reserved.
//  会話履歴の管理(リングバッファ+JSONL永続化)

import Foundation

/// 会話1往復の記録
struct ConversationTurn: Codable, Equatable {
    let role: String // "user" or "assistant"
    let text: String
    let timestamp: Date
}

/// 直近N往復の会話履歴。ghost/data/transcript.jsonl へ追記保存する。
final class ConversationHistory {
    private(set) var turns: [ConversationTurn] = []
    private let limit: Int
    private let transcriptURL: URL?
    private let queue = DispatchQueue(label: "jp.ourin.ainanika.history")

    /// - Parameters:
    ///   - limit: プロンプトへ渡す最大ターン数(リングバッファ)
    ///   - dataDirectory: transcript.jsonl の保存先(nilで永続化なし/テスト用)
    init(limit: Int = 10, dataDirectory: URL?) {
        self.limit = max(2, limit)
        if let dir = dataDirectory {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            transcriptURL = dir.appendingPathComponent("transcript.jsonl")
            loadFromDisk()
        } else {
            transcriptURL = nil
        }
    }

    func append(role: String, text: String) {
        let turn = ConversationTurn(role: role, text: text, timestamp: Date())
        queue.sync {
            turns.append(turn)
            if turns.count > limit {
                turns.removeFirst(turns.count - limit)
            }
        }
        appendToTranscript(turn)
    }

    /// ユーザー発言を記録
    func addUser(_ text: String) { append(role: "user", text: text) }

    /// キャラクター発言を記録
    func addAssistant(_ text: String) { append(role: "assistant", text: text) }

    /// 全履歴をクリア(ファイルは残す)
    func clearMemory() {
        queue.sync { turns.removeAll() }
    }

    private func loadFromDisk() {
        guard let url = transcriptURL,
              let data = try? String(contentsOf: url, encoding: .utf8) else { return }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let loaded = data.split(separator: "\n").compactMap { line -> ConversationTurn? in
            guard let d = line.data(using: .utf8) else { return nil }
            return try? decoder.decode(ConversationTurn.self, from: d)
        }
        queue.sync {
            turns = Array(loaded.suffix(limit))
        }
    }

    private func appendToTranscript(_ turn: ConversationTurn) {
        guard let url = transcriptURL else { return }
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(turn),
              let line = String(data: data, encoding: .utf8) else { return }
        queue.sync {
            if !FileManager.default.fileExists(atPath: url.path),
               FileManager.default.createFile(atPath: url.path, contents: nil) {
                #if os(macOS)
                try? FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
                #endif
            }
            if let handle = try? FileHandle(forWritingTo: url) {
                defer { try? handle.close() }
                _ = try? handle.seekToEnd()
                try? handle.write(contentsOf: Data((line + "\n").utf8))
            }
        }
    }
}

//  © eightman 2005-2025
//  Furin-lab All Rights Reserved.
//  SHIORI/3.0M C ABIエントリポイント(OurinのShioriLoader/OurinShioriXPCServiceから呼ばれる)

import Foundation
import AINanikaCore

/// ロード済みセッション(load dir単位)
final class ShioriSession {
    let engine: AINanikaEngine
    private let queue = DispatchQueue(label: "jp.ourin.ainanika.shiori")

    init(engine: AINanikaEngine) {
        self.engine = engine
    }

    /// 直列キューで処理する(watchdog 5秒以内に必ず返る設計)
    func handle(requestText: String) -> String {
        queue.sync {
            engine.handle(requestText: requestText)
        }
    }
}

private var currentSession: ShioriSession?

// MARK: - Swift向け内部ラッパー(CLIから利用)

/// shiori_load のSwiftラッパー
public func shioriLoad(path: String) -> Bool {
    path.withCString { shiori_load($0) }
}

/// shiori_request のSwiftラッパー
public func shioriRequest(text: String) -> String {
    let data = Data(text.utf8)
    var out: UnsafeMutablePointer<UInt8>?
    var outLen = 0
    let ok = data.withUnsafeBytes { raw -> Bool in
        guard let base = raw.baseAddress?.assumingMemoryBound(to: UInt8.self) else { return false }
        return shiori_request(base, data.count, &out, &outLen)
    }
    guard ok, let ptr = out else {
        return "SHIORI/3.0 500 Internal Server Error\r\n\r\n"
    }
    defer { shiori_free(ptr) }
    return String(bytes: UnsafeBufferPointer(start: ptr, count: outLen), encoding: .utf8)
        ?? "SHIORI/3.0 500 Internal Server Error\r\n\r\n"
}

/// shiori_unload のSwiftラッパー
public func shioriUnload() {
    shiori_unload()
}

// MARK: - C ABI

@_cdecl("shiori_load")
public func shiori_load(_ dir_utf8: UnsafePointer<CChar>?) -> Bool {
    guard let cPath = dir_utf8 else { return false }
    let path = String(cString: cPath)
    // Ourinはバンドルの親ディレクトリを渡してくる。
    // ghost/master/直下と master/modules/ 配置の両方で ai_config.json を探索する。
    let loadDir = URL(fileURLWithPath: path, isDirectory: true)
    var configDir = loadDirectory(forConfigIn: loadDir)

    // 見つからなければmaster(親)へも探しに行く
    if PluginConfiguration.load(from: configDir) == nil {
        let parent = loadDir.deletingLastPathComponent()
        if PluginConfiguration.load(from: parent) != nil {
            configDir = parent
        }
    }

    let engine = AINanikaEngine(loadDirectory: configDir)
    currentSession = ShioriSession(engine: engine)
    return true
}

@_cdecl("shiori_unload")
public func shiori_unload() {
    currentSession = nil
}

@_cdecl("shiori_request")
public func shiori_request(
    _ req: UnsafePointer<UInt8>?,
    _ req_len: Int,
    _ res: UnsafeMutablePointer<UnsafeMutablePointer<UInt8>?>?,
    _ res_len: UnsafeMutablePointer<Int>?
) -> Bool {
    guard let req, req_len >= 0, res != nil, res_len != nil else { return false }
    let data = Data(bytes: req, count: req_len)
    let text = String(data: data, encoding: .utf8)
        ?? String(data: data, encoding: .shiftJIS)
        ?? ""

    // セッションが無い場合でも最低限の応答は返す(ホストがハングしないように)
    let responseText: String
    if let session = currentSession {
        responseText = session.handle(requestText: text)
    } else if text.uppercased().contains("ID: VERSION") {
        responseText = WireCodec.okResponse(value: "AINanikaSHIORI/1.0")
    } else {
        responseText = WireCodec.noContentResponse()
    }

    let bytes = Array(responseText.utf8)
    let pointer = UnsafeMutablePointer<UInt8>.allocate(capacity: max(bytes.count, 1))
    if bytes.isEmpty {
        pointer.initialize(repeating: 0, count: 1)
    } else {
        pointer.initialize(from: bytes, count: bytes.count)
    }
    res?.pointee = pointer
    res_len?.pointee = bytes.count
    return true
}

@_cdecl("shiori_free")
public func shiori_free(_ p: UnsafeMutablePointer<UInt8>?) {
    p?.deallocate()
}

/// ai_config.json があるディレクトリを探す(bundle配置ではContents/Resources配下になる可能性もある)
private func loadDirectory(forConfigIn dir: URL) -> URL {
    var candidates = [dir]
    // .bundle 内 (Contents/Resources)
    if dir.pathExtension == "bundle" || dir.lastPathComponent.contains(".") {
        candidates.append(dir.appendingPathComponent("Contents/Resources"))
    }
    for candidate in candidates where PluginConfiguration.load(from: candidate) != nil {
        return candidate
    }
    return dir
}

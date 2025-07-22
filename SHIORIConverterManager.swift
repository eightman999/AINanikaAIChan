//  © eightman 2005-2025
//  Furin-lab All Rights Reserved.
//  SHIORIコードの変換と永続キャッシュ管理を担当するマネージャー

import Foundation

/// SHIORIコードの変換とキャッシュ管理を行うマネージャークラス
class SHIORIConverterManager {
    
    /// ディレクトリ管理のマネージャー
    private let directoryManager: UkagakaDirectoryManager
    
    /// UserDefaults用のキー
    private struct UserDefaultsKeys {
        static let cacheVersionPrefix = "SHIORICacheVersion_"
        static let lastConversionDatePrefix = "SHIORILastConversion_"
        static let cacheValidityPrefix = "SHIORICacheValid_"
    }
    
    /// キャッシュのバージョン（変換アルゴリズムが変わった時に更新）
    private let currentCacheVersion = 1
    
    /// エラータイプの定義
    enum SHIORIConverterError: Error {
        case ghostNotFound(String)
        case shioriFileNotFound(String)
        case conversionFailed(String)
        case cacheWriteFailed(String)
        case cacheReadFailed(String)
        case invalidCacheData
        case descriptFileNotFound(String)
    }
    
    /// 変換済みしおりコードの構造
    struct ConvertedSHIORI: Codable {
        let ghostName: String
        let originalPath: String
        let conversionDate: Date
        let cacheVersion: Int
        let convertedData: ConvertedSHIORIData
    }
    
    /// 変換されたSHIORIデータの構造
    struct ConvertedSHIORIData: Codable {
        let eventHandlers: [String: String] // イベント名 -> レスポンス
        let scriptFragments: [String] // 分解されたスクリプト断片
        let variables: [String: String] // 変数の値
        let metadata: ConversionMetadata
    }
    
    /// 変換時のメタデータ
    struct ConversionMetadata: Codable {
        let sourceFileSize: Int64
        let sourceFileHash: String
        let conversionTime: TimeInterval
        let shioriType: SHIORIType
    }
    
    /// SHIORIのタイプ
    enum SHIORIType: String, Codable {
        case dotnetShiori = "dotnet"
        case pythonShiori = "python"
        case csharpScript = "csharp_script"
        case swiftShiori = "swift"
        case unknown = "unknown"
    }
    
    /// 初期化
    init(directoryManager: UkagakaDirectoryManager) {
        self.directoryManager = directoryManager
    }
    
    /// 起動時の初期化処理：すべてのゴーストのキャッシュをチェック・変換
    func initializeOnStartup() async {
        print("SHIORIConverterManager: Starting initialization...")
        
        let ghostList = directoryManager.getGhostList()
        print("Found \(ghostList.count) ghosts: \(ghostList)")
        
        // 並行処理でキャッシュチェック・変換を実行
        await withTaskGroup(of: Void.self) { group in
            for ghostName in ghostList {
                group.addTask {
                    await self.checkAndConvertGhost(ghostName: ghostName)
                }
            }
        }
        
        print("SHIORIConverterManager: Initialization completed")
    }
    
    /// 指定されたゴーストのキャッシュをチェックし、必要に応じて変換
    private func checkAndConvertGhost(ghostName: String) async {
        print("Checking cache for ghost: \(ghostName)")
        
        do {
            let ghostDirectory = directoryManager.getGhostDirectoryURL(ghostName: ghostName)
            let descriptPath = directoryManager.getGhostDescriptFilePath(ghostName: ghostName)
            
            // descript.txtが存在するかチェック
            guard FileManager.default.fileExists(atPath: descriptPath) else {
                print("descript.txt not found for ghost: \(ghostName)")
                return
            }
            
            // キャッシュの有効性をチェック
            if isCacheValid(ghostName: ghostName) {
                print("Cache is valid for ghost: \(ghostName)")
                return
            }
            
            // キャッシュが無効または存在しない場合は変換を実行
            print("Converting SHIORI for ghost: \(ghostName)")
            try await convertSHIORI(ghostName: ghostName)
            
        } catch {
            print("Error processing ghost \(ghostName): \(error)")
        }
    }
    
    /// キャッシュの有効性をチェック
    func isCacheValid(ghostName: String) -> Bool {
        let userDefaults = UserDefaults.standard
        
        // キャッシュバージョンのチェック
        let cacheVersionKey = UserDefaultsKeys.cacheVersionPrefix + ghostName
        let cachedVersion = userDefaults.integer(forKey: cacheVersionKey)
        
        if cachedVersion != currentCacheVersion {
            print("Cache version mismatch for \(ghostName): cached=\(cachedVersion), current=\(currentCacheVersion)")
            return false
        }
        
        // キャッシュ有効性フラグのチェック
        let validityKey = UserDefaultsKeys.cacheValidityPrefix + ghostName
        let isValid = userDefaults.bool(forKey: validityKey)
        
        if !isValid {
            print("Cache marked as invalid for \(ghostName)")
            return false
        }
        
        // キャッシュファイルの存在チェック
        let cacheFilePath = getCacheFilePath(ghostName: ghostName)
        if !FileManager.default.fileExists(atPath: cacheFilePath) {
            print("Cache file not found for \(ghostName): \(cacheFilePath)")
            return false
        }
        
        return true
    }
    
    /// SHIORIコードを変換してキャッシュに保存
    func convertSHIORI(ghostName: String) async throws {
        let startTime = Date()
        print("Starting SHIORI conversion for: \(ghostName)")
        
        // SHIORIファイルのパスを特定
        let shioriPath = try findSHIORIFile(ghostName: ghostName)
        let shioriType = determineSHIORIType(path: shioriPath)
        
        print("Found SHIORI file: \(shioriPath) (type: \(shioriType.rawValue))")
        
        // ファイルのハッシュとサイズを取得
        let fileAttributes = try FileManager.default.attributesOfItem(atPath: shioriPath)
        let fileSize = fileAttributes[.size] as? Int64 ?? 0
        let fileHash = try calculateFileHash(path: shioriPath)
        
        // SHIORIタイプに応じて変換処理を実行
        let convertedData = try await performConversion(
            shioriPath: shioriPath, 
            shioriType: shioriType,
            ghostName: ghostName
        )
        
        // メタデータを作成
        let conversionTime = Date().timeIntervalSince(startTime)
        let metadata = ConversionMetadata(
            sourceFileSize: fileSize,
            sourceFileHash: fileHash,
            conversionTime: conversionTime,
            shioriType: shioriType
        )
        
        // 変換結果をまとめる
        let convertedSHIORI = ConvertedSHIORI(
            ghostName: ghostName,
            originalPath: shioriPath,
            conversionDate: Date(),
            cacheVersion: currentCacheVersion,
            convertedData: ConvertedSHIORIData(
                eventHandlers: convertedData.eventHandlers,
                scriptFragments: convertedData.scriptFragments,
                variables: convertedData.variables,
                metadata: metadata
            )
        )
        
        // キャッシュに保存
        try saveCacheToFile(convertedSHIORI: convertedSHIORI, ghostName: ghostName)
        
        // UserDefaultsにキャッシュ情報を記録
        updateCacheMetadata(ghostName: ghostName, isValid: true)
        
        print("SHIORI conversion completed for \(ghostName) in \(String(format: "%.3f", conversionTime))s")
    }
    
    /// SHIORIファイルを探す
    private func findSHIORIFile(ghostName: String) throws -> String {
        let ghostDirectory = directoryManager.getGhostDirectoryURL(ghostName: ghostName)
        let fileManager = FileManager.default
        
        // よくあるSHIORIファイル名のパターン
        let shioriPatterns = [
            "MacUkagaka.SHIORI",
            "shiori.dll",
            "shiori.exe", 
            "shiori.py",
            "shiori.csx"
        ]
        
        // 1. ゴーストディレクトリ直下を検索
        for pattern in shioriPatterns {
            let filePath = ghostDirectory.appendingPathComponent(pattern).path
            if fileManager.fileExists(atPath: filePath) {
                return filePath
            }
        }
        
        // 2. shiori/サブディレクトリを検索
        let shioriDirectory = ghostDirectory.appendingPathComponent("shiori")
        if fileManager.fileExists(atPath: shioriDirectory.path) {
            for pattern in shioriPatterns {
                let filePath = shioriDirectory.appendingPathComponent(pattern).path
                if fileManager.fileExists(atPath: filePath) {
                    return filePath
                }
            }
        }
        
        // 3. パターンマッチしない場合はdescript.txtから情報を取得
        let descriptPath = directoryManager.getGhostDescriptFilePath(ghostName: ghostName)
        if let shioriPath = extractSHIORIPathFromDescript(descriptPath: descriptPath) {
            // 相対パスの場合はゴーストディレクトリからの相対パスとして解釈
            let fullPath = ghostDirectory.appendingPathComponent(shioriPath).path
            if fileManager.fileExists(atPath: fullPath) {
                return fullPath
            }
        }
        
        throw SHIORIConverterError.shioriFileNotFound(ghostName)
    }
    
    /// descript.txtからSHIORIパスを抽出
    private func extractSHIORIPathFromDescript(descriptPath: String) -> String? {
        do {
            let content = try String(contentsOfFile: descriptPath, encoding: .utf8)
            for line in content.components(separatedBy: .newlines) {
                let parts = line.components(separatedBy: ",")
                if parts.count >= 2 {
                    let key = parts[0].trimmingCharacters(in: .whitespaces)
                    let value = parts[1].trimmingCharacters(in: .whitespaces)
                    
                    if key == "shiori" {
                        return value
                    }
                }
            }
        } catch {
            print("Failed to read descript.txt: \(error)")
        }
        return nil
    }
    
    /// SHIORIタイプを判定
    private func determineSHIORIType(path: String) -> SHIORIType {
        if path.contains("MacUkagaka.SHIORI") {
            return .dotnetShiori
        } else if path.hasSuffix(".dll") || path.hasSuffix(".exe") {
            return .dotnetShiori
        } else if path.hasSuffix(".py") {
            return .pythonShiori
        } else if path.hasSuffix(".csx") {
            return .csharpScript
        } else {
            return .unknown
        }
    }
    
    /// 実際の変換処理を実行
    private func performConversion(shioriPath: String, shioriType: SHIORIType, ghostName: String) async throws -> ConvertedSHIORIData {
        switch shioriType {
        case .dotnetShiori, .csharpScript:
            return try await convertDotNetSHIORI(shioriPath: shioriPath)
        case .pythonShiori:
            return try await convertPythonSHIORI(shioriPath: shioriPath)
        case .swiftShiori:
            return try await convertSwiftSHIORI(shioriPath: shioriPath)
        case .unknown:
            return try await convertUnknownSHIORI(shioriPath: shioriPath)
        }
    }
    
    /// .NET SHIORI の変換（簡易版）
    private func convertDotNetSHIORI(shioriPath: String) async throws -> ConvertedSHIORIData {
        // 実際の実装では、SHIORIプロセスを起動してテストリクエストを送信し、
        // レスポンスパターンを学習するか、ソースコードを解析します
        
        print("Converting .NET SHIORI: \(shioriPath)")
        
        // 基本的なイベントハンドラーのサンプル
        let eventHandlers: [String: String] = [
            "OnBoot": "\\h\\s[0]こんにちは！\\e",
            "OnClose": "\\h\\s[0]さようなら！\\e",
            "OnMouseClick": "\\h\\s[0]クリックありがとう！\\e"
        ]
        
        let scriptFragments = [
            "\\h\\s[0]", // スコープ0に切り替え
            "\\s[0]",    // サーフェス0
            "\\e"        // 終了タグ
        ]
        
        let variables: [String: String] = [:]
        
        return ConvertedSHIORIData(
            eventHandlers: eventHandlers,
            scriptFragments: scriptFragments,
            variables: variables,
            metadata: ConversionMetadata(
                sourceFileSize: 0,
                sourceFileHash: "",
                conversionTime: 0,
                shioriType: .dotnetShiori
            )
        )
    }
    
    /// Python SHIORI の変換（簡易版）
    private func convertPythonSHIORI(shioriPath: String) async throws -> ConvertedSHIORIData {
        print("Converting Python SHIORI: \(shioriPath)")
        
        // Pythonファイルの内容を読み込んで簡易解析
        let content = try String(contentsOfFile: shioriPath, encoding: .utf8)
        var eventHandlers: [String: String] = [:]
        
        // 簡易的なパターンマッチング（実際にはもっと高度な解析が必要）
        let lines = content.components(separatedBy: .newlines)
        for line in lines {
            if line.contains("OnBoot") && line.contains("return") {
                eventHandlers["OnBoot"] = extractPythonReturn(line: line)
            }
            // 他のイベントも同様に処理
        }
        
        return ConvertedSHIORIData(
            eventHandlers: eventHandlers,
            scriptFragments: [],
            variables: [:],
            metadata: ConversionMetadata(
                sourceFileSize: 0,
                sourceFileHash: "",
                conversionTime: 0,
                shioriType: .pythonShiori
            )
        )
    }
    
    /// Swift SHIORI の変換（現在のSwiftSHIORIクラス用）
    private func convertSwiftSHIORI(shioriPath: String) async throws -> ConvertedSHIORIData {
        print("Converting Swift SHIORI: \(shioriPath)")
        
        // SwiftSHIORIクラスの既知のレスポンスを使用
        let eventHandlers: [String: String] = [
            "OnBoot": "\\h\\s[0]こんにちは！SwiftSHIORIです。\\e",
            "OnClose": "\\h\\s[0]さようなら！\\e",
            "OnMouseClick": "\\h\\s[0]クリックありがとう！\\e",
            "OnTalk": "\\h\\s[0]こんにちは！\\e"
        ]
        
        return ConvertedSHIORIData(
            eventHandlers: eventHandlers,
            scriptFragments: [],
            variables: [:],
            metadata: ConversionMetadata(
                sourceFileSize: 0,
                sourceFileHash: "",
                conversionTime: 0,
                shioriType: .swiftShiori
            )
        )
    }
    
    /// 不明な形式のSHIORI変換
    private func convertUnknownSHIORI(shioriPath: String) async throws -> ConvertedSHIORIData {
        print("Converting unknown SHIORI type: \(shioriPath)")
        throw SHIORIConverterError.conversionFailed("Unsupported SHIORI type")
    }
    
    /// Python return文から値を抽出（簡易版）
    private func extractPythonReturn(line: String) -> String {
        // 'return "value"' から "value" を抽出
        if let range = line.range(of: "return \"") {
            let afterReturn = line[range.upperBound...]
            if let endQuote = afterReturn.range(of: "\"") {
                return String(afterReturn[..<endQuote.lowerBound])
            }
        }
        return "\\h\\s[0]応答なし\\e"
    }
    
    /// ファイルのハッシュ値を計算
    private func calculateFileHash(path: String) throws -> String {
        let data = try Data(contentsOf: URL(fileURLWithPath: path))
        let hash = data.sha256
        return hash.map { String(format: "%02hhx", $0) }.joined()
    }
    
    /// キャッシュファイルのパスを取得
    private func getCacheFilePath(ghostName: String) -> String {
        let cacheDirectory = directoryManager.getGhostCacheDirectoryURL(ghostName: ghostName)
        return cacheDirectory.appendingPathComponent("shiori_cache.json").path
    }
    
    /// キャッシュをファイルに保存
    private func saveCacheToFile(convertedSHIORI: ConvertedSHIORI, ghostName: String) throws {
        let cacheFilePath = getCacheFilePath(ghostName: ghostName)
        
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = .prettyPrinted
            
            let data = try encoder.encode(convertedSHIORI)
            try data.write(to: URL(fileURLWithPath: cacheFilePath))
            
            print("Cache saved to: \(cacheFilePath)")
        } catch {
            print("Failed to save cache: \(error)")
            throw SHIORIConverterError.cacheWriteFailed(ghostName)
        }
    }
    
    /// キャッシュファイルから読み込み
    func loadCacheFromFile(ghostName: String) throws -> ConvertedSHIORI {
        let cacheFilePath = getCacheFilePath(ghostName: ghostName)
        
        do {
            let data = try Data(contentsOf: URL(fileURLWithPath: cacheFilePath))
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            
            let convertedSHIORI = try decoder.decode(ConvertedSHIORI.self, from: data)
            return convertedSHIORI
        } catch {
            print("Failed to load cache: \(error)")
            throw SHIORIConverterError.cacheReadFailed(ghostName)
        }
    }
    
    /// キャッシュのメタデータをUserDefaultsに更新
    private func updateCacheMetadata(ghostName: String, isValid: Bool) {
        let userDefaults = UserDefaults.standard
        
        userDefaults.set(currentCacheVersion, forKey: UserDefaultsKeys.cacheVersionPrefix + ghostName)
        userDefaults.set(Date(), forKey: UserDefaultsKeys.lastConversionDatePrefix + ghostName)
        userDefaults.set(isValid, forKey: UserDefaultsKeys.cacheValidityPrefix + ghostName)
    }
    
    /// 指定されたゴーストのキャッシュを無効化
    func invalidateCache(ghostName: String) {
        updateCacheMetadata(ghostName: ghostName, isValid: false)
        print("Cache invalidated for ghost: \(ghostName)")
    }
    
    /// すべてのキャッシュを無効化
    func invalidateAllCaches() {
        let ghostList = directoryManager.getGhostList()
        for ghostName in ghostList {
            invalidateCache(ghostName: ghostName)
        }
        print("All caches invalidated")
    }
}

// MARK: - Data Extension for SHA256
extension Data {
    var sha256: Data {
        var hash = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
        self.withUnsafeBytes {
            _ = CC_SHA256($0.baseAddress, CC_LONG(self.count), &hash)
        }
        return Data(hash)
    }
}

// 必要に応じてCommonCryptoをインポート
import CommonCrypto
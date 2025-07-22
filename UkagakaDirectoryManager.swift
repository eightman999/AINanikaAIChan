//  © eightman 2005-2025
//  Furin-lab All Rights Reserved.
//  Ukagakaディレクトリの管理とゴースト/しおりコードの格納を担当するマネージャー

import Foundation

/// Ukagakaディレクトリとゴーストリソースの管理を行うマネージャークラス
class UkagakaDirectoryManager {
    
    /// 定数定義
    private enum Constants {
        static let ukagakaDirectoryName = "Ukagaka"
        static let cacheDirectoryName = "Cache"
        static let surfaceDirectoryName = "Surface"
        static let descriptFileName = "descript.txt"
        static let defaultGhostName = "AINanikaAIChan"
        static let bundledGhostDirectory = "ghost"
        static let bundledShellDirectory = "shell"
        static let bundledSHIORIDirectory = "shiori"
    }
    
    /// ドキュメントディレクトリ下のUkagaka/フォルダのURL
    private let ukagakaDirectoryURL: URL
    
    /// エラータイプの定義
    enum UkagakaDirectoryError: Error, LocalizedError {
        case documentDirectoryNotFound
        case directoryCreationFailed(URL, Error)
        case ghostDirectoryCreationFailed(String, Error)
        case fileOperationFailed(String, Error)
        case invalidGhostData
        case failedToGetStorageInfo(Error)
        case failedToCalculateDirectorySize(URL, Error)
        
        var errorDescription: String? {
            switch self {
            case .documentDirectoryNotFound:
                return "ドキュメントディレクトリが見つかりませんでした。"
            case .directoryCreationFailed(let url, let error):
                return "ディレクトリの作成に失敗しました: \(url.lastPathComponent) - \(error.localizedDescription)"
            case .ghostDirectoryCreationFailed(let ghostName, let error):
                return "ゴーストディレクトリの作成に失敗しました: \(ghostName) - \(error.localizedDescription)"
            case .fileOperationFailed(let operation, let error):
                return "ファイル操作に失敗しました: \(operation) - \(error.localizedDescription)"
            case .invalidGhostData:
                return "無効なゴーストデータです。"
            case .failedToGetStorageInfo(let error):
                return "ストレージ情報の取得に失敗しました: \(error.localizedDescription)"
            case .failedToCalculateDirectorySize(let url, let error):
                return "ディレクトリサイズ計算に失敗しました: \(url.lastPathComponent) - \(error.localizedDescription)"
            }
        }
    }
    
    /// 初期化時にUkagaka/ディレクトリを作成または確認
    init() throws {
        let fileManager = FileManager.default
        
        // ドキュメントディレクトリを取得
        guard let documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
            throw UkagakaDirectoryError.documentDirectoryNotFound
        }
        
        // Ukagaka/ディレクトリのURLを設定
        self.ukagakaDirectoryURL = documentsDirectory.appendingPathComponent(Constants.ukagakaDirectoryName)
        
        // Ukagaka/ディレクトリが存在しない場合は作成
        try createDirectoryIfNeeded(at: ukagakaDirectoryURL)
        
        // 適切なロギングシステムを使用する (例: OSLog)
        // Logger.log("UkagakaDirectoryManager initialized: \(ukagakaDirectoryURL.path)", level: .info)
    }
    
    /// 指定されたURLにディレクトリを作成（必要に応じて）
    private func createDirectoryIfNeeded(at url: URL) throws {
        let fileManager = FileManager.default
        
        if !fileManager.fileExists(atPath: url.path) {
            do {
                try fileManager.createDirectory(at: url, withIntermediateDirectories: true, attributes: nil)
                // 適切なロギングシステムを使用する (例: OSLog)
                // Logger.log("Created directory: \(url.path)", level: .info)
            } catch {
                // 適切なロギングシステムを使用する
                // Logger.log("Failed to create directory: \(url.path), error: \(error.localizedDescription)", level: .error)
                throw UkagakaDirectoryError.directoryCreationFailed(url, error)
            }
        }
    }
    
    /// Ukagaka/ディレクトリのパスを取得
    func getUkagakaDirectoryPath() -> String {
        return ukagakaDirectoryURL.path
    }
    
    /// Ukagaka/ディレクトリのURLを取得
    func getUkagakaDirectoryURL() -> URL {
        return ukagakaDirectoryURL
    }
    
    /// 指定されたゴースト用のディレクトリを作成
    func createGhostDirectory(ghostName: String) throws -> URL {
        // ghostNameのサニタイズ（ユーザー入力の場合）
        let sanitizedGhostName = ghostName.replacingOccurrences(of: "/", with: "_").replacingOccurrences(of: "..", with: "_")
        let ghostDirectoryURL = ukagakaDirectoryURL.appendingPathComponent(sanitizedGhostName)
        
        do {
            try createDirectoryIfNeeded(at: ghostDirectoryURL)
            
            // ゴースト内のサブディレクトリも作成
            let cacheDirectoryURL = ghostDirectoryURL.appendingPathComponent(Constants.cacheDirectoryName)
            try createDirectoryIfNeeded(at: cacheDirectoryURL)
            
            let surfaceDirectoryURL = ghostDirectoryURL.appendingPathComponent(Constants.surfaceDirectoryName)
            try createDirectoryIfNeeded(at: surfaceDirectoryURL)
            
            // 適切なロギングシステムを使用する
            // Logger.log("Created ghost directory structure for: \(ghostName)", level: .info)
            return ghostDirectoryURL
        } catch {
            throw UkagakaDirectoryError.ghostDirectoryCreationFailed(ghostName, error)
        }
    }
    
    /// ゴーストのリストを取得
    func getGhostList() -> [String] {
        let fileManager = FileManager.default
        
        do {
            let contents = try fileManager.contentsOfDirectory(at: ukagakaDirectoryURL, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles])
            
            return contents.compactMap { url in
                var isDirectory: ObjCBool = false
                if fileManager.fileExists(atPath: url.path, isDirectory: &isDirectory), isDirectory.boolValue {
                    return url.lastPathComponent
                }
                return nil
            }.sorted()
        } catch {
            // 適切なロギングシステムを使用する
            // Logger.log("Failed to get ghost list: \(error.localizedDescription)", level: .error)
            return []
        }
    }
    
    /// 指定されたゴーストディレクトリのURLを取得
    func getGhostDirectoryURL(ghostName: String) -> URL {
        return ukagakaDirectoryURL.appendingPathComponent(ghostName)
    }
    
    /// 指定されたゴーストのキャッシュディレクトリのURLを取得
    func getGhostCacheDirectoryURL(ghostName: String) -> URL {
        return getGhostDirectoryURL(ghostName: ghostName).appendingPathComponent("Cache")
    }
    
    /// 指定されたゴーストのサーフェスディレクトリのURLを取得
    func getGhostSurfaceDirectoryURL(ghostName: String) -> URL {
        return getGhostDirectoryURL(ghostName: ghostName).appendingPathComponent("Surface")
    }
    
    /// ゴーストのdescript.txtファイルのパスを取得
    func getGhostDescriptFilePath(ghostName: String) -> String {
        return getGhostDirectoryURL(ghostName: ghostName).appendingPathComponent(Constants.descriptFileName).path
    }
    
    /// ゴーストのファイルをコピー
    func copyGhostFile(from sourceURL: URL, to ghostName: String, fileName: String) throws {
        let destinationURL = getGhostDirectoryURL(ghostName: ghostName).appendingPathComponent(fileName)
        let fileManager = FileManager.default
        
        // 既存のファイルがある場合は削除
        if fileManager.fileExists(atPath: destinationURL.path) {
            try fileManager.removeItem(at: destinationURL)
        }
        
        do {
            try fileManager.copyItem(at: sourceURL, to: destinationURL)
            // 適切なロギングシステムを使用する
            // Logger.log("Copied file to: \(destinationURL.path)", level: .info)
        } catch {
            // 適切なロギングシステムを使用する
            // Logger.log("Failed to copy file from \(sourceURL.lastPathComponent) to \(destinationURL.lastPathComponent): \(error.localizedDescription)", level: .error)
            throw UkagakaDirectoryError.fileOperationFailed("Failed to copy \(fileName)", error)
        }
    }
    
    /// ゴーストディレクトリ全体をコピー
    func copyGhostDirectory(from sourceDirectoryURL: URL, ghostName: String) throws {
        let destinationURL = getGhostDirectoryURL(ghostName: ghostName)
        let fileManager = FileManager.default
        
        // 既存のディレクトリがある場合は削除
        if fileManager.fileExists(atPath: destinationURL.path) {
            try fileManager.removeItem(at: destinationURL)
        }
        
        do {
            try fileManager.copyItem(at: sourceDirectoryURL, to: destinationURL)
            // 適切なロギングシステムを使用する
            // Logger.log("Copied ghost directory to: \(destinationURL.path)", level: .info)
        } catch {
            // 適切なロギングシステムを使用する
            // Logger.log("Failed to copy ghost directory from \(sourceDirectoryURL.lastPathComponent) to \(destinationURL.lastPathComponent): \(error.localizedDescription)", level: .error)
            throw UkagakaDirectoryError.fileOperationFailed("Failed to copy ghost directory", error)
        }
    }
    
    /// 指定されたゴーストディレクトリを削除
    func removeGhostDirectory(ghostName: String) throws {
        let ghostDirectoryURL = getGhostDirectoryURL(ghostName: ghostName)
        let fileManager = FileManager.default
        
        if fileManager.fileExists(atPath: ghostDirectoryURL.path) {
            do {
                try fileManager.removeItem(at: ghostDirectoryURL)
                // 適切なロギングシステムを使用する
                // Logger.log("Removed ghost directory: \(ghostDirectoryURL.path)", level: .info)
            } catch {
                // 適切なロギングシステムを使用する
                // Logger.log("Failed to remove ghost directory \(ghostDirectoryURL.lastPathComponent): \(error.localizedDescription)", level: .error)
                throw UkagakaDirectoryError.fileOperationFailed("Failed to remove \(ghostName)", error)
            }
        }
    }
    
    /// ストレージ使用量の情報を取得
    func getStorageInfo() throws -> (totalSize: Int64, availableSize: Int64) {
        let fileManager = FileManager.default
        
        do {
            let attributes = try fileManager.attributesOfFileSystem(forPath: ukagakaDirectoryURL.path)
            let totalSize = attributes[.systemSize] as? Int64 ?? 0
            let freeSize = attributes[.systemFreeSize] as? Int64 ?? 0
            return (totalSize: totalSize, availableSize: freeSize)
        } catch {
            // 適切なロギングシステムを使用する
            // Logger.log("Failed to get storage info: \(error.localizedDescription)", level: .error)
            throw UkagakaDirectoryError.failedToGetStorageInfo(error)
        }
    }
    
    // MARK: - Default Ghost Management
    
    /// ドキュメントディレクトリにゴーストがない場合、内蔵ゴーストを使用可能にする
    func ensureDefaultGhostExists() throws {
        let ghostList = getGhostList()
        
        if ghostList.isEmpty {
            // ゴーストが存在しない場合、内蔵ゴーストをコピー
            try copyBundledGhostToDocuments()
        }
    }
    
    /// 内蔵ゴーストをドキュメントディレクトリにコピー
    private func copyBundledGhostToDocuments() throws {
        guard let bundleURL = Bundle.main.resourceURL else {
            throw UkagakaDirectoryError.invalidGhostData
        }
        
        let bundledGhostURL = bundleURL.appendingPathComponent(Constants.bundledGhostDirectory)
        let bundledShellURL = bundleURL.appendingPathComponent(Constants.bundledShellDirectory)
        let bundledSHIORIURL = bundleURL.appendingPathComponent(Constants.bundledSHIORIDirectory)
        
        // 内蔵リソースの存在確認
        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: bundledGhostURL.path),
              fileManager.fileExists(atPath: bundledShellURL.path),
              fileManager.fileExists(atPath: bundledSHIORIURL.path) else {
            throw UkagakaDirectoryError.fileOperationFailed("内蔵リソースが見つかりません", 
                NSError(domain: "BundleError", code: 1, userInfo: [NSLocalizedDescriptionKey: "必要なリソースディレクトリが見つかりません"]))
        }
        
        // デフォルトゴーストディレクトリを作成
        let defaultGhostURL = try createGhostDirectory(ghostName: Constants.defaultGhostName)
        
        do {
            // ghostディレクトリの内容をコピー
            try copyDirectoryContents(from: bundledGhostURL, to: defaultGhostURL)
            
            // shellディレクトリを作成してコピー
            let shellDestinationURL = defaultGhostURL.appendingPathComponent("shell")
            try createDirectoryIfNeeded(at: shellDestinationURL)
            try copyDirectoryContents(from: bundledShellURL, to: shellDestinationURL)
            
            // shioriディレクトリを作成してコピー
            let shioriDestinationURL = defaultGhostURL.appendingPathComponent("shiori")
            try createDirectoryIfNeeded(at: shioriDestinationURL)
            try copyDirectoryContents(from: bundledSHIORIURL, to: shioriDestinationURL)
            
            // 適切なロギングシステムを使用する
            // Logger.log("Default ghost copied to documents: \(Constants.defaultGhostName)", level: .info)
            
        } catch {
            throw UkagakaDirectoryError.fileOperationFailed("内蔵ゴーストのコピーに失敗しました", error)
        }
    }
    
    /// ディレクトリの内容を別のディレクトリにコピー
    private func copyDirectoryContents(from sourceURL: URL, to destinationURL: URL) throws {
        let fileManager = FileManager.default
        
        let contents = try fileManager.contentsOfDirectory(at: sourceURL, 
                                                          includingPropertiesForKeys: nil, 
                                                          options: [.skipsHiddenFiles])
        
        for itemURL in contents {
            let destinationItemURL = destinationURL.appendingPathComponent(itemURL.lastPathComponent)
            
            // 既存ファイルがある場合は削除
            if fileManager.fileExists(atPath: destinationItemURL.path) {
                try fileManager.removeItem(at: destinationItemURL)
            }
            
            var isDirectory: ObjCBool = false
            if fileManager.fileExists(atPath: itemURL.path, isDirectory: &isDirectory) {
                if isDirectory.boolValue {
                    // ディレクトリの場合は再帰的にコピー
                    try fileManager.copyItem(at: itemURL, to: destinationItemURL)
                } else {
                    // ファイルの場合はコピー
                    try fileManager.copyItem(at: itemURL, to: destinationItemURL)
                }
            }
        }
    }
    
    /// デフォルトゴーストが使用可能かチェック
    func isDefaultGhostAvailable() -> Bool {
        let defaultGhostURL = getGhostDirectoryURL(ghostName: Constants.defaultGhostName)
        let descriptPath = getGhostDescriptFilePath(ghostName: Constants.defaultGhostName)
        
        return FileManager.default.fileExists(atPath: defaultGhostURL.path) &&
               FileManager.default.fileExists(atPath: descriptPath)
    }
    
    /// 使用可能なゴーストがない場合にデフォルトゴースト名を返す
    func getAvailableGhostName() -> String? {
        let ghostList = getGhostList()
        
        if !ghostList.isEmpty {
            return ghostList.first
        } else if isDefaultGhostAvailable() {
            return Constants.defaultGhostName
        } else {
            return nil
        }
    }
    
    /// Ukagakaディレクトリの合計使用量を計算
    func calculateUkagakaDirectorySize() -> Int64 {
        let fileManager = FileManager.default
        var totalSize: Int64 = 0
        
        func calculateDirectorySize(at url: URL) -> Int64 {
            var size: Int64 = 0
            
            if let enumerator = fileManager.enumerator(at: url, includingPropertiesForKeys: [.fileSizeKey], options: [.skipsHiddenFiles]) {
                for case let fileURL as URL in enumerator {
                    do {
                        let resourceValues = try fileURL.resourceValues(forKeys: [.fileSizeKey])
                        size += Int64(resourceValues.fileSize ?? 0)
                    } catch {
                        // 適切なロギングシステムを使用する
                        // Logger.log("Failed to get file size for: \(fileURL.path) - \(error.localizedDescription)", level: .error)
                        // ここではエラーをthrowせず、計算を続行するが、エラーを記録する
                    }
                }
            }
            
            return size
        }
        
        totalSize = calculateDirectorySize(at: ukagakaDirectoryURL)
        return totalSize
    }
}
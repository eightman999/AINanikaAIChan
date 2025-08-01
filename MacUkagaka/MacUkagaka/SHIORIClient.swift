//  © eightman 2005-2025
//  Furin-lab All Rights Reserved.
//  SHIORIプロセスを起動しスクリプト要求を処理するクラス。

import Foundation

public class SHIORIClient {
    /// ゴーストディレクトリへのパス。
    private let ghostPath: String
    /// SHIORI実行ファイルまたはスクリプトへのパス。
    private let shioriPath: String
    /// 実行中のSHIORIプロセス。
    private var process: Process?
    /// リクエスト送信用パイプ。
    private var inputPipe: Pipe?
    /// レスポンス受信用パイプ。
    private var outputPipe: Pipe?
    
    /// SHIORIとの通信で発生し得るエラー。
    enum SHIORIError: Error {
        /// プロセスの起動に失敗。
        case processNotStarted
        /// データの送受信に失敗。
        case communicationError
        /// 受信したレスポンスが不正。
        case invalidResponse
        /// プロセスが予期せず終了。
        case processTerminated
    }
    
    /// 指定されたゴーストパスとSHIORIパスでクライアントを生成。
    public init(ghostPath: String, shioriPath: String) {
        self.ghostPath = ghostPath
        self.shioriPath = shioriPath
    }
    
    /// ファイル種別に応じてSHIORIプロセスを起動。
    func start() throws {
        if shioriPath.hasSuffix(".dll") || shioriPath.hasSuffix(".exe") {
            if shioriPath.contains("MacUkagaka.SHIORI") {
                try startDotNetCoreShiori()
            } else if shioriPath.contains("SHIOLINK") {
                try startTestSHIORIScript()
            } else if shioriPath.hasSuffix(".exe") {
                try startDotNetShiori()
            } else {
                throw SHIORIError.processNotStarted
            }
        } else if shioriPath.hasSuffix(".csx") {
            try startDotNetScript()
        } else if shioriPath.hasSuffix(".py") {
            try startPythonShiori()
        } else if shioriPath.contains("MacUkagaka.SHIORI") {
            // 拡張子なしのMacUkagaka.SHIORIファイル
            try startDotNetCoreShiori()
        } else {
            throw SHIORIError.processNotStarted
        }
    }
    
    /// 同梱のPythonテストスクリプトを起動。
    private func startTestSHIORIScript() throws {
        let scriptPath = "\(ghostPath)/test_shiori.py"
        
        guard FileManager.default.fileExists(atPath: scriptPath) else {
            throw SHIORIError.processNotStarted
        }
        
        process = Process()
        inputPipe = Pipe()
        outputPipe = Pipe()
        
        process?.executableURL = URL(fileURLWithPath: "/usr/bin/python3")
        process?.arguments = [scriptPath]
        process?.currentDirectoryURL = URL(fileURLWithPath: ghostPath)
        process?.standardInput = inputPipe
        process?.standardOutput = outputPipe
        process?.standardError = outputPipe
        
        try process?.run()
        
        Thread.sleep(forTimeInterval: 0.5)
        
        guard let proc = process, proc.isRunning else {
            throw SHIORIError.processNotStarted
        }
    }
    
    /// .NET Framework版SHIORI実行ファイルを起動。
    private func startDotNetShiori() throws {
        let exePath = "\(ghostPath)/Rosalind.CSharp.exe"
        
        guard FileManager.default.fileExists(atPath: exePath) else {
            throw SHIORIError.processNotStarted
        }
        
        process = Process()
        inputPipe = Pipe()
        outputPipe = Pipe()
        
        process?.executableURL = URL(fileURLWithPath: "/usr/local/share/dotnet/dotnet")
        process?.arguments = [exePath]
        process?.currentDirectoryURL = URL(fileURLWithPath: ghostPath)
        process?.standardInput = inputPipe
        process?.standardOutput = outputPipe
        process?.standardError = outputPipe
        
        try process?.run()
        
        Thread.sleep(forTimeInterval: 1.0)
        
        guard let proc = process, proc.isRunning else {
            throw SHIORIError.processNotStarted
        }
    }

    /// .NET Core版SHIORI実行ファイルを直接起動。
    private func startDotNetCoreShiori() throws {
        // shioriPathは既に完全なパスなので、そのまま使用
        guard FileManager.default.fileExists(atPath: shioriPath) else {
            throw SHIORIError.processNotStarted
        }
        
        // 実行可能かチェック
        guard FileManager.default.isExecutableFile(atPath: shioriPath) else {
            throw SHIORIError.processNotStarted
        }

        process = Process()
        inputPipe = Pipe()
        outputPipe = Pipe()

        // .NET実行ファイルを直接実行
        process?.executableURL = URL(fileURLWithPath: shioriPath)
        process?.arguments = []
        process?.currentDirectoryURL = URL(fileURLWithPath: ghostPath)
        process?.standardInput = inputPipe
        process?.standardOutput = outputPipe
        process?.standardError = outputPipe

        try process?.run()

        Thread.sleep(forTimeInterval: 1.0)

        guard let proc = process, proc.isRunning else {
            throw SHIORIError.processNotStarted
        }
    }
    
    /// `dotnet script`でC#スクリプトを実行。
    private func startDotNetScript() throws {
        let scriptPath = "\(ghostPath)/\(shioriPath)"
        
        guard FileManager.default.fileExists(atPath: scriptPath) else {
            throw SHIORIError.processNotStarted
        }
        
        process = Process()
        inputPipe = Pipe()
        outputPipe = Pipe()
        
        process?.executableURL = URL(fileURLWithPath: "/usr/bin/dotnet")
        process?.arguments = ["script", scriptPath]
        process?.currentDirectoryURL = URL(fileURLWithPath: ghostPath)
        process?.standardInput = inputPipe
        process?.standardOutput = outputPipe
        process?.standardError = outputPipe
        
        try process?.run()
        
        Thread.sleep(forTimeInterval: 1.0)
        
        guard let proc = process, proc.isRunning else {
            throw SHIORIError.processNotStarted
        }
    }

    /// Python製SHIORIスクリプトを起動。
    private func startPythonShiori() throws {
        let scriptPath = "\(ghostPath)/\(shioriPath)"

        guard FileManager.default.fileExists(atPath: scriptPath) else {
            throw SHIORIError.processNotStarted
        }

        process = Process()
        inputPipe = Pipe()
        outputPipe = Pipe()

        process?.executableURL = URL(fileURLWithPath: "/usr/bin/python3")
        process?.arguments = [scriptPath]
        process?.currentDirectoryURL = URL(fileURLWithPath: ghostPath)
        process?.standardInput = inputPipe
        process?.standardOutput = outputPipe
        process?.standardError = outputPipe

        try process?.run()

        Thread.sleep(forTimeInterval: 0.5)

        guard let proc = process, proc.isRunning else {
            throw SHIORIError.processNotStarted
        }
    }
    
    /// 実行中のSHIORIプロセスを終了。
    func stop() {
        process?.terminate()
        process?.waitUntilExit()
        process = nil
        inputPipe = nil
        outputPipe = nil
    }
    
    /// SHIORIへリクエストを送り、レスポンスのValue部分を返す。
    func request(event: String, references: [String]) throws -> String {
        guard let proc = process, proc.isRunning else {
            throw SHIORIError.processTerminated
        }
        
        var request = "GET SHIORI/3.0\r\n"
        request += "ID: \(event)\r\n"
        
        for (index, reference) in references.enumerated() {
            request += "Reference\(index): \(reference)\r\n"
        }
        
        request += "\r\n"
        
        guard let inputData = request.data(using: .utf8),
              let input = inputPipe?.fileHandleForWriting else {
            throw SHIORIError.communicationError
        }
        
        input.write(inputData)
        
        guard let output = outputPipe?.fileHandleForReading else {
            throw SHIORIError.communicationError
        }
        
        var responseData = Data()
        let timeout = 5.0
        let startTime = Date()
        let endMarker = "\r\n\r\n".data(using: .utf8)!
        
        while responseData.isEmpty || !containsData(responseData, endMarker) {
            if Date().timeIntervalSince(startTime) > timeout {
                throw SHIORIError.communicationError
            }
            
            let chunk = output.availableData
            if !chunk.isEmpty {
                responseData.append(chunk)
            } else {
                Thread.sleep(forTimeInterval: 0.1)
            }
        }
        
        let response = String(data: responseData, encoding: .utf8) ?? ""
        
        return parseResponse(response)
    }
    
    /// データ内にパターンが含まれているか判定する。
    private func containsData(_ data: Data, _ pattern: Data) -> Bool {
        guard data.count >= pattern.count else { return false }
        
        for i in 0...(data.count - pattern.count) {
            let range = i..<(i + pattern.count)
            if data.subdata(in: range) == pattern {
                return true
            }
        }
        return false
    }
    
    /// `Value:` ヘッダー以降の本文を抽出する。
    private func parseResponse(_ response: String) -> String {
        let lines = response.components(separatedBy: .newlines)
        var inValueSection = false
        var value = ""
        
        for line in lines {
            if line.hasPrefix("Value: ") {
                value = String(line.dropFirst(7))
                inValueSection = true
            } else if inValueSection && line.isEmpty {
                break
            } else if inValueSection {
                value += "\n" + line
            }
        }
        
        return value.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

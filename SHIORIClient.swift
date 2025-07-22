//  © eightman 2005-2025
//  Furin-lab All Rights Reserved.
//  SHIORIプロセスを起動しスクリプト要求を処理するクラス。

import Foundation

class SHIORIClient {
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
    init(ghostPath: String, shioriPath: String) {
        self.ghostPath = ghostPath
        self.shioriPath = shioriPath
    }
    
    /// ファイル種別に応じてSHIORIプロセスを起動。
    func start() throws {
        print("SHIORIClient.start() called")
        print("ghostPath: \(ghostPath)")
        print("shioriPath: \(shioriPath)")
        
        if shioriPath.hasSuffix(".dll") || shioriPath.hasSuffix(".exe") {
            if shioriPath.contains("MacUkagaka.SHIORI") {
                print("Starting DotNetCore SHIORI")
                try startDotNetCoreShiori()
            } else if shioriPath.contains("SHIOLINK") {
                print("Starting Test SHIORI Script")
                try startTestSHIORIScript()
            } else if shioriPath.hasSuffix(".exe") {
                print("Starting DotNet SHIORI")
                try startDotNetShiori()
            } else {
                print("ERROR: Unsupported SHIORI type (.dll/.exe)")
                throw SHIORIError.processNotStarted
            }
        } else if shioriPath.hasSuffix(".csx") {
            print("Starting DotNet Script")
            try startDotNetScript()
        } else if shioriPath.hasSuffix(".py") {
            print("Starting Python SHIORI")
            try startPythonShiori()
        } else if shioriPath.contains("MacUkagaka.SHIORI") {
            // 拡張子なしのMacUkagaka.SHIORIファイル
            print("Starting DotNetCore SHIORI (no extension)")
            try startDotNetCoreShiori()
        } else {
            print("ERROR: Unknown SHIORI type: \(shioriPath)")
            throw SHIORIError.processNotStarted
        }
        
        print("SHIORIClient.start() completed successfully")
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
        print("startDotNetCoreShiori() called")
        print("Checking SHIORI file existence: \(shioriPath)")
        
        // shioriPathは既に完全なパスなので、そのまま使用
        guard FileManager.default.fileExists(atPath: shioriPath) else {
            print("ERROR: SHIORI file does not exist: \(shioriPath)")
            throw SHIORIError.processNotStarted
        }
        print("SHIORI file exists")
        
        // 実行可能かチェック
        guard FileManager.default.isExecutableFile(atPath: shioriPath) else {
            print("ERROR: SHIORI file is not executable: \(shioriPath)")
            throw SHIORIError.processNotStarted
        }
        print("SHIORI file is executable")

        print("Creating Process and pipes")
        process = Process()
        inputPipe = Pipe()
        outputPipe = Pipe()

        print("Setting up process configuration")
        // .NET実行ファイルを直接実行
        process?.executableURL = URL(fileURLWithPath: shioriPath)
        process?.arguments = []
        process?.currentDirectoryURL = URL(fileURLWithPath: ghostPath)
        process?.standardInput = inputPipe
        process?.standardOutput = outputPipe
        process?.standardError = outputPipe

        print("Attempting to run process: \(shioriPath)")
        do {
            try process?.run()
            print("Process.run() completed")
        } catch {
            print("ERROR: Failed to run process: \(error)")
            throw SHIORIError.processNotStarted
        }

        print("Waiting 1 second for process to start...")
        Thread.sleep(forTimeInterval: 1.0)

        guard let proc = process, proc.isRunning else {
            print("ERROR: Process is not running after launch")
            if let proc = process {
                print("Process state - isRunning: \(proc.isRunning), processIdentifier: \(proc.processIdentifier)")
                if proc.isRunning == false {
                    print("Process terminationStatus: \(proc.terminationStatus)")
                }
            }
            throw SHIORIError.processNotStarted
        }
        
        print("Process started successfully - PID: \(proc.processIdentifier)")
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
        // デバッグ: OnSecondChangeは頻繁なので詳細ログを抑制
        let isFrequentEvent = event == "OnSecondChange"
        if !isFrequentEvent {
            print("SHIORIClient.request() called with event: \(event)")
        }
        
        guard let proc = process, proc.isRunning else {
            print("ERROR: Process is not running")
            throw SHIORIError.processTerminated
        }
        if !isFrequentEvent {
            print("Process is running (PID: \(proc.processIdentifier))")
        }
        
        var request = "GET SHIORI/3.0\r\n"
        request += "ID: \(event)\r\n"
        
        for (index, reference) in references.enumerated() {
            request += "Reference\(index): \(reference)\r\n"
        }
        
        request += "\r\n"
        if !isFrequentEvent {
            print("Sending request to SHIORI:")
            print("---")
            print(request.replacingOccurrences(of: "\r\n", with: "\\r\\n"))
            print("---")
        }
        
        guard let inputData = request.data(using: .utf8),
              let input = inputPipe?.fileHandleForWriting else {
            print("ERROR: Failed to create input data or get input pipe")
            throw SHIORIError.communicationError
        }
        
        if !isFrequentEvent {
            print("Writing request data to SHIORI process")
        }
        input.write(inputData)
        if !isFrequentEvent {
            print("Request data written successfully")
        }
        
        guard let output = outputPipe?.fileHandleForReading else {
            print("ERROR: Failed to get output pipe for reading")
            throw SHIORIError.communicationError
        }
        
        if !isFrequentEvent {
            print("Reading response from SHIORI process...")
        }
        var responseData = Data()
        let timeout = 5.0
        let startTime = Date()
        let endMarker = "\r\n\r\n".data(using: .utf8)!
        let altEndMarker = "\n\n".data(using: .utf8)! // Unix形式の終了マーカー
        
        while responseData.isEmpty || (!containsData(responseData, endMarker) && !containsData(responseData, altEndMarker)) {
            let elapsed = Date().timeIntervalSince(startTime)
            if elapsed > timeout {
                print("ERROR: Timeout waiting for SHIORI response (elapsed: \(elapsed)s)")
                print("Partial response received (\(responseData.count) bytes):")
                if let partial = String(data: responseData, encoding: .utf8) {
                    print("'\(partial.replacingOccurrences(of: "\r\n", with: "\\r\\n"))'")
                }
                throw SHIORIError.communicationError
            }
            
            let chunk = output.availableData
            if !chunk.isEmpty {
                responseData.append(chunk)
                // 詳細ログは非頻繁イベントのみ
                if !isFrequentEvent {
                    print("Received chunk: \(chunk.count) bytes (total: \(responseData.count) bytes)")
                }
            } else {
                Thread.sleep(forTimeInterval: 0.1)
            }
        }
        
        let response = String(data: responseData, encoding: .utf8) ?? ""
        let parsedResult = parseResponse(response)
        
        // 結果ログは非頻繁イベントのみ、または重要なイベント（OnBoot）のみ
        if !isFrequentEvent || event == "OnBoot" {
            print("Complete response received for \(event): '\(parsedResult)'")
        }
        
        return parsedResult
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

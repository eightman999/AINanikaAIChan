import Foundation

class SHIORIClient {
    private let ghostPath: String
    private let shioriPath: String
    private var process: Process?
    private var inputPipe: Pipe?
    private var outputPipe: Pipe?
    
    enum SHIORIError: Error {
        case processNotStarted
        case communicationError
        case invalidResponse
        case processTerminated
    }
    
    init(ghostPath: String, shioriPath: String) {
        self.ghostPath = ghostPath
        self.shioriPath = shioriPath
    }
    
    func start() throws {
        if shioriPath.hasSuffix(".dll") || shioriPath.hasSuffix(".exe") {
            if shioriPath.contains("SHIOLINK") {
                try startTestSHIORIScript()
            } else {
                throw SHIORIError.processNotStarted
            }
        } else if shioriPath.hasSuffix(".csx") {
            try startDotNetScript()
        } else {
            throw SHIORIError.processNotStarted
        }
    }
    
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
    
    func stop() {
        process?.terminate()
        process?.waitUntilExit()
        process = nil
        inputPipe = nil
        outputPipe = nil
    }
    
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
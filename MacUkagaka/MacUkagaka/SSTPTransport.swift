import Foundation

/// Errors that can occur while handling SSTP messages.
enum SSTPError: Error {
    case protocolViolation
    case badRequest
}

/// Utility to construct a compliant SSTP request.
func makeRequest(method: String, headers: [String: String], body: Data? = nil) -> String {
    var headers = headers
    if headers["Charset"] == nil {
        headers["Charset"] = "UTF-8"
    }
    if headers["Sender"] == nil {
        headers["Sender"] = "MacUkagaka"
    }
    if let body = body {
        headers["Content-Length"] = headers["Content-Length"] ?? String(body.count)
    } else {
        headers["Content-Length"] = headers["Content-Length"] ?? "0"
    }

    var lines: [String] = ["\(method) SSTP/1.5"]
    for (key, value) in headers {
        lines.append("\(key): \(value)")
    }
    lines.append("")
    if let body = body, let text = String(data: body, encoding: .utf8) {
        lines.append(text)
    }
    lines.append("")
    return lines.joined(separator: "\r\n")
}

/// Parse SSTP result string and return status code and body.
func parseResponse(_ response: String) throws -> (status: Int, body: String) {
    let lines = response.split(separator: "\r\n", omittingEmptySubsequences: false)
    guard let first = lines.first else { throw SSTPError.protocolViolation }
    let parts = first.split(separator: " ")
    guard parts.count >= 2, parts[0].hasPrefix("SSTP/1") else { throw SSTPError.protocolViolation }
    let status = Int(parts[1]) ?? 0
    let bodyLines = lines.dropFirst()
    return (status, bodyLines.joined(separator: "\r\n"))
}

/// Abstraction for sending SSTP requests via IPC.
protocol SSTPTransport {
    /// Sends a raw SSTP request string and returns the response.
    func send(request: String, receiveTimeout: TimeInterval) async throws -> String
}

/// Transport implementation using CFMessagePort.
class CFMessagePortTransport: NSObject, SSTPTransport {
    private let portName: String
    private let semaphore = DispatchSemaphore(value: 1)

    init(portName: String) {
        self.portName = portName
    }

    private func mapStatus(_ code: Int32) -> Int {
        switch code {
        case kCFMessagePortSendTimeout, kCFMessagePortReceiveTimeout:
            return 408
        case kCFMessagePortIsInvalid:
            return 503
        case kCFMessagePortSuccess:
            return 200
        default:
            return 500
        }
    }

    func send(request: String, receiveTimeout: TimeInterval = 2.0) async throws -> String {
        semaphore.wait()
        defer { semaphore.signal() }

        guard let remote = CFMessagePortCreateRemote(nil, portName as CFString) else {
            throw NSError(domain: "SSTPTransport", code: -1, userInfo: [NSLocalizedDescriptionKey: "remote port not found"])
        }

        let data = request.data(using: .utf8)! as CFData
        var returnData: Unmanaged<CFData>?
        let result = CFMessagePortSendRequest(
            remote,
            0,
            data,
            2.0,
            receiveTimeout,
            CFRunLoopMode.defaultMode.rawValue,
            &returnData)

        CFMessagePortInvalidate(remote)
        CFRelease(remote)

        if result != kCFMessagePortSuccess {
            let status = mapStatus(result)
            throw NSError(domain: "SSTPTransport", code: Int(status), userInfo: nil)
        }

        if let cfData = returnData?.takeRetainedValue() {
            let text = String(data: cfData as Data, encoding: .utf8) ?? ""
            _ = try? parseResponse(text) // Validate format
            return text
        }
        return ""
    }
}

/// Basic listener that publishes a local CFMessagePort.
class CFMessagePortListener {
  private var localPort: CFMessagePort?
  private var runLoopSource: CFRunLoopSource?

  init(portName: String, handler: @escaping (String) -> String) {
    let unmanagedSelf = Unmanaged.passRetained(self)
    var context = CFMessagePortContext(
        version: 0,
        info: unmanagedSelf.toOpaque(),
        retain: { pointer in
            let obj = Unmanaged<AnyObject>.fromOpaque(pointer)
            _ = obj.retain()
            return pointer
        },
        release: { pointer in
            Unmanaged<AnyObject>.fromOpaque(pointer).release()
        },
        copyDescription: nil)

    let callout: CFMessagePortCallBack = { _, _, data, info in
        guard let info = info else { return nil }
        let listener = Unmanaged<CFMessagePortListener>.fromOpaque(info).takeUnretainedValue()
        guard let data = data as Data?, let message = String(data: data, encoding: .utf8) else {
            return nil
        }
        let response = handler(message)
        return response.data(using: .utf8)! as CFData
    }
    localPort = CFMessagePortCreateLocal(nil, portName as CFString, callout, &context, nil)
    if let port = localPort {
        runLoopSource = CFMessagePortCreateRunLoopSource(nil, port, 0)
        if let source = runLoopSource {
            CFRunLoopAddSource(CFRunLoopGetMain(), source, .defaultMode)
        }
    }
  }

  deinit {
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .defaultMode)
        }
        if let port = localPort {
            CFMessagePortInvalidate(port)
            CFRelease(port)
        }
  }
}

import Foundation

/// Abstraction for sending SSTP requests via IPC.
protocol SSTPTransport {
  /// Sends a raw SSTP request string and returns the response.
  func send(request: String) async throws -> String
}

/// Transport implementation using CFMessagePort.
class CFMessagePortTransport: NSObject, SSTPTransport {
  private let portName: String

  init(portName: String) {
    self.portName = portName
  }

  func send(request: String) async throws -> String {
    guard let remote = CFMessagePortCreateRemote(nil, portName as CFString) else {
      throw NSError(
        domain: "SSTPTransport", code: -1,
        userInfo: [NSLocalizedDescriptionKey: "remote port not found"])
    }

    let data = request.data(using: .utf8)! as CFData
    var returnData: Unmanaged<CFData>?
    let result = CFMessagePortSendRequest(
      remote,
      0,
      data,
      2.0,
      2.0,
      CFRunLoopMode.defaultMode.rawValue,
      &returnData)
    if result != kCFMessagePortSuccess {
      throw NSError(domain: "SSTPTransport", code: Int(result), userInfo: nil)
    }

    if let cfData = returnData?.takeRetainedValue() {
      return String(data: cfData as Data, encoding: .utf8) ?? ""
    }
    return ""
  }
}

/// Basic listener that publishes a local CFMessagePort.
class CFMessagePortListener {
  private var localPort: CFMessagePort?
  private var runLoopSource: CFRunLoopSource?

  init(portName: String, handler: @escaping (String) -> String) {
    var context = CFMessagePortContext(
      version: 0,
      info: Unmanaged.passUnretained(self).toOpaque(),
      retain: nil,
      release: nil,
      copyDescription: nil)
    let callout: CFMessagePortCallBack = { _, _, data, _ in
      let listener = Unmanaged<CFMessagePortListener>.fromOpaque(context.info!)
        .takeUnretainedValue()
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
        CFRunLoopAddSource(CFRunLoopGetMain(), source, CFRunLoopMode.defaultMode)
      }
    }
  }

  deinit {
    if let source = runLoopSource {
      CFRunLoopRemoveSource(CFRunLoopGetMain(), source, CFRunLoopMode.defaultMode)
    }
    if let port = localPort {
      CFMessagePortInvalidate(port)
    }
  }
}

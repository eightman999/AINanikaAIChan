import Foundation

class SSTPService: NSObject, SSTPServiceProtocol {
  func send(request: String, withReply reply: @escaping (String) -> Void) {
    // This is a placeholder implementation that simply echoes back the request.
    reply("Received: \(request)")
  }
}

let delegate = SSTPService()
let listener = NSXPCListener.service()
listener.delegate = delegate
listener.resume()

import Foundation

@objc public protocol SSTPServiceProtocol {
  func send(request: String, withReply reply: @escaping (String) -> Void)
}

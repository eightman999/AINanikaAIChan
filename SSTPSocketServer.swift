import Foundation
import NIO
import NIOExtras
import NIOSSL

/// SSTP request methods defined by the protocol.
enum SSTPMethod: String {
    case notify = "NOTIFY"
    case send = "SEND"
    case communicate = "COMMUNICATE"
    case execute = "EXECUTE"
    case give = "GIVE"
}

/// Error cases for SSTP parsing.
enum SSTPParserError: Error {
    case invalidStartLine
    case missingRequiredHeader
    case unsupportedMethod
}

/// Represents SSTP headers with basic validation.
struct SSTPHeader {
    let fields: [String: String]

    init(lines: [String]) throws {
        var map: [String: String] = [:]
        for line in lines {
            let parts = line.split(separator: ":", maxSplits: 1, omittingEmptySubsequences: false)
            guard parts.count == 2 else { continue }
            map[String(parts[0]).trimmingCharacters(in: .whitespaces)] =
                String(parts[1]).trimmingCharacters(in: .whitespaces)
        }
        guard map["Charset"] != nil, map["Sender"] != nil else {
            throw SSTPParserError.missingRequiredHeader
        }
        self.fields = map
    }

    subscript(key: String) -> String? { fields[key] }
}

/// SSTP request structure produced by `SSTPRequestDecoder`.
struct SSTPRequest {
    let method: SSTPMethod
    let version: String
    let headers: SSTPHeader
    let body: String?
}

/// Decoder that splits inbound bytes into `SSTPRequest` messages.
final class SSTPRequestDecoder: ByteToMessageDecoder {
    typealias InboundOut = SSTPRequest

    private var buffer = ""
    private var expectedBody: Int?
    private var storedHead: (method: SSTPMethod, version: String, headers: [String])?

    func decode(context: ChannelHandlerContext, buffer: inout ByteBuffer) throws -> DecodingState {
        if let part = buffer.readString(length: buffer.readableBytes) {
            self.buffer += part
        }

        while true {
            if let length = expectedBody {
                if length == -1 {
                    guard let range = self.buffer.range(of: "\r\n\r\n") else { return .needMoreData }
                    let body = String(self.buffer[..<range.lowerBound])
                    self.buffer = String(self.buffer[range.upperBound...])
                    try emitRequest(context: context, body: body)
                    continue
                } else if self.buffer.utf8.count >= length {
                    let bodyEnd = self.buffer.index(self.buffer.startIndex, offsetBy: length)
                    let body = String(self.buffer[..<bodyEnd])
                    self.buffer = String(self.buffer[bodyEnd...])
                    try emitRequest(context: context, body: body)
                    continue
                } else {
                    return .needMoreData
                }
            }

            guard let range = self.buffer.range(of: "\r\n\r\n") else { return .needMoreData }
            let headPart = String(self.buffer[..<range.lowerBound])
            self.buffer = String(self.buffer[range.upperBound...])
            let lines = headPart.split(separator: "\r\n", omittingEmptySubsequences: false).map(String.init)
            guard let first = lines.first else { throw SSTPParserError.invalidStartLine }
            let comps = first.split(separator: " ")
            guard comps.count >= 2, let method = SSTPMethod(rawValue: String(comps[0])) else {
                throw SSTPParserError.invalidStartLine
            }
            let version = String(comps[1])
            let headerLines = Array(lines.dropFirst())
            let headersMap = headerLines.reduce(into: [String: String]()) { result, line in
                let p = line.split(separator: ":", maxSplits: 1, omittingEmptySubsequences: false)
                guard p.count == 2 else { return }
                result[String(p[0]).trimmingCharacters(in: .whitespaces)] =
                    String(p[1]).trimmingCharacters(in: .whitespaces)
            }
            if let lengthStr = headersMap["Content-Length"], let len = Int(lengthStr) {
                self.expectedBody = len
                self.storedHead = (method, version, headerLines)
                continue
            } else if method == .execute || method == .give {
                self.expectedBody = -1
                self.storedHead = (method, version, headerLines)
                continue
            } else {
                try emitHeadOnlyRequest(context: context, method: method, version: version, headers: headerLines)
                continue
            }
        }
    }

    private func emitHeadOnlyRequest(context: ChannelHandlerContext, method: SSTPMethod, version: String, headers: [String]) throws {
        let header = try SSTPHeader(lines: headers)
        let req = SSTPRequest(method: method, version: version, headers: header, body: nil)
        context.fireChannelRead(self.wrapInboundOut(req))
        self.storedHead = nil
        self.expectedBody = nil
    }

    private func emitRequest(context: ChannelHandlerContext, body: String) throws {
        guard let head = self.storedHead else { return }
        let header = try SSTPHeader(lines: head.headers)
        let req = SSTPRequest(method: head.method, version: head.version, headers: header, body: body)
        context.fireChannelRead(self.wrapInboundOut(req))
        self.storedHead = nil
        self.expectedBody = nil
    }
}

/// Simple encoder that forwards a response string.
final class SSTPResponseEncoder: MessageToByteEncoder {
    typealias OutboundIn = String

    func encode(data: String, out: inout ByteBuffer) throws {
        out.writeString(data)
    }
}

/// Business logic handler that responds according to SSTP method.
final class SSTPBusinessLogicHandler: ChannelInboundHandler {
    typealias InboundIn = SSTPRequest
    typealias OutboundOut = String

    func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        let req = unwrapInboundIn(data)
        let status: String
        switch req.method {
        case .notify:
            status = "204 No Content"
        default:
            status = "200 OK"
        }
        var response = "SSTP/1.1 \(status)\r\n"
        response += "Charset: UTF-8\r\n"
        response += "Sender: SSTPSocketServer\r\n"
        response += "\r\n"
        context.writeAndFlush(wrapOutboundOut(response)).whenComplete { _ in
            context.close(promise: nil)
        }
    }
}

/// Non-blocking SSTP server that listens on ports 9801 and 9821.
final class SSTPSocketServer {
    private let group: EventLoopGroup
    private var channels: [Channel] = []
    private let host: String

    init(group: EventLoopGroup? = nil, host: String = "127.0.0.1") {
        self.group = group ?? MultiThreadedEventLoopGroup(numberOfThreads: System.coreCount)
        self.host = host
    }

    func start() throws {
        let plain = try makeBootstrap(tls: false)
            .bind(host: host, port: 9801).wait()
        channels.append(plain)

        let tls = try makeBootstrap(tls: true)
            .bind(host: host, port: 9821).wait()
        channels.append(tls)
    }

    func stop() throws {
        try EventLoopFuture.andAllComplete(channels.map { $0.close() }, on: group.next()).wait()
        try group.syncShutdownGracefully()
    }

    private func makeBootstrap(tls: Bool) throws -> ServerBootstrap {
        let bootstrap = ServerBootstrap(group: group)
            .serverChannelOption(ChannelOptions.backlog, value: 256)
            .childChannelOption(ChannelOptions.socketOption(.so_reuseaddr), value: 1)
            .childChannelInitializer { (channel: Channel) -> EventLoopFuture<Void> in
                // ChannelHandler は Existential なので any を付ける
                var handlers: [any ChannelHandler] = [
                    LineBasedFrameDecoder(),
                    SSTPRequestDecoder(),
                    SSTPResponseEncoder(),
                    IdleStateHandler(readTimeout: .seconds(10)),
                    SSTPBusinessLogicHandler()
                ]

                if tls {
                    let configuration = TLSConfiguration.makeServerConfiguration(
                        certificateChain: [],
                        privateKey: .privateKey(
                            NIOSSLPrivateKeySource.privateKey(.generateRSA(bits: 2048))
                        )
                    )

                    do {
                        let context = try NIOSSLContext(configuration: configuration)
                        let sslHandler = NIOSSLServerHandler(context: context)
                        handlers.insert(sslHandler, at: 0)
                    } catch {
                        // makeFailedFuture の型が推論できないので Void を明示
                        return channel.eventLoop.makeFailedFuture(error)
                            as EventLoopFuture<Void>
                    }
                }

                return channel.pipeline.addHandlers(handlers)
            }

        return bootstrap
    }

}

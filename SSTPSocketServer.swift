import Foundation
import NIO

/// Non-blocking server that accepts SSTP connections and forwards complete
/// request strings upstream using `SSTPRequestParser`.
final class SSTPSocketServer {
    private let group: EventLoopGroup
    private var channels: [Channel] = []

    init(group: EventLoopGroup? = nil) {
        if let g = group {
            self.group = g
        } else {
            self.group = MultiThreadedEventLoopGroup(numberOfThreads: System.coreCount)
        }
    }

    /// Start listening on ports 9801 and 9821.
    func start() throws {
        let bootstrap = ServerBootstrap(group: group)
            .serverChannelOption(ChannelOptions.backlog, value: 256)
            .childChannelInitializer { channel in
                channel.pipeline.addHandler(ByteToMessageHandler(SSTPRequestParser()))
            }
            .childChannelOption(ChannelOptions.socketOption(.so_reuseaddr), value: 1)

        for port in [9801, 9821] {
            let channel = try bootstrap.bind(host: "0.0.0.0", port: port).wait()
            channels.append(channel)
            print("SSTPSocketServer listening on port \(port)")
        }
    }

    /// Close all server channels and shut down the event loop group.
    func stop() throws {
        try channels.map { $0.close() }.flatten().wait()
        try group.syncShutdownGracefully()
    }
}

/// Decoder that accumulates data until "\r\n\r\n" is received and then
/// forwards the complete request string.
final class SSTPRequestParser: ByteToMessageDecoder {
    typealias InboundOut = String

    private var buffer: String = ""

    func decode(context: ChannelHandlerContext, buffer: inout ByteBuffer) throws -> DecodingState {
        if let part = buffer.readString(length: buffer.readableBytes) {
            self.buffer += part
        }

        if let range = self.buffer.range(of: "\r\n\r\n") {
            let request = String(self.buffer[..<range.lowerBound])
            self.buffer = String(self.buffer[range.upperBound...])
            context.fireChannelRead(self.wrapInboundOut(request))
            return .continue
        }

        return .needMoreData
    }
}

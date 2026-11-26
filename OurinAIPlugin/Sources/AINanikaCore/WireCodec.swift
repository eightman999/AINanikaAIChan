//  © eightman 2005-2025
//  Furin-lab All Rights Reserved.
//  SHIORI/3.0 ワイヤ形式の解析・組立

import Foundation

/// SHIORIリクエストの解析結果
public struct ShioriRequest {
    public let method: String
    public let protocolVersion: String
    public let id: String
    /// Reference0..N (キーは "Reference0" 等のまま保持し欠番も維持)
    public let references: [String: String]
    public let charset: String
    public let sender: String

    public func reference(_ index: Int) -> String? {
        references["Reference\(index)"]
    }
}

public enum WireCodec {
    /// SHIORI/3.0 リクエストテキスト(CRLF区切り+空行終端)を解析する。
    /// LFのみの入力も受理する。
    public static func parse(_ text: String) -> ShioriRequest? {
        var lines = text.components(separatedBy: "\r\n")
        if lines.count == 1, !text.contains("\r\n") {
            lines = text.components(separatedBy: "\n")
        }
        guard let first = lines.first else { return nil }
        let parts = first.split(separator: " ", omittingEmptySubsequences: true).map(String.init)
        // "GET SHIORI/3.0" (2トークン) を受理する
        guard parts.count >= 2, parts[1].uppercased().hasPrefix("SHIORI/") else { return nil }

        var id = ""
        var refs: [String: String] = [:]
        var charset = "UTF-8"
        var sender = ""
        for line in lines.dropFirst() {
            if line.isEmpty { break }
            guard let colon = line.firstIndex(of: ":") else { continue }
            let key = String(line[..<colon]).trimmingCharacters(in: .whitespaces)
            let value = String(line[line.index(after: colon)...]).trimmingCharacters(in: .whitespaces)
            switch key {
            case "ID": id = value
            case "Charset": charset = value
            case "Sender": sender = value
            default:
                if key.hasPrefix("Reference") {
                    refs[key] = value
                }
            }
        }
        guard !id.isEmpty else { return nil }
        return ShioriRequest(
            method: parts[0].uppercased(),
            protocolVersion: parts[1],
            id: id,
            references: refs,
            charset: charset,
            sender: sender
        )
    }

    /// SHIORI/3.0 200 OK 応答を組立る(Value付き)
    public static func okResponse(value: String, charset: String = "UTF-8") -> String {
        // SakuraScript内の改行(\n)はそのまま残し、ヘッダ境界と混同しないよう
        // Value行にはCR単独・LFを含めない。SakuraScriptでは \n エスケープを使う。
        let sanitized = value
            .replacingOccurrences(of: "\r\n", with: "\\n")
            .replacingOccurrences(of: "\r", with: "\\n")
            .replacingOccurrences(of: "\n", with: "\\n")
        return "SHIORI/3.0 200 OK\r\nCharset: \(charset)\r\nValue: \(sanitized)\r\n\r\n"
    }

    /// SHIORI/3.0 204 No Content 応答(喋らない=ネイティブ挙動に任せる)
    public static func noContentResponse() -> String {
        "SHIORI/3.0 204 No Content\r\n\r\n"
    }

    /// SHIORI/3.0 400 Bad Request 応答
    public static func badRequestResponse() -> String {
        "SHIORI/3.0 400 Bad Request\r\n\r\n"
    }
}

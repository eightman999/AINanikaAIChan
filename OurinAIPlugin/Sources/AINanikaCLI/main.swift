//  © eightman 2005-2025
//  Furin-lab All Rights Reserved.
//  単体検証CLI: stdinからSHIORIリクエスト(空行終端)を読み、応答をstdoutへ書く
//
//  使い方:
//    ainanika-cli <loadDir>          # loadDirにはai_config.jsonを置く
//    printf 'GET SHIORI/3.0\r\nID: Version\r\n\r\n' | ainanika-cli .
//
import Foundation
import AINanikaShioriModule

setbuf(stdout, nil)

let arguments = CommandLine.arguments
guard arguments.count >= 2 else {
    FileHandle.standardError.write(Data("usage: ainanika-cli <loadDir>\n".utf8))
    exit(2)
}
let loadDir = URL(fileURLWithPath: arguments[1], isDirectory: true)

if !shioriLoad(path: loadDir.path) {
    FileHandle.standardError.write(Data("warning: shiori_load failed, continuing in stateless mode\n".utf8))
}

while let line = readLine(strippingNewline: false) {
    var lines = [line]
    // 空行まで読み続ける(SHIORIリクエストの終端)
    var done = line.trimmingCharacters(in: .newlines).isEmpty
    while !done, let next = readLine(strippingNewline: false) {
        lines.append(next)
        done = next.trimmingCharacters(in: .newlines).isEmpty
    }
    if lines.allSatisfy({ $0.trimmingCharacters(in: .newlines).isEmpty }) { break }

    // readLine(strippingNewline:false)は行末の\rを残す。まず正規化してからCRLFへ再構成する
    let normalized = lines.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
    let requestText = normalized.joined(separator: "\r\n") + "\r\n"
    let response = shioriRequest(text: requestText)
    print(response)
}

shioriUnload()

//  © eightman 2005-2025
//  Furin-lab All Rights Reserved.
//  macOSアプリを起動するエントリーポイント。

import Cocoa
import Foundation

/// プロセス用の NSApplication インスタンス。
let app = NSApplication.shared
/// ライフサイクルを管理するアプリデリゲート。
let delegate = AppDelegate()
app.delegate = delegate
app.run()
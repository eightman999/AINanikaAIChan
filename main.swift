//  © eightman 2005-2025
//  Furin-lab All Rights Reserved.
//  Entry point launching the macOS application.

import Cocoa
import Foundation

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
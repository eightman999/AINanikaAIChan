# MacUkagaka コード詳細ドキュメント

## 1. main.swift

**概要**: アプリケーションのエントリーポイント

```swift
import Cocoa
import Foundation

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
```

**解説**:
- `NSApplication.shared`: macOSアプリケーションの共有インスタンス
- `AppDelegate`: アプリケーションのライフサイクル管理を担当
- `app.run()`: アプリケーションのメインループを開始

## 2. AppDelegate.swift

**概要**: アプリケーションのライフサイクル管理とゴーストの初期化

### 主要プロパティ

```swift
var ghostManager: GhostManager?        // ゴースト管理オブジェクト
var characterWindow: CharacterWindowController?  // キャラクター表示ウィンドウ
```

### 主要メソッド

#### `applicationDidFinishLaunching(_:)`
```swift
func applicationDidFinishLaunching(_ notification: Notification) {
    setupApplication()  // アプリケーション設定
    loadGhost()         // ゴーストの読み込み
}
```

**処理内容**:
1. アプリケーションの基本設定を実行
2. ゴーストの検索と読み込み
3. キャラクターウィンドウの表示

#### `setupApplication()`
```swift
private func setupApplication() {
    NSApp.setActivationPolicy(.accessory)
}
```

**解説**:
- `.accessory`: Dockやメニューバーにアイコンを表示しない設定
- デスクトップマスコット用途に適した設定

#### `findGhostPath()`
```swift
private func findGhostPath() -> String? {
    let currentPath = FileManager.default.currentDirectoryPath
    let possiblePaths = [
        "\(currentPath)/ghost/master",
        "\(currentPath)/../ghost/master",
        "\(currentPath)/../../ghost/master"
    ]
    
    for path in possiblePaths {
        if FileManager.default.fileExists(atPath: path) {
            return path
        }
    }
    return nil
}
```

**解説**:
- 複数の候補パスからゴーストディレクトリを検索
- 相対パスを使用してフレキシブルなディレクトリ構成に対応

### デリゲートメソッド

#### `ghostManager(_:didReceiveScript:)`
```swift
func ghostManager(_ manager: GhostManager, didReceiveScript script: String) {
    DispatchQueue.main.async {
        self.characterWindow?.processScript(script)
    }
}
```

**解説**:
- ゴーストからのスクリプトを受信
- メインスレッドでUI更新を実行
- SakuraScriptの処理をCharacterWindowControllerに委譲

## 3. GhostManager.swift

**概要**: ゴーストの管理とSHIORIとの通信を統合

### データ構造

#### `GhostInfo`
```swift
struct GhostInfo {
    let name: String        // ゴースト名
    let sakuraName: String  // メインキャラクター名
    let keroName: String    // サブキャラクター名
    let shioriPath: String  // SHIORI実行ファイルパス
    let charset: String     // 文字エンコーディング
}
```

### 主要メソッド

#### `loadGhostInfo()`
```swift
private func loadGhostInfo() throws -> GhostInfo {
    let descriptPath = "\(ghostPath)/descript.txt"
    let content = try String(contentsOfFile: descriptPath, encoding: .utf8)
    
    // descript.txtの解析処理
    for line in content.components(separatedBy: .newlines) {
        let parts = line.components(separatedBy: ",")
        if parts.count >= 2 {
            let key = parts[0].trimmingCharacters(in: .whitespaces)
            let value = parts[1].trimmingCharacters(in: .whitespaces)
            
            switch key {
            case "name": name = value
            case "sakura.name": sakuraName = value
            case "shiori": shioriPath = value
            // ... 他のキーの処理
            }
        }
    }
}
```

**解説**:
- CSV形式のdescript.txtを解析
- 各設定値をGhostInfo構造体に格納
- エラーハンドリングでファイル読み込み失敗に対応

#### `start()`
```swift
func start() throws {
    guard let shiori = shioriClient else {
        throw GhostError.initializationFailed
    }
    
    try shiori.start()
    
    let bootScript = try shiori.request(event: "OnBoot", references: [
        "MacUkagaka", "1.0.0", "macOS"
    ])
    
    if !bootScript.isEmpty {
        delegate?.ghostManager(self, didReceiveScript: bootScript)
    }
    
    startRandomTalk()
}
```

**解説**:
1. SHIORIプロセスの起動
2. OnBootイベントの送信
3. 起動スクリプトの実行
4. 定期実行タイマーの開始

#### `handleMouseClick()`
```swift
func handleMouseClick(surfaceId: Int, x: Int, y: Int, button: Int) {
    guard let shiori = shioriClient else { return }
    
    do {
        let script = try shiori.request(event: "OnMouseClick", references: [
            String(surfaceId), String(x), String(y), String(button)
        ])
        
        if !script.isEmpty {
            delegate?.ghostManager(self, didReceiveScript: script)
        }
    } catch {
        delegate?.ghostManager(self, didEncounterError: error)
    }
}
```

**解説**:
- マウスクリック情報をSHIORIに送信
- 座標とボタン情報を文字列として送信
- エラーハンドリングでデリゲートに通知

## 4. SHIORIClient.swift

**概要**: SHIORIプロトコルの実装とプロセス管理

### プロセス管理

#### `startTestSHIORIScript()`
```swift
private func startTestSHIORIScript() throws {
    let scriptPath = "\(ghostPath)/test_shiori.py"
    
    process = Process()
    inputPipe = Pipe()
    outputPipe = Pipe()
    
    process?.executableURL = URL(fileURLWithPath: "/usr/bin/python3")
    process?.arguments = [scriptPath]
    process?.currentDirectoryURL = URL(fileURLWithPath: ghostPath)
    process?.standardInput = inputPipe
    process?.standardOutput = outputPipe
    
    try process?.run()
}
```

**解説**:
- Python3インタープリターでSHIORIスクリプトを実行
- 標準入出力でパイプを設定
- 作業ディレクトリをゴーストディレクトリに設定

### 通信処理

#### `request(event:references:)`
```swift
func request(event: String, references: [String]) throws -> String {
    var request = "GET SHIORI/3.0\r\n"
    request += "ID: \(event)\r\n"
    
    for (index, reference) in references.enumerated() {
        request += "Reference\(index): \(reference)\r\n"
    }
    request += "\r\n"
    
    // リクエスト送信
    let inputData = request.data(using: .utf8)!
    input.write(inputData)
    
    // レスポンス受信
    var responseData = Data()
    let endMarker = "\r\n\r\n".data(using: .utf8)!
    
    while !containsData(responseData, endMarker) {
        let chunk = output.availableData
        if !chunk.isEmpty {
            responseData.append(chunk)
        } else {
            Thread.sleep(forTimeInterval: 0.1)
        }
    }
    
    return parseResponse(String(data: responseData, encoding: .utf8) ?? "")
}
```

**解説**:
1. HTTP風のリクエストを構築
2. 標準入力でSHIORIプロセスに送信
3. 標準出力からレスポンスを受信
4. 終了マーカーまで読み込み続行

#### `parseResponse(_:)`
```swift
private func parseResponse(_ response: String) -> String {
    let lines = response.components(separatedBy: .newlines)
    var value = ""
    
    for line in lines {
        if line.hasPrefix("Value: ") {
            value = String(line.dropFirst(7))
        }
    }
    
    return value.trimmingCharacters(in: .whitespacesAndNewlines)
}
```

**解説**:
- HTTPレスポンス形式を解析
- "Value: "ヘッダーからSakuraScriptを抽出
- 前後の空白を除去して返却

## 5. SakuraScriptParser.swift

**概要**: SakuraScriptの字句解析・構文解析・アクション生成

### データ構造

#### `SakuraScriptToken`
```swift
struct SakuraScriptToken {
    enum TokenType {
        case text(String)           // 通常テキスト
        case scopeSwitch(Int)       // スコープ切り替え
        case surfaceChange(Int)     // Surface変更
        case lineBreak              // 改行
        case wait(Int)              // 待機
        case choice(String, String) // 選択肢
        case scriptEnd              // 終了
    }
    let type: TokenType
}
```

#### `SakuraScriptAction`
```swift
struct SakuraScriptAction {
    enum ActionType {
        case displayText(String, scope: Int)  // テキスト表示
        case changeSurface(Int, scope: Int)   // Surface変更
        case wait(Int)                        // 待機
        case showChoices([(String, String)])  // 選択肢表示
        case end                              // 終了
    }
    let type: ActionType
}
```

### 解析処理

#### `tokenize(_:)`
```swift
private func tokenize(_ script: String) -> [SakuraScriptToken] {
    var tokens: [SakuraScriptToken] = []
    var index = script.startIndex
    
    while index < script.endIndex {
        if script[index] == "\\" {
            // 制御コードの解析
            let (token, nextIndex) = parseControlCode(script, from: index)
            if let token = token {
                tokens.append(token)
            }
            index = nextIndex
        } else {
            // 通常テキストの解析
            let (text, nextIndex) = parseText(script, from: index)
            if !text.isEmpty {
                tokens.append(SakuraScriptToken(type: .text(text)))
            }
            index = nextIndex
        }
    }
    
    return tokens
}
```

**解説**:
1. 文字列を1文字ずつ解析
2. `\`文字で制御コードを判別
3. 通常テキストと制御コードを分離
4. トークンの配列を生成

#### `parseControlCode(_:from:)`
```swift
private func parseControlCode(_ script: String, from index: String.Index) -> (SakuraScriptToken?, String.Index) {
    let nextIndex = script.index(after: index)
    let controlChar = script[nextIndex]
    
    switch controlChar {
    case "h":
        return (SakuraScriptToken(type: .scopeSwitch(0)), script.index(after: nextIndex))
    case "u":
        return (SakuraScriptToken(type: .scopeSwitch(1)), script.index(after: nextIndex))
    case "s":
        let (surfaceId, endIndex) = parseNumericParameter(script, from: nextIndex)
        return (SakuraScriptToken(type: .surfaceChange(surfaceId)), endIndex)
    case "n":
        return (SakuraScriptToken(type: .lineBreak), script.index(after: nextIndex))
    case "e":
        return (SakuraScriptToken(type: .scriptEnd), script.index(after: nextIndex))
    default:
        return (nil, script.index(after: nextIndex))
    }
}
```

**解説**:
- 制御文字に応じた処理を実行
- パラメータ付きの制御コードは専用メソッドで解析
- 未知の制御コードは無視

### アクション生成

#### `generateActions(from:)`
```swift
private func generateActions(from tokens: [SakuraScriptToken]) -> [SakuraScriptAction] {
    var actions: [SakuraScriptAction] = []
    var currentText = ""
    var currentScope = 0
    
    for token in tokens {
        switch token.type {
        case .text(let text):
            currentText += text
        case .scopeSwitch(let scope):
            if !currentText.isEmpty {
                actions.append(SakuraScriptAction(type: .displayText(currentText, scope: currentScope)))
                currentText = ""
            }
            currentScope = scope
        case .surfaceChange(let surface):
            actions.append(SakuraScriptAction(type: .changeSurface(surface, scope: currentScope)))
        case .scriptEnd:
            if !currentText.isEmpty {
                actions.append(SakuraScriptAction(type: .displayText(currentText, scope: currentScope)))
            }
            actions.append(SakuraScriptAction(type: .end))
        }
    }
    
    return actions
}
```

**解説**:
1. トークンをアクションに変換
2. テキストの蓄積と出力タイミングの管理
3. スコープ情報の保持
4. 実行可能なアクション列を生成

## 6. CharacterWindowController.swift

**概要**: 透明ウィンドウでのキャラクター表示とUI管理

### ウィンドウ設定

#### `setupWindow()`
```swift
private func setupWindow() {
    guard let window = window else { return }
    
    window.backgroundColor = NSColor.clear
    window.isOpaque = false
    window.level = .floating
    window.isMovableByWindowBackground = true
    window.acceptsMouseMovedEvents = true
    
    window.contentView?.wantsLayer = true
    window.contentView?.layer?.backgroundColor = NSColor.clear.cgColor
}
```

**解説**:
- `backgroundColor = .clear`: 透明背景
- `isOpaque = false`: 不透明度を無効化
- `level = .floating`: 最前面表示
- `isMovableByWindowBackground = true`: ドラッグ移動可能
- `wantsLayer = true`: Core Animationレイヤーを使用

### 画像表示

#### `loadSurface(_:)`
```swift
private func loadSurface(_ surfaceId: Int) {
    let shellPath = findShellPath()
    let surfaceFile = String(format: "%03d_000.png", surfaceId)
    let imagePath = "\(shellPath)/\(surfaceFile)"
    
    guard let image = NSImage(contentsOfFile: imagePath) else {
        // フォールバック処理
        let fallbackPath = "\(shellPath)/surface\(surfaceId).png"
        guard let fallbackImage = NSImage(contentsOfFile: fallbackPath) else {
            return
        }
        characterImageView.image = fallbackImage
        return
    }
    
    characterImageView.image = image
    currentSurface = surfaceId
    
    DispatchQueue.main.async {
        self.adjustWindowSize(for: image)
    }
}
```

**解説**:
1. Surface IDから画像ファイル名を生成
2. 画像の読み込みとフォールバック処理
3. NSImageViewに画像を設定
4. ウィンドウサイズの自動調整

### スクリプト実行

#### `processScript(_:)`
```swift
func processScript(_ script: String) {
    let actions = scriptParser.parse(script)
    actionQueue.append(contentsOf: actions)
    
    if !isProcessingScript {
        processNextAction()
    }
}
```

#### `processNextAction()`
```swift
private func processNextAction() {
    guard !actionQueue.isEmpty else {
        isProcessingScript = false
        return
    }
    
    isProcessingScript = true
    let action = actionQueue.removeFirst()
    
    switch action.type {
    case .displayText(let text, let scope):
        showBalloon(text, for: scope)
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            self.processNextAction()
        }
    case .changeSurface(let surface, _):
        loadSurface(surface)
        processNextAction()
    case .wait(let milliseconds):
        DispatchQueue.main.asyncAfter(deadline: .now() + Double(milliseconds) / 1000.0) {
            self.processNextAction()
        }
    case .end:
        hideBalloon()
        processNextAction()
    }
}
```

**解説**:
1. アクションキューによる順次実行
2. 非同期処理でウェイト時間を管理
3. 各アクションタイプに応じた処理分岐
4. 再帰的な次アクション実行

### バルーン表示

#### `showBalloon(_:for:)`
```swift
private func showBalloon(_ text: String, for scope: Int) {
    hideBalloon()
    
    let balloonFrame = NSRect(
        x: window.frame.origin.x + window.frame.size.width + 10,
        y: window.frame.origin.y + window.frame.size.height - 100,
        width: 300,
        height: 100
    )
    
    balloonWindow = NSWindow(
        contentRect: balloonFrame,
        styleMask: [.borderless],
        backing: .buffered,
        defer: false
    )
    
    balloonWindow?.backgroundColor = NSColor.white
    balloonWindow?.level = .floating
    balloonWindow?.hasShadow = true
    
    // テキストフィールドの設定
    balloonTextField = NSTextField(frame: NSRect(x: 10, y: 10, width: 280, height: 80))
    balloonTextField?.stringValue = text
    balloonTextField?.isEditable = false
    balloonTextField?.backgroundColor = NSColor.clear
    balloonTextField?.isBordered = false
    
    balloonWindow?.contentView?.addSubview(balloonTextField!)
    balloonWindow?.orderFrontRegardless()
    
    // 自動消去タイマー
    DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
        self.hideBalloon()
    }
}
```

**解説**:
1. 既存のバルーンを削除
2. キャラクター位置を基準にバルーン位置を計算
3. 独立したNSWindowでバルーンを表示
4. 5秒後の自動消去タイマーを設定

## 7. test_shiori.py

**概要**: テスト用のSHIORIスクリプト（Python実装）

```python
def main():
    while True:
        try:
            request = ""
            while True:
                line = sys.stdin.readline()
                if not line:
                    break
                request += line
                if line.strip() == "":
                    break
            
            lines = request.strip().split('\n')
            event_id = ""
            
            for line in lines:
                if line.startswith("ID: "):
                    event_id = line[4:]
                    break
            
            response = ""
            if event_id == "OnBoot":
                response = "\\h\\s[0]こんにちは！MacUkagakaです。\\e"
            elif event_id == "OnMouseClick":
                response = "\\h\\s[1]クリックありがとう！\\e"
            elif event_id == "OnSecondChange":
                response = "\\h\\s[0]元気にしています。\\e"
            elif event_id == "OnClose":
                response = "\\h\\s[0]さようなら！\\e"
            
            shiori_response = f"SHIORI/3.0 200 OK\r\n"
            shiori_response += f"Content-Type: text/plain\r\n"
            shiori_response += f"Value: {response}\r\n"
            shiori_response += f"\r\n"
            
            sys.stdout.write(shiori_response)
            sys.stdout.flush()
            
        except Exception as e:
            break
```

**解説**:
1. 標準入力からリクエストを読み込み
2. イベントIDを解析
3. イベントに応じたSakuraScriptを生成
4. SHIORI/3.0形式でレスポンスを返却
5. 標準出力をフラッシュして即座に送信

## 8. エラーハンドリング

### GhostError列挙型
```swift
enum GhostError: Error {
    case descriptNotFound    // descript.txtが見つからない
    case shioriNotFound      // SHIORIファイルが見つからない
    case invalidCharset      // 不正な文字コード
    case initializationFailed // 初期化失敗
}
```

### SHIORIError列挙型
```swift
enum SHIORIError: Error {
    case processNotStarted    // プロセス起動失敗
    case communicationError   // 通信エラー
    case invalidResponse      // 不正なレスポンス
    case processTerminated    // プロセス終了
}
```

### エラーハンドリングパターン
```swift
do {
    try ghostManager?.start()
} catch {
    showErrorAndExit("ゴーストの初期化に失敗しました: \(error)")
}
```

**解説**:
- `do-catch`文による例外処理
- ユーザーフレンドリーなエラーメッセージ
- 致命的エラー時のアプリケーション終了

このドキュメントは、MacUkagakaプロジェクトの各コンポーネントの詳細な実装内容を説明しています。各メソッドの役割、データフロー、エラーハンドリングを理解することで、プロジェクトの拡張や保守が容易になります。
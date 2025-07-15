# MacUkagaka 技術仕様書

## 1. アーキテクチャ概要

MacUkagakaは、Model-View-Controller（MVC）パターンを基本とした、macOS向けSwiftアプリケーションです。

```
┌─────────────────────────────────────────────────────────────┐
│                    MacUkagaka                               │
├─────────────────────────────────────────────────────────────┤
│  AppDelegate                                                │
│  ├─ アプリケーションライフサイクル管理                       │
│  ├─ ゴーストパス検索                                         │
│  └─ エラーハンドリング                                       │
├─────────────────────────────────────────────────────────────┤
│  GhostManager (Model)                                       │
│  ├─ ゴースト情報管理                                         │
│  ├─ SHIORI通信制御                                          │
│  └─ イベント配信                                             │
├─────────────────────────────────────────────────────────────┤
│  SHIORIClient                                              │
│  ├─ プロセス管理                                             │
│  ├─ 標準入出力通信                                           │
│  └─ プロトコル処理                                           │
├─────────────────────────────────────────────────────────────┤
│  SakuraScriptParser                                        │
│  ├─ 字句解析                                                 │
│  ├─ 構文解析                                                 │
│  └─ アクション生成                                           │
├─────────────────────────────────────────────────────────────┤
│  CharacterWindowController (View + Controller)             │
│  ├─ 透明ウィンドウ管理                                       │
│  ├─ 画像表示制御                                             │
│  ├─ バルーン表示                                             │
│  └─ マウスイベント処理                                       │
└─────────────────────────────────────────────────────────────┘
```

## 2. 主要コンポーネント詳細

### 2.1 AppDelegate

**責務**: アプリケーションの初期化、終了処理、グローバル設定管理

**主要メソッド**:
- `applicationDidFinishLaunching(_:)`: 起動時の初期化
- `applicationWillTerminate(_:)`: 終了時のクリーンアップ
- `findGhostPath()`: ゴーストディレクトリの検索

**設定項目**:
- `NSApp.setActivationPolicy(.accessory)`: メニューバーに表示しない
- `applicationShouldTerminateAfterLastWindowClosed`: false（ウィンドウが閉じてもアプリは終了しない）

### 2.2 GhostManager

**責務**: ゴースト全般の管理とSHIORIとの統合

**主要プロパティ**:
```swift
struct GhostInfo {
    let name: String        // ゴースト名
    let sakuraName: String  // メインキャラクター名
    let keroName: String    // サブキャラクター名
    let shioriPath: String  // SHIORI実行ファイルパス
    let charset: String     // 文字コード
}
```

**主要メソッド**:
- `loadGhostInfo()`: descript.txtの解析
- `start()`: SHIORI起動とOnBootイベント送信
- `handleMouseClick()`: マウスクリックイベントの処理
- `handleSecondChange()`: 定期実行イベントの処理

**デリゲートパターン**:
```swift
protocol GhostManagerDelegate: AnyObject {
    func ghostManager(_ manager: GhostManager, didReceiveScript script: String)
    func ghostManager(_ manager: GhostManager, didEncounterError error: Error)
}
```

### 2.3 SHIORIClient

**責務**: SHIORIプロトコルの実装とプロセス管理

**プロセス種類**:
- Python Script: `/usr/bin/python3`
- C# Script: `/usr/local/share/dotnet/dotnet`
- 実行ファイル: 直接実行

**通信フォーマット**:
```
リクエスト:
GET SHIORI/3.0\r\n
ID: OnBoot\r\n
Reference0: MacUkagaka\r\n
Reference1: 1.0.0\r\n
\r\n

レスポンス:
SHIORI/3.0 200 OK\r\n
Content-Type: text/plain\r\n
Value: \h\s[0]こんにちは！\e\r\n
\r\n
```

**エラーハンドリング**:
```swift
enum SHIORIError: Error {
    case processNotStarted
    case communicationError
    case invalidResponse
    case processTerminated
}
```

### 2.4 SakuraScriptParser

**責務**: SakuraScriptの解析とアクション生成

**トークン種類**:
```swift
enum TokenType {
    case text(String)           // 通常テキスト
    case scopeSwitch(Int)       // スコープ切り替え (\h, \u)
    case surfaceChange(Int)     // Surface変更 (\s[n])
    case lineBreak              // 改行 (\n)
    case wait(Int)              // 待機 (\_w[n])
    case choice(String, String) // 選択肢 (\q[text,id])
    case scriptEnd              // 終了 (\e)
}
```

**アクション種類**:
```swift
enum ActionType {
    case displayText(String, scope: Int)  // テキスト表示
    case changeSurface(Int, scope: Int)   // Surface変更
    case wait(Int)                        // 待機
    case showChoices([(String, String)])  // 選択肢表示
    case end                              // 終了
}
```

**解析フロー**:
1. 字句解析（Tokenization）
2. 構文解析（Parsing）
3. アクション生成（Action Generation）

### 2.5 CharacterWindowController

**責務**: UI表示とユーザーインタラクション管理

**ウィンドウ設定**:
```swift
let window = NSWindow(
    contentRect: NSRect(x: 100, y: 100, width: 200, height: 300),
    styleMask: [.borderless],
    backing: .buffered,
    defer: false
)
window.backgroundColor = NSColor.clear
window.isOpaque = false
window.level = .floating
window.isMovableByWindowBackground = true
```

**画像表示**:
- PNG画像の透過表示
- Surface切り替え対応
- 画像サイズによる自動ウィンドウ調整

**バルーン表示**:
- 独立したNSWindow
- 自動消去タイマー（5秒）
- 選択肢UI

**マウスイベント処理**:
```swift
override func mouseDown(with event: NSEvent) {
    let locationInWindow = event.locationInWindow
    let locationInView = characterImageView.convert(locationInWindow, from: nil)
    
    ghostManager.handleMouseClick(
        surfaceId: currentSurface,
        x: Int(locationInView.x),
        y: Int(locationInView.y),
        button: event.buttonNumber
    )
}
```

## 3. ファイル構造

```
プロジェクト/
├── ghost/
│   └── master/
│       ├── descript.txt          # ゴースト設定
│       ├── test_shiori.py        # テスト用SHIORI
│       └── (その他SHIORIファイル)
├── shell/
│   └── master/
│       ├── descript.txt          # シェル設定
│       ├── surfaces.txt          # Surface定義
│       └── *.png                 # 画像ファイル
└── MacUkagaka/
    ├── Package.swift
    └── MacUkagaka/
        ├── main.swift
        ├── AppDelegate.swift
        ├── GhostManager.swift
        ├── SHIORIClient.swift
        ├── SakuraScriptParser.swift
        └── CharacterWindowController.swift
```

## 4. 設定ファイル形式

### 4.1 descript.txt（ゴースト）

```
charset,UTF-8
name,ゴースト名
sakura.name,メインキャラクター名
kero.name,サブキャラクター名
shiori,SHIORI実行ファイル名
```

### 4.2 descript.txt（シェル）

```
charset,UTF-8
name,シェル名
type,shell
sakura.balloon.offsetx,38
sakura.balloon.offsety,58
```

### 4.3 surfaces.txt（基本形式）

```
charset,Shift_JIS

surface0 {
    element0,base,000_000.png,0,0
    collision0,82,53,144,93,head
    collision1,101,127,114,133,cheek
}
```

## 5. 通信プロトコル

### 5.1 SHIORIプロトコル

MacUkagakaは、SHIORI/3.0プロトコルを実装しています。

**基本的な通信フロー**:
1. ベースウェア（MacUkagaka）がSHIORIプロセスを起動
2. 標準入力でリクエストを送信
3. 標準出力でレスポンスを受信
4. レスポンスを解析してSakuraScriptを実行

**主要イベント**:
- `OnBoot`: 起動時
- `OnClose`: 終了時
- `OnMouseClick`: マウスクリック時
- `OnSecondChange`: 毎秒実行

### 5.2 SakuraScript

**基本制御コード**:
- `\h`: メインキャラクターのスコープ
- `\u`: サブキャラクターのスコープ
- `\s[n]`: Surface（表情）をnに変更
- `\n`: 改行
- `\_w[n]`: nミリ秒待機
- `\q[text,id]`: 選択肢表示
- `\e`: スクリプト終了

## 6. 拡張性

### 6.1 新しいSakuraScript制御コードの追加

1. `SakuraScriptParser.swift`の`parseControlCode`メソッドに新しいケースを追加
2. 対応する`TokenType`を追加
3. `ActionType`に新しいアクションを追加
4. `CharacterWindowController`で新しいアクションを処理

### 6.2 新しいSHIORIサポートの追加

1. `SHIORIClient.swift`の`start`メソッドに新しい条件分岐を追加
2. 対応する`startXXXSHIORi`メソッドを実装
3. プロセス起動とパイプ設定を行う

### 6.3 新しいイベントの追加

1. `GhostManager.swift`に新しいイベントハンドラを追加
2. `CharacterWindowController`から適切なタイミングでイベントを呼び出す
3. 必要に応じて`SHIORIClient`の`request`メソッドを利用

## 7. 既知の制限事項

- WindowsのDLLファイルは直接実行不可
- surfaces.txtの複雑な合成機能は未実装
- アニメーション機能は未実装
- 複数ゴーストの同時実行は未サポート
- 設定の永続化機能は未実装

## 8. パフォーマンス考慮事項

- SHIORIとの通信は同期的に実行（非同期処理の複雑さを避けるため）
- 画像の読み込みとキャッシュは都度実行（メモリ使用量を抑えるため）
- 定期実行は1秒間隔（CPUリソースの節約のため）

## 9. セキュリティ考慮事項

- 外部プロセスの実行は指定されたディレクトリ内のファイルのみ
- 標準入出力の通信でネットワーク通信は行わない
- ファイルアクセスはゴーストディレクトリ内に限定
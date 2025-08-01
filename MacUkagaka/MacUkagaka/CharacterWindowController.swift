//  © eightman 2005-2025
//  Furin-lab All Rights Reserved.
//  ゴーストキャラクターを表示しSakuraScriptを処理するウィンドウコントローラ。

import Cocoa
import Foundation

public class CharacterWindowController: NSWindowController {
    /// SHIORIとの通信を担当するマネージャ。
    private let ghostManager: GhostManager
    /// 現在のサーフェスを表示するイメージビュー。
    private var characterImageView: NSImageView!
    /// セリフを表示する吹き出しウィンドウ。
    private var balloonWindow: NSWindow?
    /// 吹き出しウィンドウ内のテキストフィールド。
    private var balloonTextField: NSTextField?
    /// 表示中のサーフェスID。
    private var currentSurface: Int = 0
    /// SakuraScript文字列を解析するパーサ。
    private var scriptParser: SakuraScriptParser
    /// 実行待ちのアクションキュー。
    private var actionQueue: [SakuraScriptAction] = []
    /// スクリプト処理中かどうかのフラグ。
    private var isProcessingScript = false
    
    /// 指定されたゴーストマネージャと紐づくウィンドウコントローラを生成。
    public init(ghostManager: GhostManager) {
        self.ghostManager = ghostManager
        self.scriptParser = SakuraScriptParser()
        
        let window = NSWindow(
            contentRect: NSRect(x: 100, y: 100, width: 200, height: 300),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        
        super.init(window: window)
        
        setupWindow()
        setupCharacterView()
        loadInitialSurface()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    /// ウィンドウの外観と挙動を設定。
    private func setupWindow() {
        guard let window = window else { return }
        
        window.backgroundColor = NSColor.clear
        window.isOpaque = false
        window.level = .floating
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        window.isMovableByWindowBackground = true
        window.acceptsMouseMovedEvents = true
        window.ignoresMouseEvents = false
        
        window.contentView?.wantsLayer = true
        window.contentView?.layer?.backgroundColor = NSColor.clear.cgColor
    }
    
    /// キャラクター画像ビューを作成して設定。
    private func setupCharacterView() {
        guard let window = window else { return }
        
        characterImageView = NSImageView(frame: window.contentView!.bounds)
        characterImageView.imageScaling = .scaleNone
        characterImageView.imageAlignment = .alignCenter
        characterImageView.wantsLayer = true
        characterImageView.layer?.backgroundColor = NSColor.clear.cgColor
        
        let trackingArea = NSTrackingArea(
            rect: characterImageView.bounds,
            options: [.activeAlways, .mouseEnteredAndExited, .mouseMoved],
            owner: self,
            userInfo: nil
        )
        characterImageView.addTrackingArea(trackingArea)
        
        window.contentView?.addSubview(characterImageView)
        
        characterImageView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            characterImageView.topAnchor.constraint(equalTo: window.contentView!.topAnchor),
            characterImageView.leadingAnchor.constraint(equalTo: window.contentView!.leadingAnchor),
            characterImageView.trailingAnchor.constraint(equalTo: window.contentView!.trailingAnchor),
            characterImageView.bottomAnchor.constraint(equalTo: window.contentView!.bottomAnchor)
        ])
    }
    
    /// 起動時にサーフェス0を読み込む。
    private func loadInitialSurface() {
        loadSurface(0)
    }
    
    /// 指定されたサーフェス画像を表示する。
    private func loadSurface(_ surfaceId: Int) {
        let shellPath = findShellPath()
        guard let path = shellPath else { return }
        
        let surfaceFile = String(format: "%03d_000.png", surfaceId)
        let imagePath = "\(path)/\(surfaceFile)"
        
        guard let image = NSImage(contentsOfFile: imagePath) else {
            let fallbackPath = "\(path)/surface\(surfaceId).png"
            guard let fallbackImage = NSImage(contentsOfFile: fallbackPath) else {
                print("Surface image not found: \(imagePath)")
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
    
    /// シェルリソースを探す。
    private func findShellPath() -> String? {
        let currentPath = FileManager.default.currentDirectoryPath
        let possiblePaths = [
            "\(currentPath)/shell/master",
            "\(currentPath)/../shell/master",
            "\(currentPath)/../../shell/master"
        ]
        
        for path in possiblePaths {
            if FileManager.default.fileExists(atPath: path) {
                return path
            }
        }
        
        return nil
    }
    
    /// 画像サイズに合わせてウィンドウをリサイズ。
    private func adjustWindowSize(for image: NSImage) {
        guard let window = window else { return }
        
        let imageSize = image.size
        var newFrame = window.frame
        newFrame.size = imageSize
        
        window.setFrame(newFrame, display: true)
    }
    
    /// SakuraScript文字列を解析して実行。
    public func processScript(_ script: String) {
        let actions = scriptParser.parse(script)
        actionQueue.append(contentsOf: actions)
        
        if !isProcessingScript {
            processNextAction()
        }
    }
    
    /// 次のSakuraScriptアクションを実行。
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
        case .showChoices(let choices):
            showChoices(choices)
            processNextAction()
        case .end:
            hideBalloon()
            processNextAction()
        }
    }
    
    /// 指定されたテキストの吹き出しを表示。
    private func showBalloon(_ text: String, for scope: Int) {
        hideBalloon()
        
        guard let window = window else { return }
        
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
        balloonWindow?.isOpaque = true
        balloonWindow?.level = .floating
        balloonWindow?.hasShadow = true
        
        balloonTextField = NSTextField(frame: NSRect(x: 10, y: 10, width: 280, height: 80))
        balloonTextField?.stringValue = text
        balloonTextField?.isEditable = false
        balloonTextField?.isSelectable = false
        balloonTextField?.backgroundColor = NSColor.clear
        balloonTextField?.isBordered = false
        balloonTextField?.font = NSFont.systemFont(ofSize: 14)
        balloonTextField?.textColor = NSColor.black
        balloonTextField?.alignment = .left
        balloonTextField?.lineBreakMode = .byWordWrapping
        balloonTextField?.maximumNumberOfLines = 0
        
        balloonWindow?.contentView?.addSubview(balloonTextField!)
        balloonWindow?.orderFrontRegardless()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
            self.hideBalloon()
        }
    }
    
    /// 吹き出しウィンドウを非表示にする。
    private func hideBalloon() {
        balloonWindow?.orderOut(nil)
        balloonWindow = nil
        balloonTextField = nil
    }
    
    /// 選択肢ボタンを表示。
    private func showChoices(_ choices: [(String, String)]) {
        hideBalloon()
        
        guard let window = window else { return }
        
        let balloonFrame = NSRect(
            x: window.frame.origin.x + window.frame.size.width + 10,
            y: window.frame.origin.y + window.frame.size.height - 150,
            width: 300,
            height: 150
        )
        
        balloonWindow = NSWindow(
            contentRect: balloonFrame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        
        balloonWindow?.backgroundColor = NSColor.white
        balloonWindow?.isOpaque = true
        balloonWindow?.level = .floating
        balloonWindow?.hasShadow = true
        
        let stackView = NSStackView(frame: NSRect(x: 10, y: 10, width: 280, height: 130))
        stackView.orientation = .vertical
        stackView.spacing = 10
        
        for (index, choice) in choices.enumerated() {
            let button = NSButton(frame: NSRect(x: 0, y: 0, width: 280, height: 30))
            button.title = choice.0
            button.tag = index
            button.target = self
            button.action = #selector(choiceSelected(_:))
            stackView.addArrangedSubview(button)
        }
        
        balloonWindow?.contentView?.addSubview(stackView)
        balloonWindow?.orderFrontRegardless()
    }
    
    /// 選択肢ボタンが押されたときの処理。
    @objc private func choiceSelected(_ sender: NSButton) {
        hideBalloon()
        
        processNextAction()
    }
}

extension CharacterWindowController {
    /// キャラクターのマウスクリックをゴーストマネージャへ転送する。
    public override func mouseDown(with event: NSEvent) {
        guard window != nil else { return }
        
        let locationInWindow = event.locationInWindow
        let locationInView = characterImageView.convert(locationInWindow, from: nil)
        
        ghostManager.handleMouseClick(
            surfaceId: currentSurface,
            x: Int(locationInView.x),
            y: Int(locationInView.y),
            button: event.buttonNumber
        )
    }
}
import Cocoa
import Foundation

class CharacterWindowController: NSWindowController {
    private let ghostManager: GhostManager
    private var characterImageView: NSImageView!
    private var balloonWindow: NSWindow?
    private var balloonTextField: NSTextField?
    private var currentSurface: Int = 0
    private var scriptParser: SakuraScriptParser
    private var actionQueue: [SakuraScriptAction] = []
    private var isProcessingScript = false
    
    init(ghostManager: GhostManager) {
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
    
    private func setupWindow() {
        guard let window = window else { return }
        
        window.backgroundColor = NSColor.clear
        window.isOpaque = false
        window.level = .floating
        window.isMovableByWindowBackground = true
        window.acceptsMouseMovedEvents = true
        window.ignoresMouseEvents = false
        
        window.contentView?.wantsLayer = true
        window.contentView?.layer?.backgroundColor = NSColor.clear.cgColor
    }
    
    private func setupCharacterView() {
        guard let window = window else { return }
        
        characterImageView = NSImageView(frame: window.contentView!.bounds)
        characterImageView.imageScaling = .scaleNone
        characterImageView.imageAlignment = .alignCenter
        characterImageView.wantsLayer = true
        
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
    
    private func loadInitialSurface() {
        loadSurface(0)
    }
    
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
    
    private func adjustWindowSize(for image: NSImage) {
        guard let window = window else { return }
        
        let imageSize = image.size
        var newFrame = window.frame
        newFrame.size = imageSize
        
        window.setFrame(newFrame, display: true)
    }
    
    func processScript(_ script: String) {
        let actions = scriptParser.parse(script)
        actionQueue.append(contentsOf: actions)
        
        if !isProcessingScript {
            processNextAction()
        }
    }
    
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
    
    private func hideBalloon() {
        balloonWindow?.orderOut(nil)
        balloonWindow = nil
        balloonTextField = nil
    }
    
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
    
    @objc private func choiceSelected(_ sender: NSButton) {
        hideBalloon()
        
        processNextAction()
    }
}

extension CharacterWindowController {
    override func mouseDown(with event: NSEvent) {
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
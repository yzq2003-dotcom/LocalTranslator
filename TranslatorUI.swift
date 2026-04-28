#!/usr/bin/env swift
// ============================================================
// TranslatorUI.swift — Apple-native-style Translation Panel
// 使用 AppKit 构建的本地翻译弹窗，风格贴近 Apple 原生翻译 UI
// ============================================================

import Cocoa

// MARK: - 数据模型
struct TranslationData: Codable {
    let original: String
    let translated: String
    let sourceLang: String
    let targetLang: String
    let modelName: String
}

// MARK: - 翻译面板窗口
class TranslationPanel: NSWindow {

    private struct PanelLayout {
        let windowWidth: CGFloat
        let windowHeight: CGFloat
        let contentWidth: CGFloat
        let originalViewportHeight: CGFloat
        let translatedViewportHeight: CGFloat
        let originalDocumentHeight: CGFloat
        let translatedDocumentHeight: CGFloat
    }

    private var originalTextView: NSTextView!
    private var translatedTextView: NSTextView!
    private var headerLabel: NSTextField!
    private var copyButton: NSButton!
    private var closeButton: NSButton!
    private var divider: NSBox!
    private let data: TranslationData
    private let layout: PanelLayout

    init(data: TranslationData) {
        self.data = data

        let screenFrame = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        let windowWidth = min(max(screenFrame.width * 0.38, 460), 560)
        let padding: CGFloat = 20
        let contentWidth = windowWidth - padding * 2

        let originalFont = NSFont.systemFont(ofSize: 13)
        let translatedFont = NSFont.systemFont(ofSize: 14, weight: .medium)
        let originalDocumentHeight = TranslationPanel.measureTextHeight(data.original, width: contentWidth, font: originalFont)
        let translatedDocumentHeight = TranslationPanel.measureTextHeight(data.translated, width: contentWidth, font: translatedFont)

        var originalViewportHeight = min(max(originalDocumentHeight, 64), 150)
        var translatedViewportHeight = min(max(translatedDocumentHeight, 80), 320)

        let fixedHeight: CGFloat = 147
        let maxWindowHeight = max(260, min(screenFrame.height - 80, 720))
        let preferredHeight = fixedHeight + originalViewportHeight + translatedViewportHeight
        if preferredHeight > maxWindowHeight {
            let overflow = preferredHeight - maxWindowHeight
            let translatedShrink = min(overflow, max(0, translatedViewportHeight - 80))
            translatedViewportHeight -= translatedShrink

            let remainingOverflow = overflow - translatedShrink
            let originalShrink = min(remainingOverflow, max(0, originalViewportHeight - 64))
            originalViewportHeight -= originalShrink
        }

        let windowHeight = min(max(fixedHeight + originalViewportHeight + translatedViewportHeight, 240), maxWindowHeight)
        self.layout = PanelLayout(
            windowWidth: windowWidth,
            windowHeight: windowHeight,
            contentWidth: contentWidth,
            originalViewportHeight: originalViewportHeight,
            translatedViewportHeight: translatedViewportHeight,
            originalDocumentHeight: originalDocumentHeight,
            translatedDocumentHeight: translatedDocumentHeight
        )

        let windowX = screenFrame.midX - windowWidth / 2
        let windowY = screenFrame.midY - windowHeight / 2

        super.init(
            contentRect: NSRect(x: windowX, y: windowY, width: windowWidth, height: windowHeight),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        self.title = ""
        self.titlebarAppearsTransparent = true
        self.titleVisibility = .hidden
        self.isMovableByWindowBackground = true
        self.level = .floating
        self.backgroundColor = .clear
        self.isOpaque = false
        self.hasShadow = true

        setupUI()
    }

    private static func measureTextHeight(_ text: String, width: CGFloat, font: NSFont) -> CGFloat {
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineBreakMode = .byCharWrapping
        paragraphStyle.paragraphSpacing = 2

        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .paragraphStyle: paragraphStyle
        ]
        let boundingRect = (text as NSString).boundingRect(
            with: NSSize(width: width, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: attributes
        )
        let minimumHeight = max(ceil(font.ascender - font.descender + font.leading) + 4, 24)
        return max(ceil(boundingRect.height) + 4, minimumHeight)
    }

    private func setupUI() {
        let windowWidth = layout.windowWidth
        let windowHeight = layout.windowHeight
        let container = NSVisualEffectView(frame: NSRect(x: 0, y: 0, width: windowWidth, height: windowHeight))
        container.material = .hudWindow
        container.blendingMode = .behindWindow
        container.state = .active
        container.wantsLayer = true
        container.layer?.cornerRadius = 12
        container.layer?.masksToBounds = true
        self.contentView = container

        let padding: CGFloat = 20
        let contentWidth = layout.contentWidth
        var currentY = windowHeight - 44  // 从顶部 titlebar 下方开始

        // ── 头部：语言方向标签 ──
        headerLabel = makeLabel(
            "\(data.sourceLang)  →  \(data.targetLang)",
            fontSize: 11,
            color: .secondaryLabelColor,
            bold: false
        )
        headerLabel.frame = NSRect(x: padding, y: currentY, width: contentWidth - 168, height: 16)

        // ── 模型标签 ──
        let modelTag = makeLabel(
            "Model: \(data.modelName)",
            fontSize: 10,
            color: .tertiaryLabelColor,
            bold: false
        )
        modelTag.frame = NSRect(x: windowWidth - padding - 160, y: currentY, width: 160, height: 14)
        modelTag.alignment = .right
        container.addSubview(headerLabel)
        container.addSubview(modelTag)

        currentY -= 28

        // ── 原文区域（ScrollView 包裹） ──
        let originalFrame = NSRect(
            x: padding,
            y: currentY - layout.originalViewportHeight,
            width: contentWidth,
            height: layout.originalViewportHeight
        )
        let originalArea = makeScrollableTextArea(
            text: data.original,
            font: NSFont.systemFont(ofSize: 13),
            color: .secondaryLabelColor,
            frame: originalFrame,
            documentHeight: layout.originalDocumentHeight
        )
        originalTextView = originalArea.textView
        let originalScroll = originalArea.scrollView
        container.addSubview(originalScroll)
        currentY -= layout.originalViewportHeight + 12

        // ── 分割线 ──
        divider = NSBox(frame: NSRect(x: padding, y: currentY, width: contentWidth, height: 1))
        divider.boxType = .separator
        container.addSubview(divider)
        currentY -= 14

        // ── 译文区域（ScrollView 包裹） ──
        let translatedFrame = NSRect(
            x: padding,
            y: currentY - layout.translatedViewportHeight,
            width: contentWidth,
            height: layout.translatedViewportHeight
        )
        let translatedArea = makeScrollableTextArea(
            text: data.translated,
            font: NSFont.systemFont(ofSize: 14, weight: .medium),
            color: .labelColor,
            frame: translatedFrame,
            documentHeight: layout.translatedDocumentHeight
        )
        translatedTextView = translatedArea.textView
        let translatedScroll = translatedArea.scrollView
        container.addSubview(translatedScroll)
        currentY -= layout.translatedViewportHeight + 16

        // ── 底部按钮栏 ──
        let buttonY = max(currentY, padding)

        // 复制按钮（蓝色主题）
        copyButton = NSButton(frame: NSRect(x: windowWidth - padding - 100, y: buttonY, width: 100, height: 28))
        copyButton.title = "拷贝译文"
        copyButton.bezelStyle = .rounded
        copyButton.controlSize = .regular
        copyButton.keyEquivalent = "c"
        copyButton.keyEquivalentModifierMask = .command
        copyButton.target = self
        copyButton.action = #selector(copyTranslation)
        if #available(macOS 11.0, *) {
            copyButton.hasDestructiveAction = false
        }
        container.addSubview(copyButton)

        // 关闭按钮
        closeButton = NSButton(frame: NSRect(x: windowWidth - padding - 170, y: buttonY, width: 60, height: 28))
        closeButton.title = "关闭"
        closeButton.bezelStyle = .rounded
        closeButton.controlSize = .regular
        closeButton.keyEquivalent = "\u{1b}" // ESC
        closeButton.target = self
        closeButton.action = #selector(closePanel)
        container.addSubview(closeButton)

        DispatchQueue.main.async {
            self.originalTextView.scrollRangeToVisible(NSRange(location: 0, length: 0))
            self.translatedTextView.scrollRangeToVisible(NSRange(location: 0, length: 0))
        }
    }

    private func makeScrollableTextArea(text: String, font: NSFont, color: NSColor, frame: NSRect, documentHeight: CGFloat) -> (scrollView: NSScrollView, textView: NSTextView) {
        let scrollView = NSScrollView(frame: frame)
        scrollView.hasVerticalScroller = documentHeight > frame.height + 1
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder
        scrollView.drawsBackground = false

        let textViewHeight = max(documentHeight, frame.height)
        let textView = NSTextView(frame: NSRect(x: 0, y: 0, width: frame.width, height: textViewHeight))
        textView.isEditable = false
        textView.isSelectable = true
        textView.isRichText = false
        textView.importsGraphics = false
        textView.drawsBackground = false
        textView.backgroundColor = .clear
        textView.textColor = color
        textView.font = font
        textView.textContainerInset = NSSize(width: 0, height: 0)
        textView.textContainer?.lineFragmentPadding = 0
        textView.textContainer?.widthTracksTextView = true
        textView.textContainer?.containerSize = NSSize(width: frame.width, height: .greatestFiniteMagnitude)
        textView.textContainer?.lineBreakMode = .byCharWrapping
        textView.minSize = NSSize(width: frame.width, height: 0)
        textView.maxSize = NSSize(width: frame.width, height: .greatestFiniteMagnitude)
        textView.isHorizontallyResizable = false
        textView.isVerticallyResizable = true
        textView.autoresizingMask = [.width]

        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineBreakMode = .byCharWrapping
        paragraphStyle.paragraphSpacing = 2
        textView.textStorage?.setAttributedString(NSAttributedString(
            string: text,
            attributes: [
                .font: font,
                .foregroundColor: color,
                .paragraphStyle: paragraphStyle
            ]
        ))

        scrollView.documentView = textView
        return (scrollView, textView)
    }

    private func makeLabel(_ text: String, fontSize: CGFloat, color: NSColor, bold: Bool) -> NSTextField {
        let label = NSTextField(labelWithString: text)
        label.font = bold ? NSFont.boldSystemFont(ofSize: fontSize) : NSFont.systemFont(ofSize: fontSize)
        label.textColor = color
        label.backgroundColor = .clear
        label.isBordered = false
        label.isEditable = false
        label.isSelectable = false
        return label
    }

    @objc private func copyTranslation() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(data.translated, forType: .string)

        // 显示"已复制"通知 (使用 osascript 兼容最新 macOS)
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        task.arguments = ["-e", "display notification \"译文已拷贝到剪贴板\" with title \"翻译已拷贝\" sound name \"Glass\""]
        try? task.run()

        // 短暂延迟后关闭
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            NSApplication.shared.terminate(nil)
        }
    }

    @objc private func closePanel() {
        NSApplication.shared.terminate(nil)
    }
}

// MARK: - Application Delegate
class AppDelegate: NSObject, NSApplicationDelegate {
    var window: TranslationPanel?
    let data: TranslationData

    init(data: TranslationData) {
        self.data = data
        super.init()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        window = TranslationPanel(data: data)
        window?.makeKeyAndOrderFront(nil)
        NSApplication.shared.activate(ignoringOtherApps: true)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }
}

// MARK: - 入口
// 参数:
// 1. TranslatorUI --payload /path/to/payload.json
// 2. TranslatorUI <original> <translated> <sourceLang> <targetLang> <modelName>
let args = CommandLine.arguments

func loadTranslationData(from args: [String]) -> TranslationData? {
    if args.count == 3, args[1] == "--payload" {
        let payloadURL = URL(fileURLWithPath: args[2])
        guard
            let payloadData = try? Data(contentsOf: payloadURL),
            let decoded = try? JSONDecoder().decode(TranslationData.self, from: payloadData)
        else {
            return nil
        }
        return decoded
    }

    if args.count >= 6 {
        return TranslationData(
            original: args[1],
            translated: args[2],
            sourceLang: args[3],
            targetLang: args[4],
            modelName: args[5]
        )
    }

    return nil
}

guard let translationData = loadTranslationData(from: args) else {
    fputs("Usage: TranslatorUI --payload <json-file>\n       TranslatorUI <original> <translated> <sourceLang> <targetLang> <modelName>\n", stderr)
    exit(1)
}

let app = NSApplication.shared
app.setActivationPolicy(.accessory)
let delegate = AppDelegate(data: translationData)
app.delegate = delegate
app.run()

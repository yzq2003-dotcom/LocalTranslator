#!/usr/bin/env swift
// ============================================================
// TranslatorUI.swift — Apple-native-style Translation Panel
// 使用 AppKit 构建的本地翻译弹窗，风格贴近 Apple 原生翻译 UI
// ============================================================

import Cocoa

// MARK: - 数据模型
struct TranslationData {
    let original: String
    let translated: String
    let sourceLang: String
    let targetLang: String
    let modelName: String
}

// MARK: - 翻译面板窗口
class TranslationPanel: NSWindow {

    private var originalLabel: NSTextField!
    private var translatedLabel: NSTextField!
    private var headerLabel: NSTextField!
    private var copyButton: NSButton!
    private var closeButton: NSButton!
    private var divider: NSBox!
    private var data: TranslationData

    init(data: TranslationData) {
        self.data = data

        // 动态计算窗口高度
        let windowWidth: CGFloat = 420
        let padding: CGFloat = 20
        let contentWidth = windowWidth - padding * 2

        // 测量文本高度
        let originalHeight = TranslationPanel.measureTextHeight(data.original, width: contentWidth, fontSize: 13)
        let translatedHeight = TranslationPanel.measureTextHeight(data.translated, width: contentWidth, fontSize: 14)

        // header(30) + originalText + spacing(12) + divider(1) + spacing(12) + translatedText + spacing(16) + buttons(32) + padding
        let totalHeight = 30 + originalHeight + 12 + 1 + 12 + translatedHeight + 16 + 32 + padding * 2 + 16
        let clampedHeight = min(max(totalHeight, 200), 600)

        let screenFrame = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        let windowX = screenFrame.midX - windowWidth / 2
        let windowY = screenFrame.midY - clampedHeight / 2

        super.init(
            contentRect: NSRect(x: windowX, y: windowY, width: windowWidth, height: clampedHeight),
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

        setupUI(windowWidth: windowWidth, windowHeight: clampedHeight)
    }

    private static func measureTextHeight(_ text: String, width: CGFloat, fontSize: CGFloat) -> CGFloat {
        let font = NSFont.systemFont(ofSize: fontSize)
        let attributes: [NSAttributedString.Key: Any] = [.font: font]
        let boundingRect = (text as NSString).boundingRect(
            with: NSSize(width: width, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: attributes
        )
        return min(max(ceil(boundingRect.height), 20), 200)
    }

    private func setupUI(windowWidth: CGFloat, windowHeight: CGFloat) {
        let container = NSVisualEffectView(frame: NSRect(x: 0, y: 0, width: windowWidth, height: windowHeight))
        container.material = .hudWindow
        container.blendingMode = .behindWindow
        container.state = .active
        container.wantsLayer = true
        container.layer?.cornerRadius = 12
        container.layer?.masksToBounds = true
        self.contentView = container

        let padding: CGFloat = 20
        let contentWidth = windowWidth - padding * 2
        var currentY = windowHeight - 48  // 从顶部 titlebar 下方开始

        // ── 头部：语言方向标签 ──
        headerLabel = makeLabel(
            "\(data.sourceLang)  →  \(data.targetLang)",
            fontSize: 11,
            color: .secondaryLabelColor,
            bold: false
        )
        headerLabel.frame = NSRect(x: padding, y: currentY, width: contentWidth, height: 16)
        container.addSubview(headerLabel)

        currentY -= 8

        // ── 模型标签 ──
        let modelTag = makeLabel(
            "⚡ \(data.modelName)",
            fontSize: 10,
            color: .tertiaryLabelColor,
            bold: false
        )
        modelTag.frame = NSRect(x: windowWidth - padding - 120, y: currentY + 8, width: 120, height: 14)
        modelTag.alignment = .right
        container.addSubview(modelTag)

        currentY -= 8

        // ── 原文区域（ScrollView 包裹） ──
        let originalHeight = TranslationPanel.measureTextHeight(data.original, width: contentWidth, fontSize: 13)
        let clampedOriginalHeight = min(originalHeight, 120)

        let originalScroll = NSScrollView(frame: NSRect(x: padding, y: currentY - clampedOriginalHeight, width: contentWidth, height: clampedOriginalHeight))
        originalScroll.hasVerticalScroller = true
        originalScroll.autohidesScrollers = true
        originalScroll.borderType = .noBorder
        originalScroll.drawsBackground = false

        originalLabel = NSTextField(wrappingLabelWithString: data.original)
        originalLabel.font = NSFont.systemFont(ofSize: 13)
        originalLabel.textColor = .secondaryLabelColor
        originalLabel.backgroundColor = .clear
        originalLabel.isEditable = false
        originalLabel.isSelectable = true
        originalLabel.frame = NSRect(x: 0, y: 0, width: contentWidth, height: originalHeight)

        originalScroll.documentView = originalLabel
        container.addSubview(originalScroll)
        currentY -= clampedOriginalHeight + 12

        // ── 分割线 ──
        divider = NSBox(frame: NSRect(x: padding, y: currentY, width: contentWidth, height: 1))
        divider.boxType = .separator
        container.addSubview(divider)
        currentY -= 14

        // ── 译文区域（ScrollView 包裹） ──
        let translatedHeight = TranslationPanel.measureTextHeight(data.translated, width: contentWidth, fontSize: 14)
        let clampedTranslatedHeight = min(translatedHeight, 200)

        let translatedScroll = NSScrollView(frame: NSRect(x: padding, y: currentY - clampedTranslatedHeight, width: contentWidth, height: clampedTranslatedHeight))
        translatedScroll.hasVerticalScroller = true
        translatedScroll.autohidesScrollers = true
        translatedScroll.borderType = .noBorder
        translatedScroll.drawsBackground = false

        translatedLabel = NSTextField(wrappingLabelWithString: data.translated)
        translatedLabel.font = NSFont.systemFont(ofSize: 14, weight: .medium)
        translatedLabel.textColor = .labelColor
        translatedLabel.backgroundColor = .clear
        translatedLabel.isEditable = false
        translatedLabel.isSelectable = true
        translatedLabel.frame = NSRect(x: 0, y: 0, width: contentWidth, height: translatedHeight)

        translatedScroll.documentView = translatedLabel
        container.addSubview(translatedScroll)
        currentY -= clampedTranslatedHeight + 16

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
// 参数: original translated sourceLang targetLang modelName
let args = CommandLine.arguments
guard args.count >= 6 else {
    fputs("Usage: TranslatorUI <original> <translated> <sourceLang> <targetLang> <modelName>\n", stderr)
    exit(1)
}

let translationData = TranslationData(
    original: args[1],
    translated: args[2],
    sourceLang: args[3],
    targetLang: args[4],
    modelName: args[5]
)

let app = NSApplication.shared
app.setActivationPolicy(.accessory)
let delegate = AppDelegate(data: translationData)
app.delegate = delegate
app.run()

import AppKit
import Foundation
import UserNotifications

// MARK: - AppKit SVG 扩展
extension NSImage {
    convenience init?(svgName: String, size: CGFloat = 16) {
        let bundlePaths = [
            Bundle.main.resourcePath ?? "",
            Bundle.main.bundlePath + "/Contents/Resources"
        ]
        
        var svgData: Data?
        for basePath in bundlePaths {
            let svgPath = (basePath as NSString).appendingPathComponent("icons/\(svgName).svg")
            if FileManager.default.fileExists(atPath: svgPath) {
                svgData = FileManager.default.contents(atPath: svgPath)
                break
            }
        }
        
        // 降级：开发时从本地路径读取
        if svgData == nil {
            let homeDir = FileManager.default.homeDirectoryForCurrentUser.path
            let devPath = "\(homeDir)/Documents/project/PicBase64/icons/\(svgName).svg"
            svgData = FileManager.default.contents(atPath: devPath)
        }
        
        guard let data = svgData else { return nil }
        
        // 修改 SVG 使用黑色
        let svgString = String(data: data, encoding: .utf8) ?? ""
        let modified = svgString
            .replacingOccurrences(of: "#000000", with: "#000000")
            .replacingOccurrences(of: "currentColor", with: "#000000")
        
        guard let modifiedData = modified.data(using: .utf8) else { return nil }
        let rep = NSImage(data: modifiedData)
        
        self.init(size: NSSize(width: size, height: size))
        self.lockFocus()
        rep?.draw(in: NSRect(x: 0, y: 0, width: size, height: size),
                 from: NSRect.zero,
                 operation: .sourceOver,
                 fraction: 1.0)
        self.unlockFocus()
        self.isTemplate = true
    }
}

// MARK: - 输出格式
enum OutputFormat: String {
    case raw        = "raw"
    case dataURL    = "data"
    case markdown   = "md"
    case json       = "json"
}

// MARK: - AppDelegate
class AppDelegate: NSObject, NSApplicationDelegate, UNUserNotificationCenterDelegate {
    var statusItem: NSStatusItem!
    var format: OutputFormat = .dataURL
    var saveToDesktop = false
    var previewController: PreviewWindowController?
    var settingsController: SettingsWindowController?

    func debugLog(_ message: String) {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSS"
        let timestamp = formatter.string(from: Date())
        let logLine = "[\(timestamp)] \(message)\n"
        
        let logPath = "/tmp/shotbase64_debug.log"
        if let handle = FileHandle(forWritingAtPath: logPath) {
            handle.seekToEndOfFile()
            handle.write(logLine.data(using: .utf8)!)
            handle.closeFile()
        } else {
            FileManager.default.createFile(atPath: logPath, contents: logLine.data(using: .utf8), attributes: nil)
        }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        UNUserNotificationCenter.current().delegate = self
        requestPermissions()
        setupMenuBar()
        showNotify(title: "PicBase64 v3 已启动", body: "📷 截取 → /v3 粘贴读取 →")
    }

    func requestPermissions() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
    }

    func userNotificationCenter(_ c: UNUserNotificationCenter, willPresent _: UNNotification,
                                withCompletionHandler h: @escaping (UNNotificationPresentationOptions) -> Void) {
        h([.banner, .sound, .list])
    }

    func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            let img = NSImage(systemSymbolName: "camera.fill", accessibilityDescription: nil)
            img?.isTemplate = true
            button.image = img
        }

        let menu = NSMenu()

        // 截图
        addShotItem(menu, title: "选取区域截图         ⌥1", selector: #selector(captureRegion(_:)), key: "1")
        addShotItem(menu, title: "截取窗口             ⌥2", selector: #selector(captureWindow(_:)), key: "2")
        addShotItem(menu, title: "全屏截图             ⌥3", selector: #selector(captureFull(_:)), key: "3")
        addShotItem(menu, title: "剪贴板图片 → Base64  ⌥C", selector: #selector(clipboardToB64(_:)), key: "c")

        menu.addItem(.separator())

        // 🆕 反向解析
        let readItem = NSMenuItem(title: "读取 Base64 → 显示图片  ⌥V",
                                  action: #selector(showBase64Preview(_:)), keyEquivalent: "v")
        readItem.keyEquivalentModifierMask = .option
        readItem.target = self
        menu.addItem(readItem)

        menu.addItem(.separator())

        // ⚙️ 设置
        let settingsItem = NSMenuItem(title: "设置...",
                                      action: #selector(showSettings(_:)), keyEquivalent: ",")
        settingsItem.keyEquivalentModifierMask = .command
        settingsItem.target = self
        menu.addItem(settingsItem)

        menu.addItem(.separator())

        // 输出格式
        let formatParent = NSMenuItem(title: "输出格式", action: nil, keyEquivalent: "")
        let formatMenu = NSMenu()
        formatParent.submenu = formatMenu
        let formats: [(String, OutputFormat)] = [
            ("data:image URL (推荐)", .dataURL),
            ("纯 Base64", .raw),
            ("Markdown ![](data:...)", .markdown),
            ("JSON {\"data\":\"...\"}", .json),
        ]
        for (label, fmt) in formats {
            let item = NSMenuItem(title: label, action: #selector(chooseFormat(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = fmt
            item.state = (fmt == format) ? .on : .off
            formatMenu.addItem(item)
        }
        menu.addItem(formatParent)

        let saveItem = NSMenuItem(title: "同时保存 PNG 到桌面", action: #selector(toggleSave(_:)), keyEquivalent: "")
        saveItem.state = saveToDesktop ? .on : .off
        saveItem.target = self
        menu.addItem(saveItem)

        menu.addItem(.separator())

        let quitItem = NSMenuItem(title: "退出", action: #selector(quit(_:)), keyEquivalent: "q")
        quitItem.keyEquivalentModifierMask = .command
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem.menu = menu
    }

    func addShotItem(_ menu: NSMenu, title: String, selector: Selector, key: String) {
        let item = NSMenuItem(title: title, action: selector, keyEquivalent: key)
        item.keyEquivalentModifierMask = .option
        item.target = self
        menu.addItem(item)
    }

    // MARK: - 截图
    @objc func captureRegion(_ s: Any?) { capture(args: ["-i", "-x"]) }
    @objc func captureWindow(_ s: Any?) { capture(args: ["-iW", "-x"]) }
    @objc func captureFull(_ s: Any?)    { capture(args: ["-x"]) }

    func capture(args: [String]) {
        statusItem.menu?.cancelTracking()
        let tmpFile = NSTemporaryDirectory() + "PicBase64_\(UUID().uuidString).png"
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
        task.arguments = args + [tmpFile]
        do {
            try task.run()
            task.waitUntilExit()
            if task.terminationStatus != 0 { return }
            guard FileManager.default.fileExists(atPath: tmpFile) else { return }
            defer { try? FileManager.default.removeItem(atPath: tmpFile) }
            let data = try Data(contentsOf: URL(fileURLWithPath: tmpFile))
            processResult(data: data, label: "截图")
        } catch {
            NSSound.beep()
            showNotify(title: "截图失败", body: "\(error)")
        }
    }

    @objc func clipboardToB64(_ s: Any?) {
        let pb = NSPasteboard.general
        guard let image = pb.readObjects(forClasses: [NSImage.self], options: nil)?.first as? NSImage,
              let tiff = image.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff),
              let pngData = rep.representation(using: .png, properties: [:]) else {
            showNotify(title: "剪贴板无图片", body: "请先复制一张图片")
            return
        }
        processResult(data: pngData, label: "剪贴板图片")
    }

    func processResult(data: Data, label: String) {
        let b64 = data.base64EncodedString()
        var output: String
        switch format {
        case .raw:      output = b64
        case .dataURL:  output = "data:image/png;base64,\(b64)"
        case .markdown: output = "![\(label)](data:image/png;base64,\(b64))"
        case .json:
            let json: [String: Any] = ["type": "image/png", "data": b64, "size": data.count]
            if let d = try? JSONSerialization.data(withJSONObject: json, options: [.prettyPrinted, .sortedKeys]),
               let s = String(data: d, encoding: .utf8) { output = s } else { output = b64 }
        }

        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(output, forType: .string)

        if saveToDesktop {
            let desktopPath = NSSearchPathForDirectoriesInDomains(.desktopDirectory, .userDomainMask, true)[0]
            let savePath = "\(desktopPath)/PicBase64_\(formatTS()).png"
            try? data.write(to: URL(fileURLWithPath: savePath))
            showNotify(title: "\(label) 已保存", body: savePath)
        }

        NSSound(named: "Funk")?.play()
        let sizeKB = Double(data.count) / 1024.0
        let body = String(format: "大小 %.1f KB · Base64 %d 字符", sizeKB, b64.count)
        showNotify(title: "✅ \(label) Base64 已复制", body: body)
    }

    // MARK: - 🆕 读取 Base64 显示图片
    @objc func showBase64Preview(_ s: Any?) {
        debugLog("=== 🆕 读取 Base64 显示图片 ===")
        let pb = NSPasteboard.general
        var text: String?

        if let str = pb.string(forType: .string) {
            text = str
            debugLog("✅ 从剪贴板读取到 \(str.count) 字符")
        } else {
            debugLog("❌ 剪贴板为空或不是字符串")
        }

        if previewController == nil {
            debugLog("创建 PreviewWindowController...")
            previewController = PreviewWindowController(parent: self)
        }
        previewController?.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
        previewController?.window?.makeKeyAndOrderFront(nil)
        debugLog("✅ 窗口已显示")

        if let input = text, let data = decodeBase64(input) {
            debugLog("✅ 解码成功，调用 setImage")
            previewController?.setImage(data: data, source: .clipboard(input))
        } else {
            debugLog("❌ 解码失败或文本为空")
            previewController?.setImage(data: nil, source: .clipboard(text ?? ""))
        }
    }

    func decodeBase64(_ input: String) -> Data? {
        var s = input.trimmingCharacters(in: .whitespacesAndNewlines)
        debugLog("\n=== decodeBase64 开始 ===")
        debugLog("原始输入长度: \(s.count)")
        debugLog("前100字符: \(s.prefix(100))")
        
        // 1. 去除 markdown ![alt](data:...)
        if s.hasPrefix("![") {
            if let start = s.range(of: "base64,"), let end = s.range(of: ")", options: .backwards) {
                s = String(s[start.upperBound..<end.lowerBound])
                debugLog("✅ 去掉 markdown 包装")
            }
        }
        
        // 2. 去除 data URL 前缀
        if s.hasPrefix("data:") {
            if let range = s.range(of: ",") {
                s = String(s[range.upperBound...])
                debugLog("✅ 去掉 data URL 前缀")
            }
        }
        
        // 3. 去掉首尾引号
        if (s.hasPrefix("\"") && s.hasSuffix("\"")) ||
           (s.hasPrefix("'") && s.hasSuffix("'")) {
            s = String(s.dropFirst().dropLast())
            debugLog("✅ 去掉引号")
        }
        
        // 4. 清理空白字符
        s = s.replacingOccurrences(of: "\\s+", with: "", options: .regularExpression)
        debugLog("清理后长度: \(s.count)")
        
        // 5. 解码
        guard let data = Data(base64Encoded: s, options: .ignoreUnknownCharacters) else {
            debugLog("❌ base64 解码失败")
            debugLog("前50字符: \(String(s.prefix(50)))")
            return nil
        }
        debugLog("✅ 解码成功: \(data.count) bytes")
        return data
    }

    // MARK: - Menu actions
    @objc func chooseFormat(_ sender: NSMenuItem) {
        guard let fmt = sender.representedObject as? OutputFormat else { return }
        format = fmt
        for item in sender.menu?.items ?? [] {
            item.state = (item.representedObject as? OutputFormat == fmt) ? .on : .off
        }
        showNotify(title: "输出格式", body: fmt.rawValue)
    }

    @objc func toggleSave(_ sender: NSMenuItem) {
        saveToDesktop.toggle()
        sender.state = saveToDesktop ? .on : .off
    }

    // MARK: - ⚙️ 设置
    @objc func showSettings(_ sender: NSMenuItem?) {
        if settingsController == nil {
            settingsController = SettingsWindowController(parent: self)
        }
        settingsController?.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
        settingsController?.window?.makeKeyAndOrderFront(nil)
    }

    @objc func quit(_ s: Any?) { NSApp.terminate(nil) }

    func showNotify(title: String, body: String) {
        let c = UNMutableNotificationContent()
        c.title = title; c.body = body; c.sound = .default
        UNUserNotificationCenter.current().add(
            UNNotificationRequest(identifier: UUID().uuidString, content: c, trigger: nil))
    }

    func formatTS() -> String {
        let df = DateFormatter(); df.dateFormat = "HHmmss"
        return df.string(from: Date())
    }
}

// MARK: - 图片来源
enum ImageSource {
    case clipboard(String)
    case drag(String)
    case file(URL)
}

// MARK: - 图片预览窗口
class PreviewWindowController: NSWindowController, NSWindowDelegate {
    weak var parent: AppDelegate?
    var imageView: NSImageView!
    var infoLabel: NSTextField!
    var currentData: Data?
    var currentSource: ImageSource?

    // 拖拽区
    var dropZone: NSView!

    init(parent: AppDelegate) {
        self.parent = parent
        let frame = NSRect(x: 0, y: 0, width: 760, height: 620)
        let window = NSWindow(contentRect: frame,
                              styleMask: [.titled, .closable, .resizable, .miniaturizable],
                              backing: .buffered, defer: false)
        window.title = "PicBase64 · 图片预览"
        window.center()
        window.isRestorable = true
        super.init(window: window)
        window.delegate = self
        setupUI()
    }

    required init?(coder: NSCoder) { fatalError() }

    func setupUI() {
        guard let window = window, let cv = window.contentView else { return }
        cv.wantsLayer = true
        cv.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor

        let margin: CGFloat = 16

        // 顶部工具栏
        let toolbar = NSStackView()
        toolbar.orientation = .horizontal
        toolbar.spacing = 8

        let pasteBtn = toolbarButton(icon: "clipboard", title: "从剪贴板读取", action: #selector(loadFromClipboard))
        let copyPngBtn = toolbarButton(icon: "image", title: "复制 PNG 图片", action: #selector(copyPNG))
        let copyB64Btn = toolbarButton(icon: "copy", title: "复制 Base64", action: #selector(copyB64))
        let saveBtn = toolbarButton(icon: "download", title: "保存文件", action: #selector(saveFile))
        let clearBtn = toolbarButton(icon: "trash-2", title: "清空", action: #selector(clearAll))

        [pasteBtn, copyPngBtn, copyB64Btn, saveBtn, NSView(), clearBtn].forEach { toolbar.addArrangedSubview($0) }

        cv.addSubview(toolbar)
        toolbar.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            toolbar.topAnchor.constraint(equalTo: cv.topAnchor, constant: margin),
            toolbar.leadingAnchor.constraint(equalTo: cv.leadingAnchor, constant: margin),
            toolbar.trailingAnchor.constraint(equalTo: cv.trailingAnchor, constant: -margin),
            toolbar.heightAnchor.constraint(equalToConstant: 32)
        ])

        // 信息标签
        infoLabel = NSTextField(labelWithString: "拖入 base64 文本 · 或点击「从剪贴板读取」")
        infoLabel.font = .systemFont(ofSize: 12, weight: .medium)
        infoLabel.textColor = .secondaryLabelColor
        infoLabel.alignment = .center
        infoLabel.lineBreakMode = .byTruncatingTail
        infoLabel.maximumNumberOfLines = 1
        cv.addSubview(infoLabel)
        infoLabel.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            infoLabel.topAnchor.constraint(equalTo: toolbar.bottomAnchor, constant: 8),
            infoLabel.leadingAnchor.constraint(equalTo: cv.leadingAnchor, constant: margin),
            infoLabel.trailingAnchor.constraint(equalTo: cv.trailingAnchor, constant: -margin)
        ])

        // 图片展示区 (带滚轮缩放)
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.borderType = .bezelBorder

        imageView = NSImageView()
        imageView.imageScaling = .scaleProportionallyUpOrDown
        imageView.animates = true

        scrollView.documentView = imageView
        cv.addSubview(scrollView)
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: infoLabel.bottomAnchor, constant: 10),
            scrollView.leadingAnchor.constraint(equalTo: cv.leadingAnchor, constant: margin),
            scrollView.trailingAnchor.constraint(equalTo: cv.trailingAnchor, constant: -margin),
            scrollView.bottomAnchor.constraint(equalTo: cv.bottomAnchor, constant: -margin)
        ])

        // 拖拽接收区（覆盖整个窗口）
        dropZone = NSView()
        dropZone.wantsLayer = true
        dropZone.unregisterDraggedTypes()
        dropZone.registerForDraggedTypes([.string, .fileURL])
        cv.addSubview(dropZone)
        dropZone.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            dropZone.topAnchor.constraint(equalTo: scrollView.topAnchor),
            dropZone.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            dropZone.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            dropZone.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor)
        ])

        // 用 NSWindow 本身接收拖拽（更可靠）
        window.registerForDraggedTypes([.string, .fileURL])
    }

    func toolbarButton(icon: String, title: String, action: Selector) -> NSButton {
        let btn = NSButton(title: "", target: self, action: action)
        btn.bezelStyle = .rounded
        btn.controlSize = .small
        btn.font = .systemFont(ofSize: 12)
        
        let hStack = NSStackView()
        hStack.orientation = .horizontal
        hStack.spacing = 4
        hStack.alignment = .centerY
        
        if let iconImage = IconManager.shared.icon(icon, size: 14) {
            let iconView = NSImageView(image: iconImage)
            hStack.addArrangedSubview(iconView)
        }
        
        let titleLabel = NSTextField(labelWithString: title)
        titleLabel.font = .systemFont(ofSize: 12)
        hStack.addArrangedSubview(titleLabel)
        
        btn.wantsLayer = true
        btn.addSubview(hStack)
        hStack.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            hStack.leadingAnchor.constraint(equalTo: btn.leadingAnchor, constant: 8),
            hStack.trailingAnchor.constraint(equalTo: btn.trailingAnchor, constant: -8),
            hStack.topAnchor.constraint(equalTo: btn.topAnchor, constant: 4),
            hStack.bottomAnchor.constraint(equalTo: btn.bottomAnchor, constant: -4)
        ])
        
        return btn
    }

    // MARK: - 设置图片
    func setImage(data: Data?, source: ImageSource) {
        parent?.debugLog("\n=== setImage 被调用 ===")
        parent?.debugLog("data: \(data == nil ? "nil" : "\(data!.count) bytes")")
        
        guard let data = data, let img = NSImage(data: data) else {
            parent?.debugLog("❌ 数据为空或 NSImage 创建失败")
            infoLabel.stringValue = "❌ 无法解析为图片 (base64 无效或格式错误)"
            currentData = nil
            imageView.image = nil
            flashWindow(red: true)
            return
        }

        parent?.debugLog("✅ NSImage 创建成功: \(img.size.width)×\(img.size.height)")
        currentData = data
        currentSource = source
        imageView.image = img

        let sizeStr: String
        if data.count < 1024 { sizeStr = "\(data.count) B" }
        else { sizeStr = String(format: "%.1f KB", Double(data.count) / 1024) }

        let sourceStr: String
        switch source {
        case .clipboard(let raw):
            let len = min(raw.count, 60)
            let preview = raw.prefix(len) + (raw.count > len ? "…" : "")
            sourceStr = "剪贴板 · \(raw.count)字符 · \(preview)"
        case .drag(let raw):
            sourceStr = "拖入 · \(raw.count)字符"
        case .file(let url):
            sourceStr = "文件 · \(url.lastPathComponent)"
        }

        infoLabel.stringValue = "✅ \(Int(img.size.width))×\(Int(img.size.height)) · \(sizeStr) · \(sourceStr)"
        currentData = data
        flashWindow(red: false)
    }

    func flashWindow(red: Bool) {
        window?.contentView?.layer?.backgroundColor =
            red ? NSColor.systemRed.withAlphaComponent(0.1).cgColor
                : NSColor.windowBackgroundColor.cgColor
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [weak self] in
            self?.window?.contentView?.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor
        }
    }

    // MARK: - Toolbar actions
    @objc func loadFromClipboard() {
        let pb = NSPasteboard.general
        guard let str = pb.string(forType: .string) else {
            infoLabel.stringValue = "❌ 剪贴板为空"
            print("❌ 剪贴板为空")
            return
        }
        print("✅ 从剪贴板读取到 \(str.count) 字符")
        print("前100字符: \(str.prefix(100))")
        guard let data = parent?.decodeBase64(str) else {
            infoLabel.stringValue = "❌ 无法解码 base64"
            print("❌ 解码失败")
            return
        }
        print("✅ 解码成功, 数据大小: \(data.count) bytes")
        setImage(data: data, source: .clipboard(str))
    }

    @objc func copyPNG() {
        guard let data = currentData, let img = NSImage(data: data) else {
            NSSound.beep(); return
        }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.writeObjects([img])
        showInfoShort("🖼 PNG 已复制到剪贴板")
    }

    @objc func copyB64() {
        guard let data = currentData else { NSSound.beep(); return }
        let b64 = data.base64EncodedString()
        let output = "data:image/png;base64,\(b64)"
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(output, forType: .string)
        showInfoShort("🔤 base64 已复制 (\(b64.count) 字符)")
    }

    @objc func saveFile() {
        guard let data = currentData else { NSSound.beep(); return }
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.png]
        panel.nameFieldStringValue = "PicBase64_\(Int(Date().timeIntervalSince1970)).png"
        panel.begin { response in
            if response == .OK, let url = panel.url {
                do {
                    try data.write(to: url)
                    self.showInfoShort("💾 已保存到: \(url.lastPathComponent)")
                } catch {
                    self.infoLabel.stringValue = "❌ 保存失败: \(error)"
                }
            }
        }
    }

    @objc func clearAll() {
        currentData = nil
        imageView.image = nil
        infoLabel.stringValue = "已清空"
    }

    func showInfoShort(_ s: String) {
        let old = infoLabel.stringValue
        infoLabel.stringValue = s
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
            if self?.infoLabel.stringValue == s { self?.infoLabel.stringValue = old }
        }
    }

    // MARK: - 拖拽接收（通过 NSWindow 转发）
    func window(_ w: NSWindow, prepareForDragOperation info: NSDraggingInfo) -> Bool { true }

    func window(_ w: NSWindow, performDragOperation info: NSDraggingInfo) -> Bool {
        let pb = info.draggingPasteboard
        if let s = pb.string(forType: .string), let data = parent?.decodeBase64(s) {
            setImage(data: data, source: .drag(s))
            return true
        }
        if let urls = pb.readObjects(forClasses: [NSURL.self], options: [.urlReadingContentsConformToTypes: [UTType.png.identifier]]) as? [URL],
           let url = urls.first, let data = try? Data(contentsOf: url) {
            setImage(data: data, source: .file(url))
            return true
        }
        flashWindow(red: true)
        return false
    }
}

import UniformTypeIdentifiers

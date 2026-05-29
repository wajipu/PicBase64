import AppKit

class SettingsWindowController: NSWindowController, NSWindowDelegate {
    weak var parent: AppDelegate?
    
    // UI elements
    var formatPopup: NSPopUpButton!
    var saveDesktopToggle: NSSwitch!
    var shortcutPopup: NSPopUpButton!
    var launchAtLoginToggle: NSSwitch!
    var soundToggle: NSSwitch!
    
    init(parent: AppDelegate) {
        self.parent = parent
        let frame = NSRect(x: 0, y: 0, width: 560, height: 480)
        let window = NSWindow(contentRect: frame,
                              styleMask: [.titled, .closable],
                              backing: .buffered, defer: false)
        window.title = "PicBase64 · 设置"
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
        
        let margin: CGFloat = 24
        let sectionSpacing: CGFloat = 20
        
        // 主容器
        let mainStack = NSStackView()
        mainStack.orientation = .vertical
        mainStack.spacing = sectionSpacing
        mainStack.alignment = .leading
        cv.addSubview(mainStack)
        mainStack.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            mainStack.topAnchor.constraint(equalTo: cv.topAnchor, constant: margin),
            mainStack.leadingAnchor.constraint(equalTo: cv.leadingAnchor, constant: margin),
            mainStack.trailingAnchor.constraint(equalTo: cv.trailingAnchor, constant: -margin),
            mainStack.bottomAnchor.constraint(equalTo: cv.bottomAnchor, constant: -margin)
        ])
        
        // 标题
        let titleLabel = sectionTitle("PicBase64 设置")
        mainStack.addArrangedSubview(titleLabel)
        
        // 分隔线
        mainStack.addArrangedSubview(separator())
        
        // Section 1: 输出格式
        mainStack.addArrangedSubview(sectionHeader(icon: "file-text", title: "输出格式"))
        mainStack.addArrangedSubview(createFormatRow())
        
        mainStack.addArrangedSubview(separator())
        
        // Section 2: 保存选项
        mainStack.addArrangedSubview(sectionHeader(icon: "save", title: "保存选项"))
        mainStack.addArrangedSubview(createSaveRow())
        
        mainStack.addArrangedSubview(separator())
        
        // Section 3: 快捷键
        mainStack.addArrangedSubview(sectionHeader(icon: "keyboard", title: "快捷键"))
        mainStack.addArrangedSubview(createShortcutRow())
        
        mainStack.addArrangedSubview(separator())
        
        // Section 4: 启动与反馈
        mainStack.addArrangedSubview(sectionHeader(icon: "zap", title: "启动与反馈"))
        mainStack.addArrangedSubview(createStartupRow())
        mainStack.addArrangedSubview(createSoundRow())
        
        // 底部按钮
        let spacer = NSView()
        spacer.setContentHuggingPriority(.defaultLow, for: .vertical)
        mainStack.addArrangedSubview(spacer)
        
        let buttonStack = NSStackView()
        buttonStack.orientation = .horizontal
        buttonStack.spacing = 8
        
        let versionLabel = NSTextField(labelWithString: "v3.0 · Lucide Icons")
        versionLabel.font = .systemFont(ofSize: 11)
        versionLabel.textColor = .tertiaryLabelColor
        buttonStack.addArrangedSubview(versionLabel)
        
        let spacer2 = NSView()
        buttonStack.addArrangedSubview(spacer2)
        
        let aboutBtn = iconButton(icon: "info", title: "关于") { [weak self] in
            self?.showAbout()
        }
        let doneBtn = iconButton(icon: "check", title: "完成", primary: true) { [weak self] in
            self?.window?.close()
        }
        buttonStack.addArrangedSubview(aboutBtn)
        buttonStack.addArrangedSubview(doneBtn)
        
        mainStack.addArrangedSubview(buttonStack)
    }
    
    // MARK: - UI Builders
    
    func sectionTitle(_ text: String) -> NSView {
        let label = NSTextField(labelWithString: text)
        label.font = .systemFont(ofSize: 18, weight: .semibold)
        return label
    }
    
    func sectionHeader(icon: String, title: String) -> NSView {
        let stack = NSStackView()
        stack.orientation = .horizontal
        stack.spacing = 6
        stack.alignment = .centerY
        
        if let iconImage = IconManager.shared.icon(icon, size: 14) {
            let iv = NSImageView(image: iconImage)
            iv.widthAnchor.constraint(equalToConstant: 14).isActive = true
            iv.heightAnchor.constraint(equalToConstant: 14).isActive = true
            stack.addArrangedSubview(iv)
        }
        
        let label = NSTextField(labelWithString: title)
        label.font = .systemFont(ofSize: 13, weight: .medium)
        stack.addArrangedSubview(label)
        return stack
    }
    
    func separator() -> NSView {
        let sep = NSBox()
        sep.boxType = .separator
        return sep
    }
    
    func createFormatRow() -> NSView {
        return settingRow(
            label: "复制时的格式",
            description: "选择截图后生成 Base64 的输出格式",
            control: { [weak self] in
                let popup = NSPopUpButton(frame: NSRect(x: 0, y: 0, width: 240, height: 24))
                popup.addItem(withTitle: "data:image URL (推荐)")
                popup.addItem(withTitle: "纯 Base64")
                popup.addItem(withTitle: "Markdown ![](...)")
                popup.addItem(withTitle: "JSON {\"data\":\"...\"}")
                
                let format = self?.parent?.format ?? .dataURL
                switch format {
                case .dataURL: popup.selectItem(at: 0)
                case .raw: popup.selectItem(at: 1)
                case .markdown: popup.selectItem(at: 2)
                case .json: popup.selectItem(at: 3)
                }
                
                popup.target = self
                popup.action = #selector(self?.formatChanged(_:))
                self?.formatPopup = popup
                return popup
            }()
        )
    }
    
    func createSaveRow() -> NSView {
        return settingRow(
            label: "同时保存到桌面",
            description: "截图后自动保存 PNG 文件到桌面",
            control: { [weak self] in
                let sw = NSSwitch()
                sw.state = (self?.parent?.saveToDesktop ?? false) ? .on : .off
                sw.target = self
                sw.action = #selector(self?.saveChanged(_:))
                self?.saveDesktopToggle = sw
                return sw
            }()
        )
    }
    
    func createShortcutRow() -> NSView {
        return settingRow(
            label: "读取 Base64 快捷键",
            description: "按下快捷键打开图片预览窗口",
            control: { [weak self] in
                let popup = NSPopUpButton(frame: NSRect(x: 0, y: 0, width: 160, height: 24))
                popup.addItem(withTitle: "⌥V")
                popup.addItem(withTitle: "⌥B")
                popup.addItem(withTitle: "⌥R")
                popup.addItem(withTitle: "⌥P")
                popup.selectItem(at: 0)
                popup.target = self
                popup.action = #selector(self?.shortcutChanged(_:))
                self?.shortcutPopup = popup
                return popup
            }()
        )
    }
    
    func createStartupRow() -> NSView {
        return settingRow(
            label: "开机自动启动",
            description: "登录系统时自动运行 PicBase64",
            control: { [weak self] in
                let sw = NSSwitch()
                sw.state = UserDefaults.standard.bool(forKey: "launchAtLogin") ? .on : .off
                sw.target = self
                sw.action = #selector(self?.launchChanged(_:))
                self?.launchAtLoginToggle = sw
                return sw
            }()
        )
    }
    
    func createSoundRow() -> NSView {
        return settingRow(
            label: "提示音",
            description: "截图成功后播放提示音",
            control: { [weak self] in
                let sw = NSSwitch()
                sw.state = UserDefaults.standard.object(forKey: "soundEnabled") as? Bool ?? true ? .on : .off
                sw.target = self
                sw.action = #selector(self?.soundChanged(_:))
                self?.soundToggle = sw
                return sw
            }()
        )
    }
    
    func settingRow(label: String, description: String, control: NSView) -> NSView {
        let row = NSStackView()
        row.orientation = .horizontal
        row.spacing = 12
        row.alignment = .top
        
        // 左侧文本
        let leftStack = NSStackView()
        leftStack.orientation = .vertical
        leftStack.alignment = .leading
        leftStack.spacing = 2
        
        let titleLabel = NSTextField(labelWithString: label)
        titleLabel.font = .systemFont(ofSize: 13, weight: .regular)
        leftStack.addArrangedSubview(titleLabel)
        
        let descLabel = NSTextField(wrappingLabelWithString: description)
        descLabel.font = .systemFont(ofSize: 11)
        descLabel.textColor = .secondaryLabelColor
        descLabel.maximumNumberOfLines = 2
        leftStack.addArrangedSubview(descLabel)
        
        row.addArrangedSubview(leftStack)
        leftStack.setContentHuggingPriority(.defaultLow, for: .horizontal)
        
        // 控件
        control.setContentHuggingPriority(.required, for: .horizontal)
        row.addArrangedSubview(control)
        
        return row
    }
    
    func iconButton(icon: String, title: String, primary: Bool = false, action: @escaping () -> Void) -> NSButton {
        let btn = NSButton(title: title, target: self, action: #selector(buttonAction(_:)))
        btn.bezelStyle = .rounded
        btn.controlSize = .regular
        
        if let img = IconManager.shared.icon(icon, size: 14) {
            btn.image = img
            btn.imagePosition = .imageLeading
        }
        
        if primary {
            btn.keyEquivalent = "\r"
        }
        
        objc_setAssociatedObject(btn, "action", action, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        btn.target = self
        btn.action = #selector(buttonAction(_:))
        return btn
    }
    
    // MARK: - Actions
    
    @objc func buttonAction(_ sender: NSButton) {
        if let action = objc_getAssociatedObject(sender, "action") as? () -> Void {
            action()
        }
    }
    
    @objc func formatChanged(_ sender: NSPopUpButton) {
        let formats: [OutputFormat] = [.dataURL, .raw, .markdown, .json]
        let idx = sender.indexOfSelectedItem
        guard idx >= 0, idx < formats.count else { return }
        parent?.format = formats[idx]
        UserDefaults.standard.set(formats[idx].rawValue, forKey: "outputFormat")
    }
    
    @objc func saveChanged(_ sender: NSSwitch) {
        let on = sender.state == .on
        parent?.saveToDesktop = on
        UserDefaults.standard.set(on, forKey: "saveToDesktop")
    }
    
    @objc func shortcutChanged(_ sender: NSPopUpButton) {
        UserDefaults.standard.set(sender.titleOfSelectedItem ?? "⌥V", forKey: "previewShortcut")
    }
    
    @objc func launchChanged(_ sender: NSSwitch) {
        let on = sender.state == .on
        UserDefaults.standard.set(on, forKey: "launchAtLogin")
        // TODO: 接入 SMAppService
    }
    
    @objc func soundChanged(_ sender: NSSwitch) {
        UserDefaults.standard.set(sender.state == .on, forKey: "soundEnabled")
    }
    
    func showAbout() {
        let info = NSLocalizedString("about_text", comment: "")
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "3.0"
        
        let alert = NSAlert()
        alert.messageText = String(format: NSLocalizedString("about_title", comment: ""), version)
        alert.informativeText = info
        alert.alertStyle = .informational
        alert.addButton(withTitle: NSLocalizedString("ok", comment: ""))
        alert.runModal()
    }
}

import ObjectiveC

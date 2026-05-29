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
        window.title = "PicBase64 · \(L("settings_title"))"
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
        let titleLabel = sectionTitle(L("settings_heading"))
        mainStack.addArrangedSubview(titleLabel)
        
        // 分隔线
        mainStack.addArrangedSubview(separator())
        
        mainStack.addArrangedSubview(sectionHeader(icon: "file-text", title: L("section_output")))
        mainStack.addArrangedSubview(createFormatRow())
        
        mainStack.addArrangedSubview(separator())
        
        mainStack.addArrangedSubview(sectionHeader(icon: "save", title: L("section_save")))
        mainStack.addArrangedSubview(createSaveRow())
        
        mainStack.addArrangedSubview(separator())
        
        mainStack.addArrangedSubview(sectionHeader(icon: "keyboard", title: L("section_shortcut")))
        mainStack.addArrangedSubview(createShortcutRow())
        
        mainStack.addArrangedSubview(separator())
        
        mainStack.addArrangedSubview(sectionHeader(icon: "zap", title: L("section_startup")))
        mainStack.addArrangedSubview(createStartupRow())
        mainStack.addArrangedSubview(createSoundRow())
        
        // 底部按钮
        let spacer = NSView()
        spacer.setContentHuggingPriority(.defaultLow, for: .vertical)
        mainStack.addArrangedSubview(spacer)
        
        let buttonStack = NSStackView()
        buttonStack.orientation = .horizontal
        buttonStack.spacing = 8
        
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "3.2"
        let versionLabel = NSTextField(labelWithString: "v\(version) · Lucide Icons")
        versionLabel.font = .systemFont(ofSize: 11)
        versionLabel.textColor = .tertiaryLabelColor
        buttonStack.addArrangedSubview(versionLabel)
        
        let spacer2 = NSView()
        buttonStack.addArrangedSubview(spacer2)
        
        let aboutBtn = iconButton(icon: "info", title: L("about_button")) { [weak self] in
            self?.showAbout()
        }
        let doneBtn = iconButton(icon: "check", title: L("done"), primary: true) { [weak self] in
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
            label: L("label_output_format"),
            description: L("desc_output_format"),
            control: { [weak self] in
                let popup = NSPopUpButton(frame: NSRect(x: 0, y: 0, width: 240, height: 24))
                popup.addItem(withTitle: L("format_data_url"))
                popup.addItem(withTitle: L("format_raw_base64"))
                popup.addItem(withTitle: L("format_markdown"))
                popup.addItem(withTitle: L("format_json"))
                
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
            label: L("label_save_to_desktop"),
            description: L("desc_save_to_desktop"),
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
            label: L("label_shortcut"),
            description: L("desc_shortcut"),
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
            label: L("label_launch_at_login"),
            description: L("desc_launch_at_login"),
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
            label: L("label_sound"),
            description: L("desc_sound"),
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

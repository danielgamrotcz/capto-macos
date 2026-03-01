import AppKit
import ServiceManagement
import Sparkle
import SwiftUI

// ctrl+opt+cmd = controlKey(0x1000) | optionKey(0x0800) | cmdKey(0x0100)
let defaultShortcutKeyCode = 34  // kVK_ANSI_I
let defaultShortcutModifiers = 0x1900  // ctrl+opt+cmd

final class AppDelegate: NSObject, NSApplicationDelegate {
    static private(set) var shared: AppDelegate!

    private var panel: FloatingPanel!
    private var settingsPanel: FloatingPanel!
    private var hotkey: GlobalHotkey?
    private var settingsEscapeMonitor: Any?
    private let updaterController = SPUStandardUpdaterController(
        startingUpdater: true, updaterDelegate: nil, userDriverDelegate: nil
    )

    func applicationDidFinishLaunching(_ notification: Notification) {
        AppDelegate.shared = self

        migrateUserDefaults()

        // Clean up cached SwiftUI Settings window frame to prevent ghost title-bar window
        UserDefaults.standard.removeObject(forKey: "NSWindow Frame com_apple_SwiftUI_Settings_window")

        setupMainMenu()
        setupMainPanel()
        setupSettingsPanel()
        registerHotkey()
        enableLaunchAtLoginOnFirstRun()
        AccessibilityHelper.promptIfNeeded()

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(hotkeySettingsChanged),
            name: .hotkeySettingsChanged,
            object: nil
        )
    }

    // MARK: - Main Menu

    private func setupMainMenu() {
        let mainMenu = NSMenu()

        // App menu
        let appMenuItem = NSMenuItem()
        let appMenu = NSMenu()
        appMenu.addItem(withTitle: "Zkontrolovat aktualizace…", action: #selector(checkForUpdatesAction), keyEquivalent: "")
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: "Nastavení…", action: #selector(openSettingsAction), keyEquivalent: ",")
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: "Ukončit Capto", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        appMenuItem.submenu = appMenu
        mainMenu.addItem(appMenuItem)

        // Edit menu (needed for text fields: cut/copy/paste)
        let editMenuItem = NSMenuItem()
        let editMenu = NSMenu(title: "Edit")
        editMenu.addItem(withTitle: "Undo", action: Selector(("undo:")), keyEquivalent: "z")
        editMenu.addItem(withTitle: "Redo", action: Selector(("redo:")), keyEquivalent: "Z")
        editMenu.addItem(.separator())
        editMenu.addItem(withTitle: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        editMenu.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        editMenu.addItem(withTitle: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        editMenu.addItem(withTitle: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        editMenuItem.submenu = editMenu
        mainMenu.addItem(editMenuItem)

        NSApp.mainMenu = mainMenu
    }

    @objc private func checkForUpdatesAction() {
        updaterController.checkForUpdates(nil)
    }

    @objc private func openSettingsAction() {
        showSettings()
    }

    // MARK: - Main Panel Setup

    private func setupMainPanel() {
        panel = FloatingPanel()
        let hostingView = NSHostingView(rootView: NoteInputView())
        hostingView.translatesAutoresizingMaskIntoConstraints = false
        panel.contentView?.addSubview(hostingView)

        if let contentView = panel.contentView {
            NSLayoutConstraint.activate([
                hostingView.topAnchor.constraint(equalTo: contentView.topAnchor),
                hostingView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
                hostingView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
                hostingView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            ])
        }
    }

    // MARK: - Settings Panel Setup

    private func setupSettingsPanel() {
        settingsPanel = FloatingPanel(
            size: NSSize(width: 480, height: 500),
            hidesOnDeactivate: false
        )
        let hostingView = NSHostingView(rootView: SettingsView())
        hostingView.translatesAutoresizingMaskIntoConstraints = false
        settingsPanel.contentView?.addSubview(hostingView)

        if let contentView = settingsPanel.contentView {
            NSLayoutConstraint.activate([
                hostingView.topAnchor.constraint(equalTo: contentView.topAnchor),
                hostingView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
                hostingView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
                hostingView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            ])
        }
    }

    // MARK: - Hotkey

    private func registerHotkey() {
        let defaults = UserDefaults.standard
        let keyCode = UInt32(defaults.integer(forKey: "shortcutKeyCode"))
        let modifiers = UInt32(defaults.integer(forKey: "shortcutModifiers"))

        // integer(forKey:) returns 0 when key is missing — use defaults
        let finalKeyCode = keyCode != 0 ? keyCode : UInt32(defaultShortcutKeyCode)
        let finalModifiers = modifiers != 0 ? modifiers : UInt32(defaultShortcutModifiers)

        hotkey = GlobalHotkey(
            keyCode: finalKeyCode,
            modifiers: finalModifiers,
            handler: { [weak self] in
                DispatchQueue.main.async { self?.togglePanel() }
            }
        )
        hotkey?.register()
    }

    @objc private func hotkeySettingsChanged() {
        hotkey?.unregister()
        hotkey = nil
        registerHotkey()
    }

    // MARK: - Main Panel

    func togglePanel() {
        if panel.isVisible {
            hidePanel()
        } else {
            showPanel()
        }
    }

    func showPanel() {
        centerPanel(panel)
        panel.alphaValue = 0
        panel.orderFrontRegardless()
        panel.makeKey()
        NSApp.activate(ignoringOtherApps: true)

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.15
            panel.animator().alphaValue = 1
        }
    }

    func hidePanel() {
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.15
            panel.animator().alphaValue = 0
        }, completionHandler: { [weak self] in
            self?.panel.orderOut(nil)
        })
    }

    // MARK: - Settings Panel

    func showSettings() {
        centerPanel(settingsPanel)
        settingsPanel.alphaValue = 0
        settingsPanel.orderFrontRegardless()
        settingsPanel.makeKey()
        NSApp.activate(ignoringOtherApps: true)

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.15
            settingsPanel.animator().alphaValue = 1
        }

        settingsEscapeMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self, self.settingsPanel.isKeyWindow else { return event }
            if event.keyCode == 53 { // Escape
                self.hideSettings()
                return nil
            }
            return event
        }
    }

    func hideSettings() {
        if let monitor = settingsEscapeMonitor {
            NSEvent.removeMonitor(monitor)
            settingsEscapeMonitor = nil
        }

        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.15
            settingsPanel.animator().alphaValue = 0
        }, completionHandler: { [weak self] in
            self?.settingsPanel.orderOut(nil)
        })
    }

    // MARK: - Submit

    func submitNote(text: String) {
        Task {
            do {
                try await NoteService.shared.saveNote(text: text)
                await MainActor.run {
                    NotificationCenter.default.post(name: .noteSubmitted, object: nil)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                        self.hidePanel()
                    }
                }
            } catch {
                await MainActor.run {
                    NotificationCenter.default.post(
                        name: .noteSubmitFailed, object: nil,
                        userInfo: ["error": error.localizedDescription]
                    )
                }
            }
        }
    }

    private func enableLaunchAtLoginOnFirstRun() {
        let key = "hasEnabledLaunchAtLogin"
        guard !UserDefaults.standard.bool(forKey: key) else { return }
        UserDefaults.standard.set(true, forKey: key)
        try? SMAppService.mainApp.register()
    }

    private func migrateUserDefaults() {
        let current = UserDefaults.standard
        guard !current.bool(forKey: "didMigrateFromQuickNote") else { return }

        if let old = UserDefaults(suiteName: "com.danielgamrot.QuickNote") {
            let keys = ["notionToken", "notionPageId", "shortcutKeyCode", "shortcutModifiers", "hasEnabledLaunchAtLogin"]
            for key in keys {
                if let value = old.object(forKey: key), current.object(forKey: key) == nil {
                    current.set(value, forKey: key)
                }
            }
        }

        current.set(true, forKey: "didMigrateFromQuickNote")
    }

    private func centerPanel(_ targetPanel: NSPanel) {
        guard let screen = NSScreen.main else { return }
        let screenFrame = screen.visibleFrame
        let panelSize = targetPanel.frame.size
        let x = screenFrame.midX - panelSize.width / 2
        let y = screenFrame.midY - panelSize.height / 2
        targetPanel.setFrameOrigin(NSPoint(x: x, y: y))
    }
}

// MARK: - Notifications

extension Notification.Name {
    static let hotkeySettingsChanged = Notification.Name("hotkeySettingsChanged")
    static let noteSubmitted = Notification.Name("noteSubmitted")
    static let noteSubmitFailed = Notification.Name("noteSubmitFailed")
static let transcriptUpdate = Notification.Name("transcriptUpdate")
}

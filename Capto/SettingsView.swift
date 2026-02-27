import ServiceManagement
import SwiftUI

struct SettingsView: View {
    @AppStorage("shortcutKeyCode") private var keyCode: Int = defaultShortcutKeyCode
    @AppStorage("shortcutModifiers") private var modifiers: Int = defaultShortcutModifiers
    @AppStorage("sonioxApiKey") private var sonioxApiKey = ""
    @AppStorage("anthropicApiKey") private var anthropicApiKey = ""

    @AppStorage("notesFolderPath") private var notesFolderPath = ""

    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled
    @State private var accessibilityGranted = AccessibilityHelper.isTrusted
    @State private var showSonioxKey = false
    @State private var showAnthropicKey = false

    private let accessibilityTimer = Timer.publish(every: 2, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 16) {
                    generalSection
                    saveLocationSection
                    sonioxSection
                    anthropicSection
                    if !accessibilityGranted {
                        accessibilitySection
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 8)
            }

            Divider()
                .padding(.horizontal, 16)

            bottomBar
        }
        .frame(width: 480, height: accessibilityGranted ? 560 : 630)
        .background {
            VisualEffectBackground()
        }
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .onReceive(accessibilityTimer) { _ in
            accessibilityGranted = AccessibilityHelper.isTrusted
        }
    }

    // MARK: - Bottom Bar

    private var bottomBar: some View {
        HStack {
            Spacer()
            Text("Esc Zavřít")
                .font(.system(size: 11))
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }

    // MARK: - General

    private var generalSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Obecné")
                .font(.headline)
                .foregroundStyle(.secondary)
                .padding(.bottom, 8)

            VStack(spacing: 0) {
                settingsRow {
                    Text("Spustit při přihlášení")
                    Spacer()
                    Toggle("", isOn: $launchAtLogin)
                        .toggleStyle(.switch)
                        .labelsHidden()
                        .onChange(of: launchAtLogin) { _, newValue in
                            do {
                                if newValue {
                                    try SMAppService.mainApp.register()
                                } else {
                                    try SMAppService.mainApp.unregister()
                                }
                            } catch {
                                launchAtLogin = SMAppService.mainApp.status == .enabled
                            }
                        }
                }

                Divider()
                    .padding(.horizontal, 12)

                settingsRow {
                    Text("Klávesová zkratka")
                    Spacer()
                    ShortcutRecorder(
                        keyCode: Binding(
                            get: { UInt32(keyCode) },
                            set: {
                                keyCode = Int($0)
                                NotificationCenter.default.post(name: .hotkeySettingsChanged, object: nil)
                            }
                        ),
                        modifiers: Binding(
                            get: { UInt32(modifiers) },
                            set: {
                                modifiers = Int($0)
                                NotificationCenter.default.post(name: .hotkeySettingsChanged, object: nil)
                            }
                        )
                    )
                    .frame(width: 160, height: 26)
                }
            }
            .background(Color.primary.opacity(0.06))
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
    }

    // MARK: - Save Location

    private var saveLocationSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Úložiště")
                .font(.headline)
                .foregroundStyle(.secondary)
                .padding(.bottom, 8)

            VStack(spacing: 0) {
                settingsRow {
                    Text("Složka")
                        .frame(width: 120, alignment: .leading)
                    Text(notesFolderDisplayPath)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.head)
                    Spacer()
                    Button("Otevřít") {
                        NSWorkspace.shared.open(FileNoteService.shared.saveDirectory)
                    }
                    Button("Změnit") {
                        chooseFolder()
                    }
                }
            }
            .background(Color.primary.opacity(0.06))
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

            Text("Poznámky se ukládají jako Markdown soubory s AI-generovaným názvem.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .padding(.top, 6)
                .padding(.horizontal, 4)
        }
    }

    // MARK: - Soniox

    private var sonioxSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Soniox")
                .font(.headline)
                .foregroundStyle(.secondary)
                .padding(.bottom, 8)

            VStack(spacing: 0) {
                settingsRow {
                    Text("API Key")
                        .frame(width: 120, alignment: .leading)
                    HStack(spacing: 6) {
                        Group {
                            if showSonioxKey {
                                TextField("sk-...", text: $sonioxApiKey)
                            } else {
                                SecureField("sk-...", text: $sonioxApiKey)
                            }
                        }
                        .textFieldStyle(.roundedBorder)

                        Button {
                            showSonioxKey.toggle()
                        } label: {
                            Image(systemName: showSonioxKey ? "eye.slash" : "eye")
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.borderless)
                    }
                }
            }
            .background(Color.primary.opacity(0.06))
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

            Text("Přepis hlasu se spustí podržením pravého ⌥ v okně pro psaní poznámky.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .padding(.top, 6)
                .padding(.horizontal, 4)
        }
    }

    // MARK: - Anthropic

    private var anthropicSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Anthropic")
                .font(.headline)
                .foregroundStyle(.secondary)
                .padding(.bottom, 8)

            VStack(spacing: 0) {
                settingsRow {
                    Text("API Key")
                        .frame(width: 120, alignment: .leading)
                    HStack(spacing: 6) {
                        Group {
                            if showAnthropicKey {
                                TextField("sk-ant-...", text: $anthropicApiKey)
                            } else {
                                SecureField("sk-ant-...", text: $anthropicApiKey)
                            }
                        }
                        .textFieldStyle(.roundedBorder)

                        Button {
                            showAnthropicKey.toggle()
                        } label: {
                            Image(systemName: showAnthropicKey ? "eye.slash" : "eye")
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.borderless)
                    }
                }
            }
            .background(Color.primary.opacity(0.06))
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

            Text("Generuje AI titulek poznámky (5-7 slov). Bez klíče se použije začátek textu.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .padding(.top, 6)
                .padding(.horizontal, 4)
        }
    }

    // MARK: - Accessibility

    private var accessibilitySection: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(spacing: 0) {
                settingsRow {
                    Label("Klávesová zkratka vyžaduje oprávnění Accessibility.", systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)

                    Spacer()

                    Button("Povolit") {
                        AccessibilityHelper.promptIfNeeded()
                    }
                }
            }
            .background(Color.primary.opacity(0.06))
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
    }

    // MARK: - Helpers

    private var notesFolderDisplayPath: String {
        let url = FileNoteService.shared.saveDirectory
        let home = NSHomeDirectory()
        let path = url.path
        if path.hasPrefix(home) {
            return "~" + path.dropFirst(home.count)
        }
        return path
    }

    private func chooseFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = true
        panel.directoryURL = FileNoteService.shared.saveDirectory
        panel.prompt = "Vybrat"
        panel.message = "Vyber složku pro ukládání poznámek"

        if panel.runModal() == .OK, let url = panel.url {
            notesFolderPath = url.path
        }
    }

    private func settingsRow<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        HStack {
            content()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }

}

import ServiceManagement
import SwiftUI

struct SettingsView: View {
    @AppStorage("notionToken") private var token = ""
    @AppStorage("notionPageId") private var pageId = ""
    @AppStorage("shortcutKeyCode") private var keyCode: Int = defaultShortcutKeyCode
    @AppStorage("shortcutModifiers") private var modifiers: Int = defaultShortcutModifiers

    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled
    @State private var accessibilityGranted = AccessibilityHelper.isTrusted
    @State private var connectionStatus: ConnectionStatus = .idle
    @State private var showToken = false

    private let accessibilityTimer = Timer.publish(every: 2, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 16) {
                    generalSection
                    notionSection
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
        .frame(width: 480, height: accessibilityGranted ? 380 : 450)
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

    // MARK: - Notion

    private var notionSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Notion")
                .font(.headline)
                .foregroundStyle(.secondary)
                .padding(.bottom, 8)

            VStack(spacing: 0) {
                settingsRow {
                    Text("Integration Token")
                        .frame(width: 120, alignment: .leading)
                    HStack(spacing: 6) {
                        Group {
                            if showToken {
                                TextField("secret_...", text: $token)
                            } else {
                                SecureField("secret_...", text: $token)
                            }
                        }
                        .textFieldStyle(.roundedBorder)

                        Button {
                            showToken.toggle()
                        } label: {
                            Image(systemName: showToken ? "eye.slash" : "eye")
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.borderless)
                    }
                }

                Divider()
                    .padding(.horizontal, 12)

                settingsRow {
                    Text("Page ID")
                        .frame(width: 120, alignment: .leading)
                    TextField("ID nebo URL stránky", text: $pageId)
                        .textFieldStyle(.roundedBorder)
                }

                Divider()
                    .padding(.horizontal, 12)

                settingsRow {
                    Button("Otestovat připojení") {
                        testConnection()
                    }
                    .disabled(token.isEmpty || pageId.isEmpty)

                    connectionStatusView

                    Spacer()
                }
            }
            .background(Color.primary.opacity(0.06))
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

            Text("Token vytvoříte na [notion.so/my-integrations](https://www.notion.so/my-integrations). Nezapomeňte stránku propojit s integrací.")
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

    private func settingsRow<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        HStack {
            content()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }

    // MARK: - Connection

    @ViewBuilder
    private var connectionStatusView: some View {
        switch connectionStatus {
        case .idle:
            EmptyView()
        case .testing:
            ProgressView()
                .controlSize(.small)
        case .success:
            Label("Připojeno", systemImage: "checkmark.circle.fill")
                .foregroundStyle(.green)
                .font(.callout)
        case .failure(let message):
            Label(message, systemImage: "xmark.circle.fill")
                .foregroundStyle(.red)
                .font(.callout)
                .lineLimit(1)
        }
    }

    private func testConnection() {
        connectionStatus = .testing
        Task {
            do {
                let ok = try await NotionService.shared.testConnection()
                connectionStatus = ok ? .success : .failure("Nelze se připojit")
            } catch {
                connectionStatus = .failure(error.localizedDescription)
            }
        }
    }
}

private enum ConnectionStatus {
    case idle, testing, success, failure(String)
}

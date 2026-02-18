import SwiftUI

struct NoteInputView: View {
    @State private var text = ""
    @State private var status: SubmitStatus = .idle
    @State private var pendingCount = 0
    @State private var recordingBaseText = ""

    var body: some View {
        VStack(spacing: 0) {
            NoteTextEditor(
                text: $text,
                onCommandReturn: { submit() },
                onEscape: {
                    if case .recording = status {
                        Task { _ = await SonioxService.shared.stopRecording() }
                    }
                    text = ""
                    status = .idle
                    recordingBaseText = ""
                    AppDelegate.shared.hidePanel()
                },
                onRightOptionDown: { handleRecordStart() },
                onRightOptionUp: { handleRecordStop() }
            )
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 8)

            Divider()
                .padding(.horizontal, 16)

            bottomBar
        }
        .frame(width: 480, height: 180)
        .background {
            VisualEffectBackground()
        }
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .onAppear {
            pendingCount = NoteQueue.shared.pendingCount
        }
        .onReceive(NotificationCenter.default.publisher(for: .noteSubmitted)) { _ in
            status = .success
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                text = ""
                status = .idle
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .noteQueued)) { _ in
            status = .queued
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                text = ""
                status = .idle
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .noteSubmitFailed)) { notification in
            let message = notification.userInfo?["error"] as? String ?? "Neznámá chyba"
            status = .error(message)
        }
        .onReceive(NotificationCenter.default.publisher(for: .pendingNotesChanged)) { _ in
            pendingCount = NoteQueue.shared.pendingCount
        }
        .onReceive(NotificationCenter.default.publisher(for: .transcriptUpdate)) { notification in
            let committed = notification.userInfo?["committed"] as? String ?? ""
            let pending = notification.userInfo?["pending"] as? String ?? ""
            let base = recordingBaseText
            let sep = base.isEmpty || base.hasSuffix(" ") || base.hasSuffix("\n") ? "" : " "
            text = base + sep + committed
            status = .recording(pending)
        }
    }

    private var isRecording: Bool {
        if case .recording = status { return true }
        return false
    }

    private var bottomBar: some View {
        HStack {
            statusText

            if pendingCount > 0 && status == .idle {
                HStack(spacing: 4) {
                    Circle()
                        .fill(.orange)
                        .frame(width: 6, height: 6)
                    Text("\(pendingCount) čeká na odeslání")
                        .font(.system(size: 11))
                        .foregroundStyle(.orange)
                }
            }

            Spacer()
            Text(isRecording ? "Uvolněte ⌥ pro dokončení" : "⌘↩ Odeslat  ·  Esc Zrušit")
                .font(.system(size: 11))
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }

    @ViewBuilder
    private var statusText: some View {
        switch status {
        case .idle:
            EmptyView()
        case .sending:
            HStack(spacing: 6) {
                ProgressView()
                    .controlSize(.small)
                Text("Odesílání...")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
        case .success:
            Label("Odesláno", systemImage: "checkmark.circle.fill")
                .font(.system(size: 11))
                .foregroundStyle(.green)
        case .queued:
            Label("Uloženo, odešle se automaticky", systemImage: "arrow.clockwise.circle.fill")
                .font(.system(size: 11))
                .foregroundStyle(.orange)
        case .error(let message):
            Text(message)
                .font(.system(size: 11))
                .foregroundStyle(.red)
                .lineLimit(1)
        case .recording(let partial):
            HStack(spacing: 6) {
                RecordingDot()
                Text(partial.isEmpty ? "Nahrávám..." : partial)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
    }

    // MARK: - Submit

    private func submit() {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        status = .sending
        AppDelegate.shared.submitNote(text: trimmed)
    }

    // MARK: - Recording

    private func handleRecordStart() {
        guard SonioxService.shared.isConfigured else {
            status = .error("Nastav Soniox API klíč v nastavení")
            return
        }
        recordingBaseText = text
        status = .recording("")
        Task {
            do {
                try await SonioxService.shared.startRecording()
            } catch {
                status = .error(error.localizedDescription)
            }
        }
    }

    private func handleRecordStop() {
        Task {
            let final = await SonioxService.shared.stopRecording()
            let base = recordingBaseText
            let sep = base.isEmpty || base.hasSuffix(" ") || base.hasSuffix("\n") ? "" : " "
            if !final.isEmpty {
                text = base + sep + final
            }
            status = .idle
        }
    }
}

private enum SubmitStatus: Equatable {
    case idle, sending, success, queued, error(String), recording(String)
}

// MARK: - Recording dot

private struct RecordingDot: View {
    @State private var pulse = false

    var body: some View {
        Circle()
            .fill(.red)
            .frame(width: 6, height: 6)
            .opacity(pulse ? 0.25 : 1.0)
            .onAppear {
                withAnimation(.easeInOut(duration: 0.7).repeatForever(autoreverses: true)) {
                    pulse = true
                }
            }
    }
}

// MARK: - Visual Effect Background

struct VisualEffectBackground: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = .hudWindow
        view.blendingMode = .behindWindow
        view.state = .active
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {}
}

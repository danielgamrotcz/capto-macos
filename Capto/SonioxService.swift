import AVFoundation
import Foundation

final class SonioxService {
    static let shared = SonioxService()

    private var webSocket: URLSessionWebSocketTask?
    private var audioEngine: AVAudioEngine?
    private var committedText = ""
    private var isActive = false
    private let urlSession = URLSession(configuration: .default)

    var isConfigured: Bool {
        !(UserDefaults.standard.string(forKey: "sonioxApiKey") ?? "").isEmpty
    }

    private var apiKey: String {
        UserDefaults.standard.string(forKey: "sonioxApiKey") ?? ""
    }

    private init() {}

    func startRecording() async throws {
        guard !apiKey.isEmpty else { throw SonioxError.missingApiKey }
        guard !isActive else { return }

        isActive = true
        committedText = ""

        let url = URL(string: "wss://stt-rt.soniox.com/transcribe-websocket")!
        webSocket = urlSession.webSocketTask(with: url)
        webSocket?.resume()

        let config: [String: Any] = [
            "api_key": apiKey,
            "model": "stt-rt-v4",
            "audio_format": "pcm_s16le",
            "sample_rate": 16000,
            "num_channels": 1,
            "language_hints": ["cs", "sk", "en"],
            "language_hints_strict": true,
            "enable_language_identification": true,
            "enable_endpoint_detection": false,
            "enable_non_final_tokens": true,
        ]
        let configJson = String(data: try JSONSerialization.data(withJSONObject: config), encoding: .utf8)!
        try await webSocket?.send(.string(configJson))

        startReceiving()
        try setupAudio()
    }

    func stopRecording() async -> String {
        guard isActive else { return "" }
        isActive = false

        audioEngine?.stop()
        audioEngine?.inputNode.removeTap(onBus: 0)
        audioEngine = nil

        if let socket = webSocket {
            try? await socket.send(.string(#"{"type":"finalize"}"#))
            try? await Task.sleep(nanoseconds: 700_000_000)
        }

        webSocket?.cancel(with: .normalClosure, reason: nil)
        webSocket = nil

        return committedText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Audio

    private func setupAudio() throws {
        let engine = AVAudioEngine()
        audioEngine = engine

        let inputNode = engine.inputNode
        let inputFormat = inputNode.outputFormat(forBus: 0)

        guard let targetFormat = AVAudioFormat(
            commonFormat: .pcmFormatInt16,
            sampleRate: 16000,
            channels: 1,
            interleaved: true
        ) else { throw SonioxError.audioSetupFailed }

        guard let converter = AVAudioConverter(from: inputFormat, to: targetFormat) else {
            throw SonioxError.audioSetupFailed
        }

        let tapFrames = AVAudioFrameCount(inputFormat.sampleRate * 0.05)
        inputNode.installTap(onBus: 0, bufferSize: tapFrames, format: inputFormat) { [weak self] buffer, _ in
            guard let self, self.isActive else { return }
            let ratio = 16000.0 / inputFormat.sampleRate
            let outFrames = AVAudioFrameCount(Double(buffer.frameLength) * ratio + 1)
            guard let outBuffer = AVAudioPCMBuffer(pcmFormat: targetFormat, frameCapacity: outFrames) else { return }

            var convError: NSError?
            let status = converter.convert(to: outBuffer, error: &convError) { _, outStatus in
                outStatus.pointee = .haveData
                return buffer
            }

            guard status != .error, convError == nil, outBuffer.frameLength > 0 else { return }

            let bytes = Data(bytes: outBuffer.int16ChannelData![0], count: Int(outBuffer.frameLength) * 2)
            Task { try? await self.webSocket?.send(.data(bytes)) }
        }

        try engine.start()
    }

    // MARK: - WebSocket receiving

    private func startReceiving() {
        Task {
            while let socket = webSocket {
                do {
                    let message = try await socket.receive()
                    if case .string(let json) = message {
                        processMessage(json)
                    }
                } catch {
                    break
                }
            }
        }
    }

    private func processMessage(_ json: String) {
        guard let data = json.data(using: .utf8),
              let response = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let tokens = response["tokens"] as? [[String: Any]] else { return }

        var newCommitted = ""
        var pending = ""

        for token in tokens {
            guard let text = token["text"] as? String else { continue }
            if token["is_final"] as? Bool == true {
                newCommitted += text
            } else {
                pending += text
            }
        }

        committedText += newCommitted
        DispatchQueue.main.async {
            NotificationCenter.default.post(
                name: .transcriptUpdate,
                object: nil,
                userInfo: ["committed": self.committedText, "pending": pending]
            )
        }
    }
}

enum SonioxError: LocalizedError {
    case missingApiKey, audioSetupFailed

    var errorDescription: String? {
        switch self {
        case .missingApiKey: return "Soniox API klíč není nastaven v nastavení"
        case .audioSetupFailed: return "Nepodařilo se spustit mikrofon"
        }
    }
}

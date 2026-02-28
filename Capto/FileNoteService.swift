import Foundation

enum FileNoteError: LocalizedError {
    case directoryCreationFailed
    case writeFailed(Error)

    var errorDescription: String? {
        switch self {
        case .directoryCreationFailed:
            return "Nelze vytvořit složku pro poznámky"
        case .writeFailed(let error):
            return "Chyba zápisu: \(error.localizedDescription)"
        }
    }
}

final class FileNoteService {
    static let shared = FileNoteService()

    private static let defaultDirectory = URL(
        fileURLWithPath: NSHomeDirectory()
    ).appendingPathComponent("Library/CloudStorage/GoogleDrive-daniel@gamrot.cz/Můj disk/Notero", isDirectory: true)

    var saveDirectory: URL {
        let custom = UserDefaults.standard.string(forKey: "notesFolderPath") ?? ""
        if custom.isEmpty {
            return Self.defaultDirectory
        }
        return URL(fileURLWithPath: custom)
    }

    private let session = URLSession.shared
    private let anthropicModel = "claude-haiku-4-5-20251001"

    private var anthropicApiKey: String {
        UserDefaults.standard.string(forKey: "anthropicApiKey") ?? ""
    }

    private init() {}

    func saveNote(text: String) async throws {
        try ensureDirectory()
        let title = await generateTitle(text: text)
        let fileName = buildFileName(title: title)
        let fileURL = saveDirectory.appendingPathComponent(fileName)

        let content = "# 💻 \(title)\n\n\(text)"
        do {
            try content.write(to: fileURL, atomically: true, encoding: .utf8)
        } catch {
            throw FileNoteError.writeFailed(error)
        }

        let notePath = fileName.replacingOccurrences(of: ".md", with: "")
        let noteTitle = "💻 \(title)"
        Task.detached {
            _ = await SupabaseService.shared.syncNote(
                path: notePath, title: noteTitle, content: content
            )
        }
    }

    // MARK: - File Naming

    private func buildFileName(title: String) -> String {
        let sanitized = sanitize(title)
        let base = "💻 \(sanitized)"

        if !FileManager.default.fileExists(atPath: saveDirectory.appendingPathComponent("\(base).md").path) {
            return "\(base).md"
        }

        for i in 2...99 {
            let candidate = "\(base) \(i).md"
            if !FileManager.default.fileExists(atPath: saveDirectory.appendingPathComponent(candidate).path) {
                return candidate
            }
        }

        return "\(base) \(UUID().uuidString.prefix(6)).md"
    }

    private func sanitize(_ name: String) -> String {
        let forbidden = CharacterSet(charactersIn: "/:\\?*\"<>|")
        return name.components(separatedBy: forbidden).joined()
    }

    private func ensureDirectory() throws {
        let fm = FileManager.default
        if !fm.fileExists(atPath: saveDirectory.path) {
            do {
                try fm.createDirectory(at: saveDirectory, withIntermediateDirectories: true)
            } catch {
                throw FileNoteError.directoryCreationFailed
            }
        }
    }

    // MARK: - Title Generation

    private func generateTitle(text: String) async -> String {
        guard !anthropicApiKey.isEmpty else {
            return fallbackTitle(text: text)
        }
        do {
            return try await callClaude(text: text)
        } catch {
            return fallbackTitle(text: text)
        }
    }

    private func callClaude(text: String) async throws -> String {
        let url = URL(string: "https://api.anthropic.com/v1/messages")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(anthropicApiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")

        let body: [String: Any] = [
            "model": anthropicModel,
            "max_tokens": 50,
            "system": "Shrň následující text do krátkého názvu o 5-7 slovech v češtině. Na konci nebude žádné interpunkční znaménko, ani tečka, ani čárka, ani vykřičník, ani otazník. Odpověz POUZE názvem, nic jiného.",
            "messages": [["role": "user", "content": text.trimmingCharacters(in: .whitespacesAndNewlines)]],
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw FileNoteError.writeFailed(
                NSError(domain: "FileNoteService", code: -1, userInfo: [
                    NSLocalizedDescriptionKey: "Claude API error"
                ])
            )
        }

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let content = json["content"] as? [[String: Any]],
              let title = content.first?["text"] as? String,
              !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return fallbackTitle(text: text)
        }

        return title.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func fallbackTitle(text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return "Voice note" }
        let words = trimmed.split(separator: " ", maxSplits: 7, omittingEmptySubsequences: true)
        if words.count <= 7 { return trimmed }
        return words.prefix(7).joined(separator: " ")
    }
}

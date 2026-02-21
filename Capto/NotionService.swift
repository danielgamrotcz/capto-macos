import Foundation

enum NotionError: LocalizedError {
    case invalidConfig
    case networkError(Error)
    case apiError(Int, String)

    var errorDescription: String? {
        switch self {
        case .invalidConfig:
            return "Notion token nebo Page ID není nastaven"
        case .networkError(let error):
            return "Chyba sítě: \(error.localizedDescription)"
        case .apiError(let code, let message):
            return "Notion API \(code): \(message)"
        }
    }
}

final class NotionService {
    static let shared = NotionService()
    private let session = URLSession.shared
    private let apiVersion = "2022-06-28"
    private let anthropicModel = "claude-haiku-4-5-20251001"

    private var token: String {
        UserDefaults.standard.string(forKey: "notionToken") ?? ""
    }

    private var pageId: String {
        UserDefaults.standard.string(forKey: "notionPageId") ?? ""
    }

    private var anthropicApiKey: String {
        UserDefaults.standard.string(forKey: "anthropicApiKey") ?? ""
    }

    private init() {}

    private func czechTimestamp() -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "cs_CZ")
        formatter.timeZone = TimeZone.current
        formatter.dateFormat = "d. M. yyyy, HH:mm"
        return formatter.string(from: Date())
    }

    func append(text: String) async throws {
        guard !token.isEmpty, !pageId.isEmpty else {
            throw NotionError.invalidConfig
        }

        let title = await generateTitle(text: text)
        let timestamp = czechTimestamp()
        let textBlocks = splitTextIntoBlocks(text)

        var children: [[String: Any]] = [
            [
                "object": "block",
                "type": "paragraph",
                "paragraph": [
                    "rich_text": [
                        [
                            "type": "text",
                            "text": ["content": timestamp],
                            "annotations": ["bold": true, "color": "gray"],
                        ]
                    ]
                ],
            ]
        ]
        children.append(contentsOf: textBlocks)

        let body: [String: Any] = [
            "parent": ["page_id": pageId],
            "icon": ["type": "emoji", "emoji": "💻"],
            "properties": [
                "title": [["text": ["content": title]]]
            ],
            "children": children,
        ]

        let url = URL(string: "https://api.notion.com/v1/pages")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue(apiVersion, forHTTPHeaderField: "Notion-Version")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw NotionError.networkError(
                NSError(domain: "NotionService", code: -1, userInfo: [
                    NSLocalizedDescriptionKey: "Neplatná odpověď serveru"
                ])
            )
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            let message = parseErrorMessage(from: data) ?? "Neznámá chyba"
            throw NotionError.apiError(httpResponse.statusCode, message)
        }
    }

    func testConnection() async throws -> Bool {
        guard !token.isEmpty, !pageId.isEmpty else {
            throw NotionError.invalidConfig
        }

        let url = URL(string: "https://api.notion.com/v1/pages/\(pageId)")!
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue(apiVersion, forHTTPHeaderField: "Notion-Version")

        let (_, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            return false
        }

        return httpResponse.statusCode == 200
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
            "system": "Generate a concise 5-7 word title for this voice note. Keep the same language as the input. Return ONLY the title, no quotes, no punctuation at the end.",
            "messages": [["role": "user", "content": text.trimmingCharacters(in: .whitespacesAndNewlines)]],
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw NotionError.networkError(
                NSError(domain: "NotionService", code: -1, userInfo: [
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
        if trimmed.count <= 60 { return trimmed }
        return String(trimmed.prefix(60)) + "…"
    }

    // MARK: - Text Splitting

    private func splitTextIntoBlocks(_ text: String) -> [[String: Any]] {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        var blocks: [[String: Any]] = []
        var index = trimmed.startIndex

        while index < trimmed.endIndex {
            let end = trimmed.index(index, offsetBy: 2000, limitedBy: trimmed.endIndex) ?? trimmed.endIndex
            let chunk = String(trimmed[index..<end])
            blocks.append([
                "object": "block",
                "type": "paragraph",
                "paragraph": [
                    "rich_text": [
                        [
                            "type": "text",
                            "text": ["content": chunk],
                        ]
                    ]
                ],
            ])
            index = end
        }

        return blocks
    }

    // MARK: - Helpers

    private func parseErrorMessage(from data: Data) -> String? {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }
        return json["message"] as? String
    }
}

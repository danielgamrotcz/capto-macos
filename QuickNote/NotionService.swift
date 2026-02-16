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

    private var token: String {
        UserDefaults.standard.string(forKey: "notionToken") ?? ""
    }

    private var pageId: String {
        UserDefaults.standard.string(forKey: "notionPageId") ?? ""
    }

    private init() {}

    func append(text: String) async throws {
        guard !token.isEmpty, !pageId.isEmpty else {
            throw NotionError.invalidConfig
        }

        let url = URL(string: "https://api.notion.com/v1/blocks/\(pageId)/children")!
        var request = URLRequest(url: url)
        request.httpMethod = "PATCH"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue(apiVersion, forHTTPHeaderField: "Notion-Version")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "children": [
                [
                    "object": "block",
                    "type": "paragraph",
                    "paragraph": [
                        "rich_text": [
                            [
                                "type": "text",
                                "text": ["content": text],
                            ]
                        ]
                    ],
                ]
            ]
        ]

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

    private func parseErrorMessage(from data: Data) -> String? {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }
        return json["message"] as? String
    }
}

import Foundation

actor SupabaseService {
    static let shared = SupabaseService()

    private let session = URLSession.shared
    private var folderCache: [String: String] = [:]

    private var url: String { UserDefaults.standard.string(forKey: "supabaseURL") ?? "" }
    private var serviceKey: String { UserDefaults.standard.string(forKey: "supabaseServiceKey") ?? "" }
    private var userId: String { UserDefaults.standard.string(forKey: "supabaseUserID") ?? "" }

    private var isConfigured: Bool { !url.isEmpty && !serviceKey.isEmpty && !userId.isEmpty }

    private init() {}

    // MARK: - Public

    func syncNote(path: String, title: String, content: String) async -> Bool {
        guard isConfigured else { return false }
        do {
            let folderPath = (path as NSString).deletingLastPathComponent
            let folderId = try await ensureFolder(path: folderPath)

            var body: [String: Any] = [
                "user_id": userId,
                "title": title,
                "content": content,
                "path": path,
            ]
            if let folderId { body["folder_id"] = folderId }

            _ = try await request(method: "POST", table: "notes", data: body,
                                  extraHeaders: ["Prefer": "resolution=merge-duplicates"])
            return true
        } catch {
            NSLog("[SupabaseService] syncNote failed: \(error)")
            return false
        }
    }

    func testConnection() async -> Bool {
        guard isConfigured else { return false }
        do {
            _ = try await request(method: "GET", table: "notes",
                                  params: "?select=id&limit=1")
            return true
        } catch {
            NSLog("[SupabaseService] testConnection failed: \(error)")
            return false
        }
    }

    // MARK: - Folder Chain

    private func ensureFolder(path: String) async throws -> String? {
        if path.isEmpty || path == "." { return nil }
        if let cached = folderCache[path] { return cached }

        let parts = path.split(separator: "/").map(String.init)
        var parentId: String?

        for i in 0..<parts.count {
            let currentPath = parts[0...i].joined(separator: "/")
            if let cached = folderCache[currentPath] {
                parentId = cached
                continue
            }

            let encoded = currentPath.addingPercentEncoding(withAllowedCharacters: CharacterSet()) ?? currentPath
            let qs = "?user_id=eq.\(userId)&path=eq.\(encoded)&select=id"
            let rows = try await request(method: "GET", table: "folders", params: qs)

            if let first = rows.first, let id = first["id"] as? String {
                parentId = id
            } else {
                var folderData: [String: Any] = [
                    "user_id": userId,
                    "name": parts[i],
                    "path": currentPath,
                ]
                if let parentId { folderData["parent_id"] = parentId }

                let created = try await request(method: "POST", table: "folders", data: folderData,
                                                extraHeaders: ["Prefer": "return=representation"])
                guard let first = created.first, let id = first["id"] as? String else {
                    throw URLError(.badServerResponse)
                }
                parentId = id
            }
            folderCache[currentPath] = parentId
        }

        return parentId
    }

    // MARK: - HTTP

    private func request(method: String, table: String,
                         data: [String: Any]? = nil, params: String = "",
                         extraHeaders: [String: String] = [:]) async throws -> [[String: Any]] {
        guard let url = URL(string: "\(self.url)/rest/v1/\(table)\(params)") else {
            throw URLError(.badURL)
        }

        var req = URLRequest(url: url, timeoutInterval: 30)
        req.httpMethod = method
        req.setValue(serviceKey, forHTTPHeaderField: "apikey")
        req.setValue("Bearer \(serviceKey)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        for (key, value) in extraHeaders {
            req.setValue(value, forHTTPHeaderField: key)
        }

        if let data {
            req.httpBody = try JSONSerialization.data(withJSONObject: data)
        }

        let (responseData, response) = try await session.data(for: req)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            let code = (response as? HTTPURLResponse)?.statusCode ?? -1
            throw URLError(.badServerResponse, userInfo: [
                NSLocalizedDescriptionKey: "HTTP \(code)"
            ])
        }

        let text = String(data: responseData, encoding: .utf8) ?? ""
        if text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return [] }
        let parsed = try JSONSerialization.jsonObject(with: responseData)
        if let array = parsed as? [[String: Any]] { return array }
        if let dict = parsed as? [String: Any] { return [dict] }
        return []
    }
}

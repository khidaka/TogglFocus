import Foundation

enum TogglError: LocalizedError {
    case missingToken
    case missingWorkspace
    case http(status: Int, body: String)
    case decoding(Error)
    case transport(Error)

    var errorDescription: String? {
        switch self {
        case .missingToken: return "API トークンが未設定です。設定画面から登録してください。"
        case .missingWorkspace: return "Workspace ID が取得できません。設定画面から接続テストを実行してください。"
        case .http(let s, let b): return "Toggl API エラー (\(s)): \(b)"
        case .decoding(let e): return "レスポンス解析失敗: \(e.localizedDescription)"
        case .transport(let e): return "通信エラー: \(e.localizedDescription)"
        }
    }
}

struct MeResponse: Decodable {
    let id: Int
    let defaultWorkspaceId: Int

    enum CodingKeys: String, CodingKey {
        case id
        case defaultWorkspaceId = "default_workspace_id"
    }
}

actor TogglClient {
    static let shared = TogglClient()

    private let session: URLSession
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder

    init(session: URLSession = .shared) {
        self.session = session

        let dec = JSONDecoder()
        let enc = JSONEncoder()
        let withFrac = Date.ISO8601FormatStyle(includingFractionalSeconds: true)
        let noFrac = Date.ISO8601FormatStyle(includingFractionalSeconds: false)

        dec.dateDecodingStrategy = .custom { d in
            let c = try d.singleValueContainer()
            let s = try c.decode(String.self)
            if let date = try? withFrac.parse(s) { return date }
            if let date = try? noFrac.parse(s) { return date }
            throw DecodingError.dataCorruptedError(in: c, debugDescription: "Bad date: \(s)")
        }
        enc.dateEncodingStrategy = .custom { date, encoder in
            var c = encoder.singleValueContainer()
            try c.encode(noFrac.format(date))
        }
        self.decoder = dec
        self.encoder = enc
    }

    private func authHeader() throws -> String {
        guard let token = SharedSettings.apiToken, !token.isEmpty else {
            throw TogglError.missingToken
        }
        let pair = "\(token):api_token"
        let b64 = Data(pair.utf8).base64EncodedString()
        return "Basic \(b64)"
    }

    private func request(
        _ method: String,
        _ path: String,
        query: [URLQueryItem] = [],
        body: Data? = nil
    ) async throws -> Data {
        var comps = URLComponents(string: "https://api.track.toggl.com/api/v9" + path)!
        if !query.isEmpty { comps.queryItems = query }
        var req = URLRequest(url: comps.url!)
        req.httpMethod = method
        req.setValue(try authHeader(), forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        req.httpBody = body

        do {
            let (data, resp) = try await session.data(for: req)
            guard let http = resp as? HTTPURLResponse else {
                throw TogglError.http(status: -1, body: "no response")
            }
            guard (200..<300).contains(http.statusCode) else {
                let body = String(data: data, encoding: .utf8) ?? ""
                throw TogglError.http(status: http.statusCode, body: body)
            }
            return data
        } catch let e as TogglError {
            throw e
        } catch {
            throw TogglError.transport(error)
        }
    }

    private func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        do { return try decoder.decode(type, from: data) }
        catch { throw TogglError.decoding(error) }
    }

    func fetchMe() async throws -> MeResponse {
        let data = try await request("GET", "/me", query: [URLQueryItem(name: "with_related_data", value: "false")])
        return try decode(MeResponse.self, from: data)
    }

    func fetchProjects() async throws -> [TogglProject] {
        let data = try await request("GET", "/me/projects",
                                     query: [URLQueryItem(name: "include_archived", value: "false")])
        return try decode([TogglProject].self, from: data)
    }

    func fetchTimeEntries(since: Date) async throws -> [TogglTimeEntry] {
        let ts = Int(since.timeIntervalSince1970)
        let data = try await request("GET", "/me/time_entries",
                                     query: [URLQueryItem(name: "since", value: String(ts))])
        return try decode([TogglTimeEntry].self, from: data)
    }

    func fetchCurrent() async throws -> TogglTimeEntry? {
        let data = try await request("GET", "/me/time_entries/current")
        if data.isEmpty || data == Data("null".utf8) { return nil }
        return try? decode(TogglTimeEntry.self, from: data)
    }

    func startEntry(workspaceId: Int, projectId: Int?, description: String) async throws -> TogglTimeEntry {
        struct Body: Encodable {
            let description: String
            let project_id: Int?
            let workspace_id: Int
            let start: Date
            let duration: Int
            let created_with: String
        }
        let body = Body(
            description: description,
            project_id: projectId,
            workspace_id: workspaceId,
            start: .now,
            duration: -1,
            created_with: "TogglFocus"
        )
        let data = try await request("POST", "/workspaces/\(workspaceId)/time_entries",
                                     body: try encoder.encode(body))
        return try decode(TogglTimeEntry.self, from: data)
    }

    func updateDescription(workspaceId: Int, entryId: Int, description: String) async throws -> TogglTimeEntry {
        struct Body: Encodable { let description: String }
        let data = try await request("PUT", "/workspaces/\(workspaceId)/time_entries/\(entryId)",
                                     body: try encoder.encode(Body(description: description)))
        return try decode(TogglTimeEntry.self, from: data)
    }

    func stopEntry(workspaceId: Int, entryId: Int) async throws -> TogglTimeEntry {
        let data = try await request("PATCH", "/workspaces/\(workspaceId)/time_entries/\(entryId)/stop")
        return try decode(TogglTimeEntry.self, from: data)
    }
}

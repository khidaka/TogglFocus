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

    private struct CacheEntry<T> {
        let value: T
        let storedAt: Date
        func isFresh(ttl: TimeInterval) -> Bool {
            Date.now.timeIntervalSince(storedAt) < ttl
        }
    }

    private static let cacheTTL: TimeInterval = 300

    private var cachedMe: CacheEntry<MeResponse>?
    private var cachedClients: CacheEntry<[WorkspaceClient]>?
    private var cachedProjects: CacheEntry<[TogglProject]>?
    private var cachedEntries: (since: Date, entry: CacheEntry<[TogglTimeEntry]>)?
    private var cachedCurrent: CacheEntry<TogglTimeEntry?>?

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

    func fetchMe(forceRefresh: Bool = false) async throws -> MeResponse {
        if !forceRefresh, let c = cachedMe, c.isFresh(ttl: Self.cacheTTL) { return c.value }
        let data = try await request("GET", "/me", query: [URLQueryItem(name: "with_related_data", value: "false")])
        let value = try decode(MeResponse.self, from: data)
        cachedMe = CacheEntry(value: value, storedAt: .now)
        return value
    }

    func fetchClients(forceRefresh: Bool = false) async throws -> [WorkspaceClient] {
        if !forceRefresh, let c = cachedClients, c.isFresh(ttl: Self.cacheTTL) { return c.value }
        let data = try await request("GET", "/me/clients")
        let value: [WorkspaceClient]
        if data.isEmpty || data == Data("null".utf8) {
            value = []
        } else {
            value = try decode([WorkspaceClient].self, from: data)
        }
        cachedClients = CacheEntry(value: value, storedAt: .now)
        return value
    }

    func fetchProjects(forceRefresh: Bool = false) async throws -> [TogglProject] {
        if !forceRefresh, let c = cachedProjects, c.isFresh(ttl: Self.cacheTTL) { return c.value }
        let data = try await request("GET", "/me/projects",
                                     query: [URLQueryItem(name: "include_archived", value: "false")])
        let value = try decode([TogglProject].self, from: data)
        cachedProjects = CacheEntry(value: value, storedAt: .now)
        return value
    }

    func fetchTimeEntries(since: Date, forceRefresh: Bool = false) async throws -> [TogglTimeEntry] {
        if !forceRefresh, let cached = cachedEntries, cached.since == since, cached.entry.isFresh(ttl: Self.cacheTTL) {
            return cached.entry.value
        }
        let ts = Int(since.timeIntervalSince1970)
        let data = try await request("GET", "/me/time_entries",
                                     query: [URLQueryItem(name: "since", value: String(ts))])
        let value = try decode([TogglTimeEntry].self, from: data)
        cachedEntries = (since: since, entry: CacheEntry(value: value, storedAt: .now))
        return value
    }

    func fetchCurrent(forceRefresh: Bool = false) async throws -> TogglTimeEntry? {
        if !forceRefresh, let c = cachedCurrent, c.isFresh(ttl: Self.cacheTTL) { return c.value }
        let data = try await request("GET", "/me/time_entries/current")
        let value: TogglTimeEntry?
        if data.isEmpty || data == Data("null".utf8) {
            value = nil
        } else {
            value = try? decode(TogglTimeEntry.self, from: data)
        }
        cachedCurrent = CacheEntry(value: value, storedAt: .now)
        return value
    }

    func invalidateAll() {
        cachedMe = nil
        cachedClients = nil
        cachedProjects = nil
        cachedEntries = nil
        cachedCurrent = nil
    }

    private func invalidateEntryCaches() {
        cachedEntries = nil
        cachedCurrent = nil
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
        invalidateEntryCaches()
        return try decode(TogglTimeEntry.self, from: data)
    }

    func updateDescription(workspaceId: Int, entryId: Int, description: String) async throws -> TogglTimeEntry {
        struct Body: Encodable { let description: String }
        let data = try await request("PUT", "/workspaces/\(workspaceId)/time_entries/\(entryId)",
                                     body: try encoder.encode(Body(description: description)))
        invalidateEntryCaches()
        return try decode(TogglTimeEntry.self, from: data)
    }

    func stopEntry(workspaceId: Int, entryId: Int) async throws -> TogglTimeEntry {
        let data = try await request("PATCH", "/workspaces/\(workspaceId)/time_entries/\(entryId)/stop")
        invalidateEntryCaches()
        return try decode(TogglTimeEntry.self, from: data)
    }
}

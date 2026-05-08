import Foundation
import Observation

struct ActiveProjectRow: Identifiable, Hashable {
    let project: TogglProject
    let latestEntry: TogglTimeEntry?
    var id: Int { project.id }
}

@Observable
@MainActor
final class ProjectStore {
    var rows: [ActiveProjectRow] = []
    var clients: [WorkspaceClient] = []
    var isLoading: Bool = false
    var lastError: String?

    private let client: TogglClient

    init(client: TogglClient = .shared) {
        self.client = client
    }

    /// 一覧に登場するプロジェクトの clientId 集合 (nil 含む) に絞り込み、名前順で返す。
    var availableClients: [WorkspaceClient] {
        let usedIds = Set(rows.compactMap { $0.project.clientId })
        return clients.filter { usedIds.contains($0.id) }.sorted { $0.name < $1.name }
    }

    var hasUnclassifiedProjects: Bool {
        rows.contains { $0.project.clientId == nil }
    }

    func refresh(force: Bool = false) async {
        isLoading = true
        defer { isLoading = false }

        do {
            if SharedSettings.workspaceId == nil {
                let me = try await client.fetchMe()
                SharedSettings.workspaceId = me.defaultWorkspaceId
            }

            async let projectsTask = client.fetchProjects(forceRefresh: force)
            async let clientsTask = client.fetchClients(forceRefresh: force)
            let cal = Calendar.current
            let today = cal.startOfDay(for: .now)
            let since = cal.date(byAdding: .day, value: -60, to: today) ?? Date(timeIntervalSinceNow: -60 * 60 * 24 * 60)
            async let entriesTask = client.fetchTimeEntries(since: since, forceRefresh: force)
            let (projects, fetchedClients, entries) = try await (projectsTask, clientsTask, entriesTask)
            self.clients = fetchedClients

            var latestByProject: [Int: TogglTimeEntry] = [:]
            for entry in entries.sorted(by: { $0.start > $1.start }) {
                guard let pid = entry.projectId else { continue }
                if latestByProject[pid] == nil { latestByProject[pid] = entry }
            }

            let activeProjects = projects.filter { $0.active }
            self.rows = activeProjects
                .map { ActiveProjectRow(project: $0, latestEntry: latestByProject[$0.id]) }
                .sorted { lhs, rhs in
                    let l = lhs.latestEntry?.start ?? .distantPast
                    let r = rhs.latestEntry?.start ?? .distantPast
                    return l > r
                }
            self.lastError = nil
        } catch {
            self.lastError = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }
}

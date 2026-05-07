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
    var isLoading: Bool = false
    var lastError: String?

    private let client: TogglClient

    init(client: TogglClient = .shared) {
        self.client = client
    }

    func refresh() async {
        isLoading = true
        defer { isLoading = false }

        do {
            if SharedSettings.workspaceId == nil {
                let me = try await client.fetchMe()
                SharedSettings.workspaceId = me.defaultWorkspaceId
            }

            async let projectsTask = client.fetchProjects()
            let since = Calendar.current.date(byAdding: .day, value: -60, to: .now) ?? Date(timeIntervalSinceNow: -60 * 60 * 24 * 60)
            async let entriesTask = client.fetchTimeEntries(since: since)
            let (projects, entries) = try await (projectsTask, entriesTask)

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

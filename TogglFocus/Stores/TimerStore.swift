import Foundation
import Observation
import ActivityKit
import SwiftData

@Observable
@MainActor
final class TimerStore {
    var current: TogglTimeEntry?
    var currentProject: TogglProject?
    var lastError: String?
    var isWorking: Bool = false

    private var activityId: String?
    private let client: TogglClient
    private let modelContext: ModelContext

    init(client: TogglClient = .shared,
         modelContext: ModelContext = SharedModelContainer.shared.mainContext) {
        self.client = client
        self.modelContext = modelContext
    }

    func bootstrap(projectsById: [Int: TogglProject], forceRefresh: Bool = false) async {
        do {
            if let entry = try await client.fetchCurrent(forceRefresh: forceRefresh) {
                self.current = entry
                if let pid = entry.projectId { self.currentProject = projectsById[pid] }
                attachExistingActivity(for: entry)
            } else {
                self.current = nil
                self.currentProject = nil
                await endActivityIfNeeded()
            }
        } catch {
            self.lastError = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }

    func start(project: TogglProject, description: String, tags: [String] = []) async {
        guard let workspaceId = SharedSettings.workspaceId ?? Optional(project.workspaceId) else {
            self.lastError = "Workspace ID 不明"
            return
        }
        isWorking = true
        defer { isWorking = false }

        do {
            await endActivityIfNeeded()
            let entry = try await client.startEntry(
                workspaceId: workspaceId,
                projectId: project.id,
                description: description,
                tags: tags
            )
            self.current = entry
            self.currentProject = project
            await startActivity(for: entry, project: project)
            self.lastError = nil
        } catch {
            self.lastError = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }

    func stop() async {
        guard let entry = current else { return }
        let workspaceId = entry.workspaceId
        isWorking = true
        defer { isWorking = false }

        if let pid = entry.projectId, let note = noteFor(projectId: pid), !note.isEmpty,
           note != (entry.description ?? "") {
            _ = try? await client.updateDescription(
                workspaceId: workspaceId,
                entryId: entry.id,
                description: note
            )
        }

        var stopFailure: String?
        do {
            _ = try await client.stopEntry(workspaceId: workspaceId, entryId: entry.id)
        } catch TogglError.http(let status, _) where status == 400 || status == 404 || status == 409 {
            // 既に停止済みのエントリを再度停止しようとしたケース。サーバ側は最終状態が保たれている。
        } catch {
            stopFailure = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }

        self.current = nil
        self.currentProject = nil
        await endActivityIfNeeded()
        self.lastError = stopFailure
    }

    private func noteFor(projectId: Int) -> String? {
        let descriptor = FetchDescriptor<ProjectMeta>(
            predicate: #Predicate { $0.projectId == projectId }
        )
        return (try? modelContext.fetch(descriptor).first)?.note
    }

    // MARK: - Live Activity

    private func attachExistingActivity(for entry: TogglTimeEntry) {
        if let existing = Activity<TogglFocusAttributes>.activities.first(where: { $0.attributes.entryId == entry.id }) {
            self.activityId = existing.id
        }
    }

    private func startActivity(for entry: TogglTimeEntry, project: TogglProject) async {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        let attrs = TogglFocusAttributes(
            entryId: entry.id,
            workspaceId: entry.workspaceId,
            projectId: entry.projectId,
            projectName: project.name,
            projectColorHex: project.color,
            startedAt: entry.start
        )
        let state = TogglFocusAttributes.ContentState(description: entry.description ?? "")
        do {
            let activity = try Activity.request(
                attributes: attrs,
                content: .init(state: state, staleDate: nil),
                pushType: nil
            )
            self.activityId = activity.id
        } catch {
            self.lastError = "Live Activity 起動失敗: \(error.localizedDescription)"
        }
    }

    private func endActivityIfNeeded() async {
        for a in Activity<TogglFocusAttributes>.activities {
            await a.end(nil, dismissalPolicy: .immediate)
        }
        self.activityId = nil
    }
}

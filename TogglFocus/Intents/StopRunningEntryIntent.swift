import AppIntents
import ActivityKit
import SwiftData
import Foundation

struct StopRunningEntryIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "進行中のタイマーを停止"
    static let description = IntentDescription("Toggl Track のタイマーを停止し、ローカルノートを description に反映します。")

    @Parameter(title: "Entry ID") var entryId: Int
    @Parameter(title: "Workspace ID") var workspaceId: Int
    @Parameter(title: "Project ID") var projectId: Int?
    @Parameter(title: "Activity ID") var activityId: String

    init() {}

    init(entryId: Int, workspaceId: Int, projectId: Int?, activityId: String) {
        self.entryId = entryId
        self.workspaceId = workspaceId
        self.projectId = projectId
        self.activityId = activityId
    }

    func perform() async throws -> some IntentResult {
        let client = TogglClient.shared

        if let pid = projectId,
           let note = await Self.note(forProjectId: pid),
           !note.isEmpty {
            _ = try? await client.updateDescription(
                workspaceId: workspaceId,
                entryId: entryId,
                description: note
            )
        }

        _ = try? await client.stopEntry(workspaceId: workspaceId, entryId: entryId)

        for activity in Activity<TogglFocusAttributes>.activities where activity.id == activityId {
            await activity.end(nil, dismissalPolicy: .immediate)
        }

        return .result()
    }

    @MainActor
    private static func note(forProjectId projectId: Int) -> String? {
        let context = SharedModelContainer.shared.mainContext
        let descriptor = FetchDescriptor<ProjectMeta>(
            predicate: #Predicate { $0.projectId == projectId }
        )
        guard let meta = try? context.fetch(descriptor).first else { return nil }
        return meta.note
    }
}

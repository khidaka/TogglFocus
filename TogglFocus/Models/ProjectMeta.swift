import Foundation
import SwiftData

@Model
final class ProjectMeta {
    #Unique<ProjectMeta>([\.projectId])

    var projectId: Int
    var url: String?
    var note: String?
    var updatedAt: Date

    init(projectId: Int, url: String? = nil, note: String? = nil, updatedAt: Date = .now) {
        self.projectId = projectId
        self.url = url
        self.note = note
        self.updatedAt = updatedAt
    }

    var hasContent: Bool {
        !(url ?? "").isEmpty || !(note ?? "").isEmpty
    }
}

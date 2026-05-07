import Foundation

struct TogglTimeEntry: Codable, Identifiable, Hashable, Sendable {
    let id: Int
    let workspaceId: Int
    let projectId: Int?
    let description: String?
    let start: Date
    let stop: Date?
    let duration: Int

    enum CodingKeys: String, CodingKey {
        case id
        case workspaceId = "workspace_id"
        case projectId = "project_id"
        case description
        case start
        case stop
        case duration
    }

    var isRunning: Bool { duration < 0 }
}

import Foundation
import ActivityKit

struct TogglFocusAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var description: String
    }

    let entryId: Int
    let workspaceId: Int
    let projectId: Int?
    let projectName: String
    let projectColorHex: String?
    let startedAt: Date
}

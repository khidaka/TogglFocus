import Foundation

struct WorkspaceClient: Codable, Identifiable, Hashable, Sendable {
    let id: Int
    let name: String
    let archived: Bool?

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case archived
    }
}

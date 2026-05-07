import Foundation
import SwiftUI

struct TogglProject: Codable, Identifiable, Hashable, Sendable {
    let id: Int
    let workspaceId: Int
    let name: String
    let color: String?
    let active: Bool
    let clientId: Int?

    enum CodingKeys: String, CodingKey {
        case id
        case workspaceId = "workspace_id"
        case name
        case color
        case active
        case clientId = "client_id"
    }

    var swiftUIColor: Color {
        guard let hex = color, let parsed = Color(hex: hex) else { return .accentColor }
        return parsed
    }
}

extension Color {
    init?(hex: String) {
        var s = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.hasPrefix("#") { s.removeFirst() }
        guard s.count == 6, let v = UInt32(s, radix: 16) else { return nil }
        let r = Double((v >> 16) & 0xFF) / 255
        let g = Double((v >> 8) & 0xFF) / 255
        let b = Double(v & 0xFF) / 255
        self = Color(red: r, green: g, blue: b)
    }
}

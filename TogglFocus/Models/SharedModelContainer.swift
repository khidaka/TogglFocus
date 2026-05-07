import Foundation
import SwiftData

enum SharedModelContainer {
    static let shared: ModelContainer = {
        let schema = Schema([ProjectMeta.self])
        let url = AppGroup.sharedContainerURL.appending(path: "TogglFocus.sqlite")
        let config = ModelConfiguration(schema: schema, url: url)
        do {
            return try ModelContainer(for: schema, configurations: [config])
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }()
}

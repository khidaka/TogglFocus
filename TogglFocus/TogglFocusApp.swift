import SwiftUI
import SwiftData

@main
struct TogglFocusApp: App {
    var body: some Scene {
        WindowGroup {
            ActiveProjectsView()
        }
        .modelContainer(SharedModelContainer.shared)
    }
}

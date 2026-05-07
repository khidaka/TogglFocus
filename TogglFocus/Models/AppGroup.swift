import Foundation

enum AppGroup {
    static let identifier = "group.com.hidaka.TogglFocus"

    static var sharedDefaults: UserDefaults {
        UserDefaults(suiteName: identifier) ?? .standard
    }

    static var sharedContainerURL: URL {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: identifier)
            ?? URL.documentsDirectory
    }

    enum Keys {
        static let apiToken = "togglApiToken"
        static let workspaceId = "togglWorkspaceId"
    }
}

enum SharedSettings {
    static var apiToken: String? {
        get { AppGroup.sharedDefaults.string(forKey: AppGroup.Keys.apiToken) }
        set { AppGroup.sharedDefaults.set(newValue, forKey: AppGroup.Keys.apiToken) }
    }

    static var workspaceId: Int? {
        get {
            let v = AppGroup.sharedDefaults.integer(forKey: AppGroup.Keys.workspaceId)
            return v == 0 ? nil : v
        }
        set { AppGroup.sharedDefaults.set(newValue ?? 0, forKey: AppGroup.Keys.workspaceId) }
    }
}

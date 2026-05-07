import SwiftUI

struct SettingsView: View {
    @State private var token: String = SharedSettings.apiToken ?? ""
    @State private var workspaceId: Int? = SharedSettings.workspaceId
    @State private var status: String = ""
    @State private var testing: Bool = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Toggl Track API トークン") {
                    SecureField("API トークン", text: $token)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    Button {
                        SharedSettings.apiToken = token.trimmingCharacters(in: .whitespacesAndNewlines)
                        Task { await test() }
                    } label: {
                        if testing { ProgressView() } else { Text("保存して接続テスト") }
                    }
                    .disabled(token.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || testing)
                }

                Section("接続情報") {
                    LabeledContent("Workspace ID") {
                        Text(workspaceId.map(String.init) ?? "未取得")
                            .foregroundStyle(.secondary)
                    }
                    if !status.isEmpty {
                        Text(status).font(.footnote).foregroundStyle(.secondary)
                    }
                }

                Section {
                    Link("Toggl Track プロフィールから API トークンを取得",
                         destination: URL(string: "https://track.toggl.com/profile")!)
                }
            }
            .navigationTitle("設定")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private func test() async {
        testing = true
        defer { testing = false }
        do {
            let me = try await TogglClient.shared.fetchMe()
            SharedSettings.workspaceId = me.defaultWorkspaceId
            workspaceId = me.defaultWorkspaceId
            status = "接続成功"
        } catch {
            status = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }
}

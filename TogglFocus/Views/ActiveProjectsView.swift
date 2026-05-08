import SwiftUI
import SwiftData

struct ActiveProjectsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.openURL) private var openURL
    @Query private var allMetas: [ProjectMeta]

    @State private var projectStore = ProjectStore()
    @State private var timerStore = TimerStore()

    @State private var showSettings = false
    @State private var editingProject: TogglProject?
    @State private var safariURL: URL?

    private var metaByProject: [Int: ProjectMeta] {
        Dictionary(uniqueKeysWithValues: allMetas.map { ($0.projectId, $0) })
    }

    private var projectsById: [Int: TogglProject] {
        Dictionary(uniqueKeysWithValues: projectStore.rows.map { ($0.project.id, $0.project) })
    }

    var body: some View {
        NavigationStack {
            ZStack {
                content
            }
            .navigationTitle("プロジェクト")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showSettings = true
                    } label: { Image(systemName: "gearshape") }
                }
            }
            .safeAreaInset(edge: .bottom) {
                if let entry = timerStore.current {
                    RunningBannerView(
                        entry: entry,
                        project: timerStore.currentProject,
                        onStop: { Task { await timerStore.stop(); await projectStore.refresh() } }
                    )
                }
            }
            .refreshable { await projectStore.refresh(force: true) }
            .task {
                if SharedSettings.apiToken == nil { showSettings = true }
                await projectStore.refresh()
                await timerStore.bootstrap(projectsById: projectsById)
            }
            .sheet(isPresented: $showSettings) {
                SettingsView()
                    .onDisappear { Task { await projectStore.refresh() } }
            }
            .sheet(item: $editingProject) { p in
                ProjectMetaEditSheet(project: p)
            }
            .sheet(item: $safariURL) { url in
                SafariView(url: url).ignoresSafeArea()
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        if projectStore.isLoading && projectStore.rows.isEmpty {
            ProgressView()
        } else if let err = projectStore.lastError, projectStore.rows.isEmpty {
            ContentUnavailableView("読み込み失敗", systemImage: "exclamationmark.triangle", description: Text(err))
        } else if projectStore.rows.isEmpty {
            ContentUnavailableView("アクティブなプロジェクトがありません", systemImage: "tray")
        } else {
            List(projectStore.rows) { row in
                ProjectRowView(row: row, meta: metaByProject[row.project.id]) { url in
                    if url.scheme == "http" || url.scheme == "https" {
                        safariURL = url
                    } else {
                        openURL(url)
                    }
                }
                .swipeActions(edge: .leading) {
                    Button {
                        editingProject = row.project
                    } label: { Label("編集", systemImage: "square.and.pencil") }
                    .tint(.blue)
                }
                .contextMenu {
                    Button {
                        editingProject = row.project
                    } label: { Label("URL とノートを編集", systemImage: "square.and.pencil") }
                }
                .onTapGesture {
                    let m = metaByProject[row.project.id]
                    let desc = (m?.note?.isEmpty == false ? m?.note : row.latestEntry?.description) ?? ""
                    Task {
                        await timerStore.start(project: row.project, description: desc)
                        await projectStore.refresh()
                    }
                }
            }
            .listStyle(.insetGrouped)
        }
    }
}

extension URL: @retroactive Identifiable {
    public var id: String { absoluteString }
}

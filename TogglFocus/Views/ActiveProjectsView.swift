import SwiftUI
import SwiftData

enum ClientFilter: Hashable {
    case all
    case unclassified
    case client(Int)

    var rawValue: Int {
        switch self {
        case .all: return -1
        case .unclassified: return -2
        case .client(let id): return id
        }
    }

    init(rawValue: Int) {
        switch rawValue {
        case -1: self = .all
        case -2: self = .unclassified
        default: self = .client(rawValue)
        }
    }
}

struct ActiveProjectsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.openURL) private var openURL
    @Environment(\.scenePhase) private var scenePhase
    @Query private var allMetas: [ProjectMeta]

    @State private var projectStore = ProjectStore()
    @State private var timerStore = TimerStore()

    @State private var showSettings = false
    @State private var editingProject: TogglProject?
    @State private var safariURL: URL?

    @AppStorage("clientFilterRaw") private var clientFilterRaw: Int = -1
    private var clientFilter: ClientFilter { ClientFilter(rawValue: clientFilterRaw) }

    private var metaByProject: [Int: ProjectMeta] {
        Dictionary(uniqueKeysWithValues: allMetas.map { ($0.projectId, $0) })
    }

    private var projectsById: [Int: TogglProject] {
        Dictionary(uniqueKeysWithValues: projectStore.rows.map { ($0.project.id, $0.project) })
    }

    private var displayedRows: [ActiveProjectRow] {
        switch clientFilter {
        case .all: return projectStore.rows
        case .unclassified: return projectStore.rows.filter { $0.project.clientId == nil }
        case .client(let cid): return projectStore.rows.filter { $0.project.clientId == cid }
        }
    }

    private var filterTitle: String {
        switch clientFilter {
        case .all: return "すべて"
        case .unclassified: return "未分類"
        case .client(let cid):
            return projectStore.clients.first { $0.id == cid }?.name ?? "クライアント"
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                content
            }
            .navigationTitle("プロジェクト")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Menu {
                        Button {
                            clientFilterRaw = ClientFilter.all.rawValue
                        } label: {
                            Label("すべて", systemImage: clientFilter == .all ? "checkmark" : "")
                        }
                        if projectStore.hasUnclassifiedProjects {
                            Button {
                                clientFilterRaw = ClientFilter.unclassified.rawValue
                            } label: {
                                Label("未分類", systemImage: clientFilter == .unclassified ? "checkmark" : "")
                            }
                        }
                        if !projectStore.availableClients.isEmpty {
                            Divider()
                            ForEach(projectStore.availableClients) { c in
                                Button {
                                    clientFilterRaw = ClientFilter.client(c.id).rawValue
                                } label: {
                                    Label(c.name, systemImage: clientFilter == .client(c.id) ? "checkmark" : "")
                                }
                            }
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "line.3.horizontal.decrease.circle")
                            Text(filterTitle).font(.subheadline)
                        }
                    }
                }
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
            .onChange(of: scenePhase) { _, phase in
                guard phase == .active else { return }
                Task {
                    await projectStore.refresh(force: true)
                    await timerStore.bootstrap(projectsById: projectsById, forceRefresh: true)
                }
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
        } else if displayedRows.isEmpty {
            ContentUnavailableView("該当プロジェクトなし", systemImage: "line.3.horizontal.decrease.circle",
                                   description: Text("「\(filterTitle)」では空です"))
        } else {
            List(displayedRows) { row in
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

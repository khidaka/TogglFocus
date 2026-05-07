import SwiftUI
import SwiftData

struct ProjectMetaEditSheet: View {
    let project: TogglProject

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var url: String = ""
    @State private var note: String = ""
    @State private var existing: ProjectMeta?

    var body: some View {
        NavigationStack {
            Form {
                Section("ノート") {
                    TextField("作業内容メモ", text: $note, axis: .vertical)
                        .lineLimit(3...8)
                }
                Section("作業参照 URL") {
                    TextField("https://...", text: $url)
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }
            }
            .navigationTitle(project.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") { save(); dismiss() }
                }
            }
            .onAppear { load() }
        }
    }

    private func load() {
        let pid = project.id
        let descriptor = FetchDescriptor<ProjectMeta>(predicate: #Predicate { $0.projectId == pid })
        if let m = try? modelContext.fetch(descriptor).first {
            existing = m
            url = m.url ?? ""
            note = m.note ?? ""
        }
    }

    private func save() {
        let trimmedURL = url.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedNote = note.trimmingCharacters(in: .whitespacesAndNewlines)

        if trimmedURL.isEmpty && trimmedNote.isEmpty {
            if let existing { modelContext.delete(existing) }
            try? modelContext.save()
            return
        }

        if let m = existing {
            m.url = trimmedURL.isEmpty ? nil : trimmedURL
            m.note = trimmedNote.isEmpty ? nil : trimmedNote
            m.updatedAt = .now
        } else {
            let m = ProjectMeta(
                projectId: project.id,
                url: trimmedURL.isEmpty ? nil : trimmedURL,
                note: trimmedNote.isEmpty ? nil : trimmedNote
            )
            modelContext.insert(m)
        }
        try? modelContext.save()
    }
}

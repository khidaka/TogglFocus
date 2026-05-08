import SwiftUI
import SwiftData

struct ProjectRowView: View {
    let row: ActiveProjectRow
    let meta: ProjectMeta?
    let onOpenURL: (URL) -> Void

    private var primaryText: String {
        if let n = meta?.note, !n.isEmpty { return n }
        if let d = row.latestEntry?.description, !d.isEmpty { return d }
        return "(履歴なし)"
    }

    private var secondaryText: String? {
        guard let n = meta?.note, !n.isEmpty,
              let d = row.latestEntry?.description, !d.isEmpty,
              n != d else { return nil }
        return d
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Circle()
                .fill(row.project.swiftUIColor)
                .frame(width: 10, height: 10)
                .padding(.top, 6)
            VStack(alignment: .leading, spacing: 2) {
                Text(row.project.name)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                Text(primaryText)
                    .font(.body)
                    .lineLimit(2)
                if let secondaryText {
                    Text(secondaryText)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }
                if let last = row.latestEntry?.start {
                    HStack(spacing: 6) {
                        Text(DurationFormatter.relative(last))
                        Text("·").foregroundStyle(.quaternary)
                        Text(DurationFormatter.absolute(last))
                    }
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                }
            }
            Spacer(minLength: 0)
            if let urlString = meta?.url, let url = URL(string: urlString), !urlString.isEmpty {
                Button {
                    onOpenURL(url)
                } label: {
                    Image(systemName: "link")
                        .imageScale(.medium)
                        .foregroundStyle(.tint)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("作業参照リンクを開く")
            }
        }
        .contentShape(Rectangle())
    }
}

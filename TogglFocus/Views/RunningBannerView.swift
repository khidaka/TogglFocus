import SwiftUI

struct RunningBannerView: View {
    let entry: TogglTimeEntry
    let project: TogglProject?
    let onStop: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(project?.swiftUIColor ?? .accentColor)
                .frame(width: 10, height: 10)
            VStack(alignment: .leading, spacing: 2) {
                Text(project?.name ?? "Project")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Text(entry.description?.isEmpty == false ? entry.description! : "(no description)")
                    .font(.subheadline)
                    .lineLimit(1)
            }
            Spacer()
            Text(timerInterval: entry.start...Date.distantFuture, countsDown: false)
                .font(.body.monospacedDigit())
                .foregroundStyle(.secondary)
            Button(role: .destructive, action: onStop) {
                Image(systemName: "stop.fill")
                    .imageScale(.large)
            }
            .buttonStyle(.borderedProminent)
            .tint(.red)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(.bar)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .padding(.horizontal)
        .padding(.bottom, 8)
    }
}

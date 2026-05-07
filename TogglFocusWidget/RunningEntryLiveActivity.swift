import ActivityKit
import WidgetKit
import SwiftUI

struct RunningEntryLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: TogglFocusAttributes.self) { context in
            LockScreenView(context: context)
                .activityBackgroundTint(.black.opacity(0.3))
                .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    HStack(spacing: 8) {
                        Circle()
                            .fill(color(for: context.attributes.projectColorHex))
                            .frame(width: 8, height: 8)
                        Text(context.attributes.projectName)
                            .font(.caption.weight(.semibold))
                            .lineLimit(1)
                    }
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text(timerInterval: context.attributes.startedAt...Date.distantFuture, countsDown: false)
                        .font(.caption.monospacedDigit())
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
                DynamicIslandExpandedRegion(.center) {
                    Text(context.state.description.isEmpty ? "(no description)" : context.state.description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Button(intent: stopIntent(context: context)) {
                        Label("停止", systemImage: "stop.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .tint(.red)
                }
            } compactLeading: {
                Circle()
                    .fill(color(for: context.attributes.projectColorHex))
                    .frame(width: 8, height: 8)
            } compactTrailing: {
                Text(timerInterval: context.attributes.startedAt...Date.distantFuture, countsDown: false)
                    .font(.caption.monospacedDigit())
                    .frame(width: 50)
            } minimal: {
                Text(timerInterval: context.attributes.startedAt...Date.distantFuture, countsDown: false)
                    .font(.caption2.monospacedDigit())
            }
        }
    }

    private func stopIntent(context: ActivityViewContext<TogglFocusAttributes>) -> StopRunningEntryIntent {
        StopRunningEntryIntent(
            entryId: context.attributes.entryId,
            workspaceId: context.attributes.workspaceId,
            projectId: context.attributes.projectId,
            activityId: context.activityID
        )
    }

    private func color(for hex: String?) -> Color {
        guard let hex, let c = Color(hex: hex) else { return .accentColor }
        return c
    }
}

private struct LockScreenView: View {
    let context: ActivityViewContext<TogglFocusAttributes>

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Circle()
                        .fill(Color(hex: context.attributes.projectColorHex ?? "") ?? .accentColor)
                        .frame(width: 8, height: 8)
                    Text(context.attributes.projectName)
                        .font(.caption.weight(.semibold))
                        .lineLimit(1)
                }
                Text(context.state.description.isEmpty ? "(no description)" : context.state.description)
                    .font(.body)
                    .lineLimit(2)
                Text(timerInterval: context.attributes.startedAt...Date.distantFuture, countsDown: false)
                    .font(.title3.monospacedDigit())
            }
            Spacer()
            Button(intent: StopRunningEntryIntent(
                entryId: context.attributes.entryId,
                workspaceId: context.attributes.workspaceId,
                projectId: context.attributes.projectId,
                activityId: context.activityID
            )) {
                Image(systemName: "stop.fill")
                    .imageScale(.large)
                    .padding(10)
            }
            .buttonStyle(.borderedProminent)
            .tint(.red)
        }
        .padding()
    }
}

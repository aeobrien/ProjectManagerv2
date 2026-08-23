import WidgetKit
import SwiftUI

/// Timeline entry for the Quick Capture widget.
struct QuickCaptureEntry: TimelineEntry {
    let date: Date
    let projectCount: Int
    let focusedProjectName: String?
}

/// Timeline provider that supplies widget data.
struct QuickCaptureProvider: TimelineProvider {
    func placeholder(in context: Context) -> QuickCaptureEntry {
        QuickCaptureEntry(date: Date(), projectCount: 0, focusedProjectName: "My Project")
    }

    func getSnapshot(in context: Context, completion: @escaping (QuickCaptureEntry) -> Void) {
        let entry = QuickCaptureEntry(
            date: Date(),
            projectCount: readProjectCount(),
            focusedProjectName: readFocusedProjectName()
        )
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<QuickCaptureEntry>) -> Void) {
        let entry = QuickCaptureEntry(
            date: Date(),
            projectCount: readProjectCount(),
            focusedProjectName: readFocusedProjectName()
        )
        // Refresh every 30 minutes
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 30, to: Date())!
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }

    /// Read project count from shared UserDefaults (App Group).
    private func readProjectCount() -> Int {
        let defaults = UserDefaults(suiteName: "group.com.aeobrien.projectmanager.shared")
        return defaults?.integer(forKey: "projectCount") ?? 0
    }

    /// Read focused project name from shared UserDefaults (App Group).
    private func readFocusedProjectName() -> String? {
        let defaults = UserDefaults(suiteName: "group.com.aeobrien.projectmanager.shared")
        return defaults?.string(forKey: "focusedProjectName")
    }
}

/// The Quick Capture widget view.
struct QuickCaptureWidgetEntryView: View {
    var entry: QuickCaptureProvider.Entry

    @Environment(\.widgetFamily) var family

    var body: some View {
        switch family {
        case .systemSmall:
            smallView
        case .systemMedium:
            mediumView
        default:
            smallView
        }
    }

    private var smallView: some View {
        VStack(spacing: 8) {
            Image(systemName: "bolt.fill")
                .font(.title2)
                .foregroundStyle(.blue)

            Text("Quick Capture")
                .font(.caption)
                .fontWeight(.semibold)

            if let name = entry.focusedProjectName {
                Text(name)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .widgetURL(URL(string: "projectmanager://quickcapture"))
    }

    private var mediumView: some View {
        HStack {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "bolt.fill")
                        .foregroundStyle(.blue)
                    Text("Quick Capture")
                        .font(.headline)
                }

                if let name = entry.focusedProjectName {
                    Text("Focused: \(name)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Text("\(entry.projectCount) projects")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(spacing: 8) {
                Link(destination: URL(string: "projectmanager://quickcapture")!) {
                    Label("Capture", systemImage: "plus.circle.fill")
                        .font(.caption)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(.blue.opacity(0.15))
                        .clipShape(Capsule())
                }

                Link(destination: URL(string: "projectmanager://focusboard")!) {
                    Label("Focus", systemImage: "target")
                        .font(.caption)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(.green.opacity(0.15))
                        .clipShape(Capsule())
                }
            }
        }
        .padding()
        .widgetURL(URL(string: "projectmanager://quickcapture"))
    }
}

/// The widget configuration.
struct QuickCaptureWidget: Widget {
    let kind: String = "QuickCaptureWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: QuickCaptureProvider()) { entry in
            QuickCaptureWidgetEntryView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Quick Capture")
        .description("Quickly capture ideas and tasks for your projects.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

// MARK: - Widget Bundle

@main
struct QuickCaptureWidgetBundle: WidgetBundle {
    var body: some Widget {
        QuickCaptureWidget()
    }
}

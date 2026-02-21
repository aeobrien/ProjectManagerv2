import SwiftUI

/// The sidebar navigation sections for the app.
public enum NavigationSection: String, CaseIterable, Identifiable, Sendable {
    case focusBoard = "Focus Board"
    case allProjects = "All Projects"
    case quickCapture = "Quick Capture"
    case crossProjectRoadmap = "Roadmap"
    case aiChat = "AI Chat"
    case settings = "Settings"

    public var id: String { rawValue }

    public var iconName: String {
        switch self {
        case .focusBoard: "square.grid.2x2"
        case .allProjects: "folder"
        case .quickCapture: "plus.circle"
        case .crossProjectRoadmap: "map"
        case .aiChat: "bubble.left.and.bubble.right"
        case .settings: "gear"
        }
    }

    public var isMainSection: Bool {
        switch self {
        case .focusBoard, .allProjects, .quickCapture, .crossProjectRoadmap, .aiChat: true
        case .settings: false
        }
    }
}

/// The root navigation shell for the macOS app.
public struct AppNavigationView<
    FocusBoardContent: View,
    ProjectBrowserContent: View,
    QuickCaptureContent: View,
    CrossProjectRoadmapContent: View,
    AIChatContent: View,
    SettingsContent: View
>: View {
    @State private var selectedSection: NavigationSection? = .focusBoard

    let focusBoard: () -> FocusBoardContent
    let projectBrowser: () -> ProjectBrowserContent
    let quickCapture: () -> QuickCaptureContent
    let crossProjectRoadmap: () -> CrossProjectRoadmapContent
    let aiChat: () -> AIChatContent
    let settings: () -> SettingsContent

    public init(
        @ViewBuilder focusBoard: @escaping () -> FocusBoardContent,
        @ViewBuilder projectBrowser: @escaping () -> ProjectBrowserContent,
        @ViewBuilder quickCapture: @escaping () -> QuickCaptureContent,
        @ViewBuilder crossProjectRoadmap: @escaping () -> CrossProjectRoadmapContent,
        @ViewBuilder aiChat: @escaping () -> AIChatContent,
        @ViewBuilder settings: @escaping () -> SettingsContent
    ) {
        self.focusBoard = focusBoard
        self.projectBrowser = projectBrowser
        self.quickCapture = quickCapture
        self.crossProjectRoadmap = crossProjectRoadmap
        self.aiChat = aiChat
        self.settings = settings
    }

    public var body: some View {
        NavigationSplitView {
            List(selection: $selectedSection) {
                Section("Main") {
                    ForEach(NavigationSection.allCases.filter(\.isMainSection)) { section in
                        Label(section.rawValue, systemImage: section.iconName)
                            .tag(section)
                    }
                }

                Section {
                    Label(NavigationSection.settings.rawValue, systemImage: NavigationSection.settings.iconName)
                        .tag(NavigationSection.settings)
                }
            }
            .navigationTitle("Project Manager")
        } detail: {
            switch selectedSection {
            case .focusBoard:
                focusBoard()
            case .allProjects:
                projectBrowser()
            case .quickCapture:
                quickCapture()
            case .crossProjectRoadmap:
                crossProjectRoadmap()
            case .aiChat:
                aiChat()
            case .settings:
                settings()
            case nil:
                Text("Select a section from the sidebar.")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }
}

// MARK: - Placeholder Views for unbuilt sections

public struct PlaceholderView: View {
    let title: String
    let iconName: String
    let message: String

    public init(title: String, iconName: String, message: String) {
        self.title = title
        self.iconName = iconName
        self.message = message
    }

    public var body: some View {
        VStack(spacing: 16) {
            Image(systemName: iconName)
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text(title)
                .font(.title2)
                .fontWeight(.semibold)
            Text(message)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

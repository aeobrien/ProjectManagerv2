import SwiftUI

/// Navigation tab identifiers for the iOS app.
public enum IOSTab: String, CaseIterable, Identifiable, Sendable {
    case focusBoard = "Focus Board"
    case projects = "Projects"
    case aiChat = "AI Chat"
    case quickCapture = "Capture"
    case more = "More"

    public var id: String { rawValue }

    public var iconName: String {
        switch self {
        case .focusBoard: "square.grid.2x2"
        case .projects: "folder"
        case .aiChat: "bubble.left.and.bubble.right"
        case .quickCapture: "plus.circle.fill"
        case .more: "ellipsis.circle"
        }
    }
}

/// Tab-based root navigation for the iOS app.
public struct IOSTabNavigationView<
    FocusBoardContent: View,
    ProjectsContent: View,
    AIChatContent: View,
    QuickCaptureContent: View,
    MoreContent: View
>: View {
    @State private var selectedTab: IOSTab = .focusBoard

    let focusBoard: () -> FocusBoardContent
    let projects: () -> ProjectsContent
    let aiChat: () -> AIChatContent
    let quickCapture: () -> QuickCaptureContent
    let more: () -> MoreContent

    public init(
        @ViewBuilder focusBoard: @escaping () -> FocusBoardContent,
        @ViewBuilder projects: @escaping () -> ProjectsContent,
        @ViewBuilder aiChat: @escaping () -> AIChatContent,
        @ViewBuilder quickCapture: @escaping () -> QuickCaptureContent,
        @ViewBuilder more: @escaping () -> MoreContent
    ) {
        self.focusBoard = focusBoard
        self.projects = projects
        self.aiChat = aiChat
        self.quickCapture = quickCapture
        self.more = more
    }

    public var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack {
                focusBoard()
            }
            .tabItem { Label(IOSTab.focusBoard.rawValue, systemImage: IOSTab.focusBoard.iconName) }
            .tag(IOSTab.focusBoard)

            NavigationStack {
                projects()
            }
            .tabItem { Label(IOSTab.projects.rawValue, systemImage: IOSTab.projects.iconName) }
            .tag(IOSTab.projects)

            NavigationStack {
                aiChat()
            }
            .tabItem { Label(IOSTab.aiChat.rawValue, systemImage: IOSTab.aiChat.iconName) }
            .tag(IOSTab.aiChat)

            NavigationStack {
                quickCapture()
            }
            .tabItem { Label(IOSTab.quickCapture.rawValue, systemImage: IOSTab.quickCapture.iconName) }
            .tag(IOSTab.quickCapture)

            NavigationStack {
                more()
            }
            .tabItem { Label(IOSTab.more.rawValue, systemImage: IOSTab.more.iconName) }
            .tag(IOSTab.more)
        }
    }
}

#Preview("iOS Tab Navigation") {
    IOSTabNavigationView {
        Text("Focus Board")
    } projects: {
        Text("Projects")
    } aiChat: {
        Text("AI Chat")
    } quickCapture: {
        Text("Quick Capture")
    } more: {
        Text("Settings")
    }
}

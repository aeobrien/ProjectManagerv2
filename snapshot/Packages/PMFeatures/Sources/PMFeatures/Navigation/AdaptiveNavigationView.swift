import SwiftUI

/// Provides platform-adaptive navigation: sidebar on macOS/iPad, tabs on iPhone.
public struct AdaptiveNavigationView<
    FocusBoardContent: View,
    ProjectsContent: View,
    QuickCaptureContent: View,
    CrossProjectRoadmapContent: View,
    AIChatContent: View,
    SettingsContent: View
>: View {
    let focusBoard: () -> FocusBoardContent
    let projects: () -> ProjectsContent
    let quickCapture: () -> QuickCaptureContent
    let crossProjectRoadmap: () -> CrossProjectRoadmapContent
    let aiChat: () -> AIChatContent
    let settings: () -> SettingsContent

    public init(
        @ViewBuilder focusBoard: @escaping () -> FocusBoardContent,
        @ViewBuilder projects: @escaping () -> ProjectsContent,
        @ViewBuilder quickCapture: @escaping () -> QuickCaptureContent,
        @ViewBuilder crossProjectRoadmap: @escaping () -> CrossProjectRoadmapContent,
        @ViewBuilder aiChat: @escaping () -> AIChatContent,
        @ViewBuilder settings: @escaping () -> SettingsContent
    ) {
        self.focusBoard = focusBoard
        self.projects = projects
        self.quickCapture = quickCapture
        self.crossProjectRoadmap = crossProjectRoadmap
        self.aiChat = aiChat
        self.settings = settings
    }

    #if !os(macOS)
    @State private var selectedTab: IOSTab = .focusBoard
    #endif

    public var body: some View {
        #if os(macOS)
        AppNavigationView(
            focusBoard: focusBoard,
            projectBrowser: projects,
            quickCapture: quickCapture,
            crossProjectRoadmap: crossProjectRoadmap,
            aiChat: aiChat,
            settings: settings
        )
        #else
        IOSTabNavigationView(
            selectedTab: $selectedTab,
            focusBoard: focusBoard,
            projects: projects,
            aiChat: aiChat,
            quickCapture: quickCapture,
            more: settings
        )
        #endif
    }
}

import SwiftUI

/// Provides platform-adaptive navigation: sidebar on macOS/iPad, tabs on iPhone.
public struct AdaptiveNavigationView<
    FocusBoardContent: View,
    ProjectsContent: View,
    AIChatContent: View,
    QuickCaptureContent: View,
    SettingsContent: View
>: View {
    let focusBoard: () -> FocusBoardContent
    let projects: () -> ProjectsContent
    let aiChat: () -> AIChatContent
    let quickCapture: () -> QuickCaptureContent
    let settings: () -> SettingsContent

    public init(
        @ViewBuilder focusBoard: @escaping () -> FocusBoardContent,
        @ViewBuilder projects: @escaping () -> ProjectsContent,
        @ViewBuilder aiChat: @escaping () -> AIChatContent,
        @ViewBuilder quickCapture: @escaping () -> QuickCaptureContent,
        @ViewBuilder settings: @escaping () -> SettingsContent
    ) {
        self.focusBoard = focusBoard
        self.projects = projects
        self.aiChat = aiChat
        self.quickCapture = quickCapture
        self.settings = settings
    }

    public var body: some View {
        #if os(macOS)
        AppNavigationView(
            focusBoard: focusBoard,
            projectBrowser: projects,
            aiChat: aiChat,
            settings: settings
        )
        #else
        IOSTabNavigationView(
            focusBoard: focusBoard,
            projects: projects,
            aiChat: aiChat,
            quickCapture: quickCapture,
            more: settings
        )
        #endif
    }
}

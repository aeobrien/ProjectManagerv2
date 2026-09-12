import SwiftUI

/// Renders a string as markdown using SwiftUI's built-in LocalizedStringKey parsing.
/// Use this for AI-authored content that may contain markdown formatting.
public struct MarkdownText: View {
    let content: String

    public init(_ content: String) {
        self.content = content
    }

    public var body: some View {
        Text(LocalizedStringKey(content))
            .textSelection(.enabled)
    }
}

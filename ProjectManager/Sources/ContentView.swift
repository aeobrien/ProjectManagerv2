import SwiftUI
import PMUtilities

struct ContentView: View {
    var body: some View {
        NavigationSplitView {
            List {
                Label("Focus Board", systemImage: "square.grid.2x2")
                Label("All Projects", systemImage: "folder")
                Label("AI Chat", systemImage: "bubble.left.and.bubble.right")

                Divider()

                Label("Settings", systemImage: "gear")
            }
            .navigationTitle("Project Manager")
        } detail: {
            VStack(spacing: 16) {
                Image(systemName: "hammer.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(.secondary)
                Text("Project Manager")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                Text("Phase 0: Scaffolding Complete")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                Text("Select a section from the sidebar to get started.")
                    .foregroundStyle(.tertiary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

#Preview {
    ContentView()
}

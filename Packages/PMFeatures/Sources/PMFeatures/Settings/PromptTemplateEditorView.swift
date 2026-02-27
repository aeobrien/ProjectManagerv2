import SwiftUI
import PMServices
import PMDesignSystem

/// Settings section for viewing and editing AI prompt templates.
struct PromptTemplateEditorView: View {
    @State private var expandedKey: PromptTemplateKey?
    @State private var editTexts: [PromptTemplateKey: String] = [:]
    private let store = PromptTemplateStore.shared

    private var groupedKeys: [(group: String, keys: [PromptTemplateKey])] {
        let groups = Dictionary(grouping: PromptTemplateKey.allCases, by: \.group)
        let order = ["Core", "Onboarding", "Check-ins", "Reviews", "Chat", "Vision Discovery", "Document Generation"]
        return order.compactMap { group in
            guard let keys = groups[group] else { return nil }
            return (group: group, keys: keys)
        }
    }

    var body: some View {
        PMCard {
            VStack(alignment: .leading, spacing: 12) {
                PMSectionHeader("Prompt Templates", subtitle: "View and edit AI system prompts. Changes take effect immediately.")

                ForEach(groupedKeys, id: \.group) { group in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(group.group)
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundStyle(.secondary)
                            .padding(.top, 4)

                        ForEach(group.keys, id: \.rawValue) { key in
                            templateRow(key)
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func templateRow(_ key: PromptTemplateKey) -> some View {
        let isExpanded = expandedKey == key
        let hasOverride = store.hasOverride(for: key)

        VStack(alignment: .leading, spacing: 6) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    if isExpanded {
                        // Save when collapsing
                        saveIfChanged(key)
                        expandedKey = nil
                    } else {
                        // Save previous if switching
                        if let prev = expandedKey {
                            saveIfChanged(prev)
                        }
                        editTexts[key] = store.template(for: key)
                        expandedKey = key
                    }
                }
            } label: {
                HStack {
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .frame(width: 12)

                    Text(key.displayName)
                        .font(.subheadline)

                    if hasOverride {
                        Text("edited")
                            .font(.caption2)
                            .foregroundStyle(.orange)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(.orange.opacity(0.1), in: Capsule())
                    }

                    Spacer()

                    if let help = key.variableHelp {
                        Text(help)
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if isExpanded {
                VStack(alignment: .leading, spacing: 4) {
                    TextEditor(text: Binding(
                        get: { editTexts[key] ?? store.template(for: key) },
                        set: { editTexts[key] = $0 }
                    ))
                    .font(.system(.caption, design: .monospaced))
                    .frame(minHeight: 150, maxHeight: 400)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .strokeBorder(.quaternary, lineWidth: 1)
                    )

                    HStack {
                        if hasOverride {
                            Button("Reset to Default") {
                                store.resetToDefault(for: key)
                                editTexts[key] = store.template(for: key)
                            }
                            .font(.caption)
                            .foregroundStyle(.orange)
                        }

                        Spacer()

                        Text("\(editTexts[key]?.count ?? 0) chars")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }
                .padding(.leading, 16)
            }
        }
    }

    private func saveIfChanged(_ key: PromptTemplateKey) {
        guard let text = editTexts[key] else { return }
        let defaultText = PromptTemplateStore.defaultTemplate(for: key)
        if text == defaultText {
            store.resetToDefault(for: key)
        } else {
            store.setOverride(text, for: key)
        }
    }
}

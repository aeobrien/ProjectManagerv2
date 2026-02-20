import SwiftUI
import PMData
import PMDesignSystem

/// Full settings panel backed by SettingsManager.
public struct SettingsView: View {
    @Bindable var settings: SettingsManager

    public init(settings: SettingsManager) {
        self.settings = settings
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                focusBoardSection
                checkInSection
                estimatesSection
                notificationsSection
                doneColumnSection
                voiceSection
                aiSection
                syncSection
                integrationSection
            }
            .padding()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Focus Board

    private var focusBoardSection: some View {
        PMCard {
            VStack(alignment: .leading, spacing: 12) {
                PMSectionHeader("Focus Board", subtitle: "Control how projects appear on your focus board")

                Stepper("Max focus slots: \(settings.maxFocusSlots)", value: $settings.maxFocusSlots, in: 1...10)
                Stepper("Max per category: \(settings.maxPerCategory)", value: $settings.maxPerCategory, in: 1...10)
                Stepper("Visible tasks per project: \(settings.maxVisibleTasksPerProject)", value: $settings.maxVisibleTasksPerProject, in: 1...10)
                Stepper("Staleness threshold (days): \(settings.stalenessThresholdDays)", value: $settings.stalenessThresholdDays, in: 1...30)
                Stepper("Return briefing after (days): \(settings.returnBriefingThresholdDays)", value: $settings.returnBriefingThresholdDays, in: 7...60)
            }
        }
    }

    // MARK: - Check-ins

    private var checkInSection: some View {
        PMCard {
            VStack(alignment: .leading, spacing: 12) {
                PMSectionHeader("Check-in Prompts", subtitle: "How often you're nudged to check in on projects")

                Stepper("Gentle prompt (days): \(settings.checkInGentlePromptDays)", value: $settings.checkInGentlePromptDays, in: 1...14)
                Stepper("Moderate prompt (days): \(settings.checkInModeratePromptDays)", value: $settings.checkInModeratePromptDays, in: 3...21)
                Stepper("Prominent prompt (days): \(settings.checkInProminentPromptDays)", value: $settings.checkInProminentPromptDays, in: 7...30)
                Stepper("Deferred threshold: \(settings.deferredThreshold)", value: $settings.deferredThreshold, in: 1...10)
            }
        }
    }

    // MARK: - Estimates

    private var estimatesSection: some View {
        PMCard {
            VStack(alignment: .leading, spacing: 12) {
                PMSectionHeader("Time Estimates", subtitle: "Adjust how estimates are calculated")

                HStack {
                    Text("Pessimism multiplier: \(settings.pessimismMultiplier, specifier: "%.1f")x")
                    Spacer()
                    Slider(value: $settings.pessimismMultiplier, in: 1.0...3.0, step: 0.1)
                        .frame(maxWidth: 200)
                }
            }
        }
    }

    // MARK: - Notifications

    private var notificationsSection: some View {
        PMCard {
            VStack(alignment: .leading, spacing: 12) {
                PMSectionHeader("Notifications", subtitle: "Control when and how you're notified")

                Toggle("Notifications enabled", isOn: $settings.notificationsEnabled)

                if settings.notificationsEnabled {
                    Stepper("Max daily: \(settings.maxDailyNotifications)", value: $settings.maxDailyNotifications, in: 1...5)

                    HStack {
                        Text("Quiet hours:")
                        Spacer()
                        Picker("Start", selection: $settings.quietHoursStart) {
                            ForEach(0..<24, id: \.self) { hour in
                                Text(formatHour(hour)).tag(hour)
                            }
                        }
                        .labelsHidden()
                        .frame(width: 80)

                        Text("to")

                        Picker("End", selection: $settings.quietHoursEnd) {
                            ForEach(0..<24, id: \.self) { hour in
                                Text(formatHour(hour)).tag(hour)
                            }
                        }
                        .labelsHidden()
                        .frame(width: 80)
                    }
                }
            }
        }
    }

    // MARK: - Done Column

    private var doneColumnSection: some View {
        PMCard {
            VStack(alignment: .leading, spacing: 12) {
                PMSectionHeader("Done Column", subtitle: "How long completed tasks stay visible")

                Stepper("Retention (days): \(settings.doneColumnRetentionDays)", value: $settings.doneColumnRetentionDays, in: 1...30)
                Stepper("Max visible items: \(settings.doneColumnMaxItems)", value: $settings.doneColumnMaxItems, in: 5...50)
            }
        }
    }

    // MARK: - Voice

    private var voiceSection: some View {
        PMCard {
            VStack(alignment: .leading, spacing: 12) {
                PMSectionHeader("Voice Input", subtitle: "Whisper transcription settings")

                Picker("Whisper model", selection: $settings.whisperModel) {
                    Text("Tiny").tag("tiny")
                    Text("Base").tag("base")
                    Text("Small").tag("small")
                    Text("Medium").tag("medium")
                    Text("Large").tag("large")
                }
                .pickerStyle(.segmented)
            }
        }
    }

    // MARK: - AI

    private var aiSection: some View {
        PMCard {
            VStack(alignment: .leading, spacing: 12) {
                PMSectionHeader("AI Assistant", subtitle: "Configure AI model and trust level")

                TextField("Model identifier", text: $settings.aiModel)
                    .textFieldStyle(.roundedBorder)

                Picker("Trust level", selection: $settings.aiTrustLevel) {
                    Text("Confirm All").tag("confirmAll")
                    Text("Confirm Destructive").tag("confirmDestructive")
                    Text("Auto").tag("auto")
                }
            }
        }
    }

    // MARK: - Sync

    private var syncSection: some View {
        PMCard {
            VStack(alignment: .leading, spacing: 12) {
                PMSectionHeader("Life Planner Sync", subtitle: "Sync projects with external life planner")

                Toggle("Enable sync", isOn: $settings.lifePlannerSyncEnabled)

                if settings.lifePlannerSyncEnabled {
                    Picker("Sync method", selection: $settings.lifePlannerSyncMethod) {
                        Text("MySQL").tag("mysql")
                        Text("REST API").tag("rest")
                        Text("File Export").tag("file")
                    }
                }
            }
        }
    }

    // MARK: - Integration API

    private var integrationSection: some View {
        PMCard {
            VStack(alignment: .leading, spacing: 12) {
                PMSectionHeader("Integration API", subtitle: "Local REST API for external tools")

                Toggle("Enable API", isOn: $settings.integrationAPIEnabled)

                if settings.integrationAPIEnabled {
                    Stepper("Port: \(settings.integrationAPIPort)", value: $settings.integrationAPIPort, in: 1024...65535)
                }
            }
        }
    }

    // MARK: - Helpers

    private func formatHour(_ hour: Int) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "ha"
        var components = DateComponents()
        components.hour = hour
        let date = Calendar.current.date(from: components) ?? Date()
        return formatter.string(from: date)
    }
}

// MARK: - Preview

#Preview("Settings") {
    SettingsView(settings: SettingsManager())
        .frame(width: 500, height: 700)
}

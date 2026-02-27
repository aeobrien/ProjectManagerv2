import SwiftUI
import PMData
import PMServices
import PMDesignSystem
import PMDomain

/// Full settings panel backed by SettingsManager.
public struct SettingsView: View {
    @Bindable var settings: SettingsManager
    var exportService: ExportService?
    var syncManager: SyncManager?
    var migrationViewModelFactory: (() -> MigrationViewModel)?
    var onboardingManager: OnboardingFlowManager?
    var categories: [PMDomain.Category] = []
    var aiDevScreenViewModelFactory: (() -> AIDevScreenViewModel)?
    @State private var exportStatus: ExportStatus?
    @State private var isExporting = false
    @State private var showMigration = false
    @State private var showOnboarding = false
    @State private var showAIDevScreen = false

    public init(
        settings: SettingsManager,
        exportService: ExportService? = nil,
        syncManager: SyncManager? = nil,
        migrationViewModelFactory: (() -> MigrationViewModel)? = nil,
        onboardingManager: OnboardingFlowManager? = nil,
        categories: [PMDomain.Category] = [],
        aiDevScreenViewModelFactory: (() -> AIDevScreenViewModel)? = nil
    ) {
        self.settings = settings
        self.exportService = exportService
        self.syncManager = syncManager
        self.migrationViewModelFactory = migrationViewModelFactory
        self.onboardingManager = onboardingManager
        self.categories = categories
        self.aiDevScreenViewModelFactory = aiDevScreenViewModelFactory
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
                promptTemplatesSection
                importSection
                exportSection
                syncSection
                lifePlannerSyncSection
                integrationSection
                #if DEBUG
                aiDevSection
                #endif
            }
            .padding()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .sheet(isPresented: $showMigration) {
            if let factory = migrationViewModelFactory {
                MigrationView(viewModel: factory()) { markdown, repoURL, name in
                    // Pre-fill onboarding and switch sheets
                    if let mgr = onboardingManager {
                        mgr.reset()
                        mgr.brainDumpText = markdown
                        mgr.repoURL = repoURL
                        mgr.isFromImport = true
                        mgr.suggestedProjectName = name
                    }
                    showMigration = false
                    showOnboarding = true
                }
            }
        }
        .sheet(isPresented: $showAIDevScreen) {
            if let factory = aiDevScreenViewModelFactory {
                AIDevScreenView(viewModel: factory())
            }
        }
        .sheet(isPresented: $showOnboarding) {
            if let mgr = onboardingManager {
                OnboardingView(manager: mgr, categories: categories)
                    #if os(macOS)
                    .frame(minWidth: 700, idealWidth: 800, minHeight: 600)
                    #endif
            }
        }
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

                    Divider()

                    Text("Notification Types")
                        .font(.subheadline)
                        .fontWeight(.medium)

                    Toggle("Waiting items past check-back date", isOn: $settings.notifyWaitingCheckBack)
                    Toggle("Deadlines approaching (24h)", isOn: $settings.notifyDeadlineApproaching)
                    Toggle("Check-in reminders", isOn: $settings.notifyCheckInReminder)
                    Toggle("Phase completion", isOn: $settings.notifyPhaseCompletion)
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

                Picker("Provider", selection: $settings.aiProvider) {
                    Text("Anthropic").tag("anthropic")
                    Text("OpenAI").tag("openai")
                }

                SecureField("API Key", text: $settings.aiApiKey)
                    .textFieldStyle(.roundedBorder)

                TextField("Model identifier", text: $settings.aiModel)
                    .textFieldStyle(.roundedBorder)

                Picker("Trust level", selection: $settings.aiTrustLevel) {
                    Text("Confirm All").tag("confirmAll")
                    Text("Auto-apply Minor").tag("autoMinor")
                    Text("Auto-apply All").tag("autoAll")
                }
            }
        }
    }

    // MARK: - Prompt Templates

    private var promptTemplatesSection: some View {
        PromptTemplateEditorView()
    }

    // MARK: - Import

    private var importSection: some View {
        PMCard {
            VStack(alignment: .leading, spacing: 12) {
                PMSectionHeader("Import Projects", subtitle: "Import projects from markdown files")

                Text("Each .md file will be fed into the onboarding flow, where the AI will help you structure it into a full project.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Button {
                    showMigration = true
                } label: {
                    Label("Import from Markdown", systemImage: "square.and.arrow.down")
                }
                .disabled(migrationViewModelFactory == nil)
            }
        }
    }

    // MARK: - Export

    private var exportSection: some View {
        PMCard {
            VStack(alignment: .leading, spacing: 12) {
                PMSectionHeader("Data Export", subtitle: "Export project data for external tools")

                if let exportService {
                    HStack {
                        Button {
                            Task {
                                isExporting = true
                                _ = await exportService.triggerLifePlannerExport()
                                exportStatus = await exportService.currentStatus()
                                isExporting = false
                            }
                        } label: {
                            if isExporting {
                                ProgressView()
                                    .controlSize(.small)
                            } else {
                                Label("Export Now", systemImage: "square.and.arrow.up")
                            }
                        }
                        .disabled(isExporting)

                        Spacer()

                        if let status = exportStatus {
                            VStack(alignment: .trailing, spacing: 2) {
                                if let result = status.lastResult {
                                    HStack(spacing: 4) {
                                        Image(systemName: result == .success ? "checkmark.circle.fill" : "xmark.circle.fill")
                                            .foregroundStyle(result == .success ? .green : .red)
                                        Text(result == .success ? "Success" : result.rawValue)
                                            .font(.caption)
                                    }
                                }
                                if let date = status.lastExportDate {
                                    Text(date, style: .relative)
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                                Text("\(status.exportCount) total exports")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                } else {
                    Text("Export service not configured")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    // MARK: - CloudKit Sync

    private var syncSection: some View {
        PMCard {
            VStack(alignment: .leading, spacing: 12) {
                PMSectionHeader("iCloud Sync", subtitle: "Sync data across your devices via CloudKit")

                Toggle("Enable iCloud sync", isOn: $settings.syncEnabled)

                if let syncManager {
                    HStack {
                        if syncManager.isSyncing {
                            ProgressView()
                                .controlSize(.small)
                            Text("Syncing...")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        } else if let lastSync = syncManager.lastSyncDate {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                            Text("Last sync: \(lastSync, style: .relative) ago")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        } else {
                            Image(systemName: "icloud.slash")
                                .foregroundStyle(.secondary)
                            Text("Not yet synced")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        if syncManager.pendingChangeCount > 0 {
                            Text("\(syncManager.pendingChangeCount) pending")
                                .font(.caption)
                                .foregroundStyle(.orange)
                        }
                    }

                    if let error = syncManager.error {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }

                    Button {
                        Task { await syncManager.syncNow() }
                    } label: {
                        Label("Sync Now", systemImage: "arrow.triangle.2.circlepath")
                    }
                    .disabled(!settings.syncEnabled || syncManager.isSyncing)
                }
            }
        }
    }

    // MARK: - Life Planner Sync

    private var lifePlannerSyncSection: some View {
        PMCard {
            VStack(alignment: .leading, spacing: 12) {
                PMSectionHeader("Life Planner Sync", subtitle: "Export focused project data to your Life Planner")

                Toggle("Enable sync", isOn: $settings.lifePlannerSyncEnabled)

                if settings.lifePlannerSyncEnabled {
                    Picker("Export method", selection: $settings.lifePlannerSyncMethod) {
                        Text("REST API").tag("rest")
                        Text("File Export").tag("file")
                        Text("MySQL").tag("mysql")
                    }

                    switch settings.lifePlannerSyncMethod {
                    case "rest":
                        TextField("API endpoint", text: $settings.lifePlannerAPIEndpoint)
                            .textFieldStyle(.roundedBorder)
                        SecureField("API key (optional)", text: $settings.lifePlannerAPIKey)
                            .textFieldStyle(.roundedBorder)
                    case "file":
                        TextField("Export file path", text: $settings.lifePlannerFilePath)
                            .textFieldStyle(.roundedBorder)
                    case "mysql":
                        Text("MySQL export requires a running MySQL server. Configure connection details in a future update.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    default:
                        EmptyView()
                    }

                    if let exportService {
                        Divider()

                        HStack {
                            Button {
                                Task {
                                    isExporting = true
                                    await exportService.triggerLifePlannerExport()
                                    exportStatus = await exportService.currentStatus()
                                    isExporting = false
                                }
                            } label: {
                                if isExporting {
                                    ProgressView()
                                        .controlSize(.small)
                                } else {
                                    Label("Export Now", systemImage: "square.and.arrow.up")
                                }
                            }
                            .disabled(isExporting)

                            Spacer()

                            if let status = exportStatus {
                                lifePlannerStatusView(status)
                            }
                        }
                    }
                }
            }
        }
    }

    private func lifePlannerStatusView(_ status: ExportStatus) -> some View {
        VStack(alignment: .trailing, spacing: 2) {
            if let result = status.lastResult {
                HStack(spacing: 4) {
                    Image(systemName: result == .success ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundStyle(result == .success ? .green : .red)
                    Text(result == .success ? "Success" : result.rawValue)
                        .font(.caption)
                }
            }
            if let date = status.lastExportDate {
                Text(date, style: .relative)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
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
                    SecureField("API key (optional)", text: $settings.integrationAPIKey)
                        .textFieldStyle(.roundedBorder)
                }
            }
        }
    }

    // MARK: - AI Dev Screen

    #if DEBUG
    private var aiDevSection: some View {
        PMCard {
            VStack(alignment: .leading, spacing: 12) {
                PMSectionHeader("AI System V2 (Dev)", subtitle: "Development testing screen for the V2 AI pipeline")

                Button {
                    showAIDevScreen = true
                } label: {
                    Label("Open Dev Screen", systemImage: "terminal")
                }
                .disabled(aiDevScreenViewModelFactory == nil)
            }
        }
    }
    #endif

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

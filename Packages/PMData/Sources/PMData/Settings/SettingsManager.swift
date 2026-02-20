import Foundation
import SwiftUI

/// Observable settings store backed by UserDefaults.
/// All configurable values from the technical brief section 16.1.
@Observable
@MainActor
public final class SettingsManager {
    private let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        registerDefaults()
    }

    private func registerDefaults() {
        defaults.register(defaults: [
            Keys.maxFocusSlots: 5,
            Keys.maxPerCategory: 2,
            Keys.maxVisibleTasksPerProject: 3,
            Keys.stalenessThresholdDays: 7,
            Keys.checkInGentlePromptDays: 3,
            Keys.checkInModeratePromptDays: 7,
            Keys.checkInProminentPromptDays: 14,
            Keys.pessimismMultiplier: 1.5,
            Keys.deferredThreshold: 3,
            Keys.whisperModel: "small",
            Keys.aiModel: "",
            Keys.aiTrustLevel: "confirmAll",
            Keys.notificationsEnabled: true,
            Keys.maxDailyNotifications: 2,
            Keys.quietHoursStart: 20,
            Keys.quietHoursEnd: 9,
            Keys.lifePlannerSyncEnabled: false,
            Keys.lifePlannerSyncMethod: "mysql",
            Keys.integrationAPIEnabled: false,
            Keys.integrationAPIPort: 8420,
            Keys.returnBriefingThresholdDays: 14,
            Keys.doneColumnRetentionDays: 7,
            Keys.doneColumnMaxItems: 20,
        ])
    }

    // MARK: - Focus Board

    public var maxFocusSlots: Int {
        get { defaults.integer(forKey: Keys.maxFocusSlots).clamped(to: 1...10) }
        set { defaults.set(newValue.clamped(to: 1...10), forKey: Keys.maxFocusSlots) }
    }

    public var maxPerCategory: Int {
        get { defaults.integer(forKey: Keys.maxPerCategory).clamped(to: 1...10) }
        set { defaults.set(newValue.clamped(to: 1...10), forKey: Keys.maxPerCategory) }
    }

    public var maxVisibleTasksPerProject: Int {
        get { defaults.integer(forKey: Keys.maxVisibleTasksPerProject).clamped(to: 1...10) }
        set { defaults.set(newValue.clamped(to: 1...10), forKey: Keys.maxVisibleTasksPerProject) }
    }

    public var stalenessThresholdDays: Int {
        get { defaults.integer(forKey: Keys.stalenessThresholdDays).clamped(to: 1...30) }
        set { defaults.set(newValue.clamped(to: 1...30), forKey: Keys.stalenessThresholdDays) }
    }

    public var returnBriefingThresholdDays: Int {
        get { defaults.integer(forKey: Keys.returnBriefingThresholdDays).clamped(to: 7...60) }
        set { defaults.set(newValue.clamped(to: 7...60), forKey: Keys.returnBriefingThresholdDays) }
    }

    public var doneColumnRetentionDays: Int {
        get { defaults.integer(forKey: Keys.doneColumnRetentionDays).clamped(to: 1...30) }
        set { defaults.set(newValue.clamped(to: 1...30), forKey: Keys.doneColumnRetentionDays) }
    }

    public var doneColumnMaxItems: Int {
        get { defaults.integer(forKey: Keys.doneColumnMaxItems).clamped(to: 5...50) }
        set { defaults.set(newValue.clamped(to: 5...50), forKey: Keys.doneColumnMaxItems) }
    }

    // MARK: - Check-ins

    public var checkInGentlePromptDays: Int {
        get { defaults.integer(forKey: Keys.checkInGentlePromptDays).clamped(to: 1...14) }
        set { defaults.set(newValue.clamped(to: 1...14), forKey: Keys.checkInGentlePromptDays) }
    }

    public var checkInModeratePromptDays: Int {
        get { defaults.integer(forKey: Keys.checkInModeratePromptDays).clamped(to: 3...21) }
        set { defaults.set(newValue.clamped(to: 3...21), forKey: Keys.checkInModeratePromptDays) }
    }

    public var checkInProminentPromptDays: Int {
        get { defaults.integer(forKey: Keys.checkInProminentPromptDays).clamped(to: 7...30) }
        set { defaults.set(newValue.clamped(to: 7...30), forKey: Keys.checkInProminentPromptDays) }
    }

    public var deferredThreshold: Int {
        get { defaults.integer(forKey: Keys.deferredThreshold).clamped(to: 1...10) }
        set { defaults.set(newValue.clamped(to: 1...10), forKey: Keys.deferredThreshold) }
    }

    // MARK: - Estimates

    public var pessimismMultiplier: Double {
        get { defaults.double(forKey: Keys.pessimismMultiplier).clamped(to: 1.0...3.0) }
        set { defaults.set(newValue.clamped(to: 1.0...3.0), forKey: Keys.pessimismMultiplier) }
    }

    // MARK: - Voice

    public var whisperModel: String {
        get { defaults.string(forKey: Keys.whisperModel) ?? "small" }
        set { defaults.set(newValue, forKey: Keys.whisperModel) }
    }

    // MARK: - AI

    public var aiModel: String {
        get { defaults.string(forKey: Keys.aiModel) ?? "" }
        set { defaults.set(newValue, forKey: Keys.aiModel) }
    }

    public var aiTrustLevel: String {
        get { defaults.string(forKey: Keys.aiTrustLevel) ?? "confirmAll" }
        set { defaults.set(newValue, forKey: Keys.aiTrustLevel) }
    }

    // MARK: - Notifications

    public var notificationsEnabled: Bool {
        get { defaults.bool(forKey: Keys.notificationsEnabled) }
        set { defaults.set(newValue, forKey: Keys.notificationsEnabled) }
    }

    public var maxDailyNotifications: Int {
        get { defaults.integer(forKey: Keys.maxDailyNotifications).clamped(to: 1...5) }
        set { defaults.set(newValue.clamped(to: 1...5), forKey: Keys.maxDailyNotifications) }
    }

    public var quietHoursStart: Int {
        get { defaults.integer(forKey: Keys.quietHoursStart).clamped(to: 0...23) }
        set { defaults.set(newValue.clamped(to: 0...23), forKey: Keys.quietHoursStart) }
    }

    public var quietHoursEnd: Int {
        get { defaults.integer(forKey: Keys.quietHoursEnd).clamped(to: 0...23) }
        set { defaults.set(newValue.clamped(to: 0...23), forKey: Keys.quietHoursEnd) }
    }

    // MARK: - Sync

    public var lifePlannerSyncEnabled: Bool {
        get { defaults.bool(forKey: Keys.lifePlannerSyncEnabled) }
        set { defaults.set(newValue, forKey: Keys.lifePlannerSyncEnabled) }
    }

    public var lifePlannerSyncMethod: String {
        get { defaults.string(forKey: Keys.lifePlannerSyncMethod) ?? "mysql" }
        set { defaults.set(newValue, forKey: Keys.lifePlannerSyncMethod) }
    }

    // MARK: - Integration API

    public var integrationAPIEnabled: Bool {
        get { defaults.bool(forKey: Keys.integrationAPIEnabled) }
        set { defaults.set(newValue, forKey: Keys.integrationAPIEnabled) }
    }

    public var integrationAPIPort: Int {
        get { defaults.integer(forKey: Keys.integrationAPIPort).clamped(to: 1024...65535) }
        set { defaults.set(newValue.clamped(to: 1024...65535), forKey: Keys.integrationAPIPort) }
    }
}

// MARK: - Keys

private enum Keys {
    static let maxFocusSlots = "settings.maxFocusSlots"
    static let maxPerCategory = "settings.maxPerCategory"
    static let maxVisibleTasksPerProject = "settings.maxVisibleTasksPerProject"
    static let stalenessThresholdDays = "settings.stalenessThresholdDays"
    static let checkInGentlePromptDays = "settings.checkInGentlePromptDays"
    static let checkInModeratePromptDays = "settings.checkInModeratePromptDays"
    static let checkInProminentPromptDays = "settings.checkInProminentPromptDays"
    static let pessimismMultiplier = "settings.pessimismMultiplier"
    static let deferredThreshold = "settings.deferredThreshold"
    static let whisperModel = "settings.whisperModel"
    static let aiModel = "settings.aiModel"
    static let aiTrustLevel = "settings.aiTrustLevel"
    static let notificationsEnabled = "settings.notificationsEnabled"
    static let maxDailyNotifications = "settings.maxDailyNotifications"
    static let quietHoursStart = "settings.quietHoursStart"
    static let quietHoursEnd = "settings.quietHoursEnd"
    static let lifePlannerSyncEnabled = "settings.lifePlannerSyncEnabled"
    static let lifePlannerSyncMethod = "settings.lifePlannerSyncMethod"
    static let integrationAPIEnabled = "settings.integrationAPIEnabled"
    static let integrationAPIPort = "settings.integrationAPIPort"
    static let returnBriefingThresholdDays = "settings.returnBriefingThresholdDays"
    static let doneColumnRetentionDays = "settings.doneColumnRetentionDays"
    static let doneColumnMaxItems = "settings.doneColumnMaxItems"
}

// MARK: - Comparable clamping

private extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}

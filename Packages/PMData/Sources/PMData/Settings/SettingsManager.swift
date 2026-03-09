import Foundation
import SwiftUI
import PMUtilities

/// Observable settings store backed by UserDefaults.
/// All configurable values from the technical brief section 16.1.
///
/// Properties are stored (not computed) so `@Observable` can track them.
/// Each property writes back to UserDefaults via `didSet`.
@Observable
@MainActor
public final class SettingsManager {
    private let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        registerDefaults()
        loadFromDefaults()
        observeCloudKeyValueChanges()
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
            Keys.aiModel: "claude-opus-4-6",
            Keys.aiTrustLevel: "confirmAll",
            Keys.aiProvider: "anthropic",
            Keys.notificationsEnabled: true,
            Keys.maxDailyNotifications: 2,
            Keys.quietHoursStart: 21,
            Keys.quietHoursEnd: 9,
            Keys.notifyWaitingCheckBack: true,
            Keys.notifyDeadlineApproaching: true,
            Keys.notifyCheckInReminder: true,
            Keys.notifyPhaseCompletion: true,
            Keys.syncEnabled: false,
            Keys.lifePlannerSyncEnabled: false,
            Keys.lifePlannerSyncMethod: "mysql",
            Keys.lifePlannerAPIEndpoint: "",
            Keys.lifePlannerFilePath: "",
            Keys.integrationAPIEnabled: false,
            Keys.integrationAPIPort: 8420,
            Keys.defaultCodebaseSizeLimitMB: 25,
            Keys.returnBriefingThresholdDays: 14,
            Keys.doneColumnRetentionDays: 7,
            Keys.doneColumnMaxItems: 20,
        ])
    }

    private func loadFromDefaults() {
        maxFocusSlots = defaults.integer(forKey: Keys.maxFocusSlots).clamped(to: 1...10)
        maxPerCategory = defaults.integer(forKey: Keys.maxPerCategory).clamped(to: 1...10)
        maxVisibleTasksPerProject = defaults.integer(forKey: Keys.maxVisibleTasksPerProject).clamped(to: 1...10)
        stalenessThresholdDays = defaults.integer(forKey: Keys.stalenessThresholdDays).clamped(to: 1...30)
        returnBriefingThresholdDays = defaults.integer(forKey: Keys.returnBriefingThresholdDays).clamped(to: 7...60)
        doneColumnRetentionDays = defaults.integer(forKey: Keys.doneColumnRetentionDays).clamped(to: 1...30)
        doneColumnMaxItems = defaults.integer(forKey: Keys.doneColumnMaxItems).clamped(to: 5...50)
        checkInGentlePromptDays = defaults.integer(forKey: Keys.checkInGentlePromptDays).clamped(to: 1...14)
        checkInModeratePromptDays = defaults.integer(forKey: Keys.checkInModeratePromptDays).clamped(to: 3...21)
        checkInProminentPromptDays = defaults.integer(forKey: Keys.checkInProminentPromptDays).clamped(to: 7...30)
        deferredThreshold = defaults.integer(forKey: Keys.deferredThreshold).clamped(to: 1...10)
        pessimismMultiplier = defaults.double(forKey: Keys.pessimismMultiplier).clamped(to: 1.0...3.0)
        whisperModel = defaults.string(forKey: Keys.whisperModel) ?? "small"
        aiModel = defaults.string(forKey: Keys.aiModel) ?? "claude-opus-4-6"
        aiTrustLevel = defaults.string(forKey: Keys.aiTrustLevel) ?? "confirmAll"
        aiProvider = defaults.string(forKey: Keys.aiProvider) ?? "anthropic"
        aiApiKey = loadSecretKey(Keys.aiApiKey, syncFromCloud: true)
        notificationsEnabled = defaults.bool(forKey: Keys.notificationsEnabled)
        maxDailyNotifications = defaults.integer(forKey: Keys.maxDailyNotifications).clamped(to: 1...5)
        quietHoursStart = defaults.integer(forKey: Keys.quietHoursStart).clamped(to: 0...23)
        quietHoursEnd = defaults.integer(forKey: Keys.quietHoursEnd).clamped(to: 0...23)
        notifyWaitingCheckBack = defaults.bool(forKey: Keys.notifyWaitingCheckBack)
        notifyDeadlineApproaching = defaults.bool(forKey: Keys.notifyDeadlineApproaching)
        notifyCheckInReminder = defaults.bool(forKey: Keys.notifyCheckInReminder)
        notifyPhaseCompletion = defaults.bool(forKey: Keys.notifyPhaseCompletion)
        syncEnabled = defaults.bool(forKey: Keys.syncEnabled)
        lifePlannerSyncEnabled = defaults.bool(forKey: Keys.lifePlannerSyncEnabled)
        lifePlannerSyncMethod = defaults.string(forKey: Keys.lifePlannerSyncMethod) ?? "mysql"
        lifePlannerAPIEndpoint = defaults.string(forKey: Keys.lifePlannerAPIEndpoint) ?? ""
        lifePlannerAPIKey = loadSecretKey(Keys.lifePlannerAPIKey)
        lifePlannerFilePath = defaults.string(forKey: Keys.lifePlannerFilePath) ?? ""
        integrationAPIEnabled = defaults.bool(forKey: Keys.integrationAPIEnabled)
        integrationAPIPort = defaults.integer(forKey: Keys.integrationAPIPort).clamped(to: 1024...65535)
        integrationAPIKey = loadSecretKey(Keys.integrationAPIKey)
        defaultCodebaseSizeLimitMB = defaults.integer(forKey: Keys.defaultCodebaseSizeLimitMB).clamped(to: 5...200)
    }

    // MARK: - Focus Board

    public var maxFocusSlots: Int = 5 {
        didSet { defaults.set(maxFocusSlots.clamped(to: 1...10), forKey: Keys.maxFocusSlots) }
    }

    public var maxPerCategory: Int = 2 {
        didSet { defaults.set(maxPerCategory.clamped(to: 1...10), forKey: Keys.maxPerCategory) }
    }

    public var maxVisibleTasksPerProject: Int = 3 {
        didSet { defaults.set(maxVisibleTasksPerProject.clamped(to: 1...10), forKey: Keys.maxVisibleTasksPerProject) }
    }

    public var stalenessThresholdDays: Int = 7 {
        didSet { defaults.set(stalenessThresholdDays.clamped(to: 1...30), forKey: Keys.stalenessThresholdDays) }
    }

    public var returnBriefingThresholdDays: Int = 14 {
        didSet { defaults.set(returnBriefingThresholdDays.clamped(to: 7...60), forKey: Keys.returnBriefingThresholdDays) }
    }

    public var doneColumnRetentionDays: Int = 7 {
        didSet { defaults.set(doneColumnRetentionDays.clamped(to: 1...30), forKey: Keys.doneColumnRetentionDays) }
    }

    public var doneColumnMaxItems: Int = 20 {
        didSet { defaults.set(doneColumnMaxItems.clamped(to: 5...50), forKey: Keys.doneColumnMaxItems) }
    }

    // MARK: - Check-ins

    public var checkInGentlePromptDays: Int = 3 {
        didSet { defaults.set(checkInGentlePromptDays.clamped(to: 1...14), forKey: Keys.checkInGentlePromptDays) }
    }

    public var checkInModeratePromptDays: Int = 7 {
        didSet { defaults.set(checkInModeratePromptDays.clamped(to: 3...21), forKey: Keys.checkInModeratePromptDays) }
    }

    public var checkInProminentPromptDays: Int = 14 {
        didSet { defaults.set(checkInProminentPromptDays.clamped(to: 7...30), forKey: Keys.checkInProminentPromptDays) }
    }

    public var deferredThreshold: Int = 3 {
        didSet { defaults.set(deferredThreshold.clamped(to: 1...10), forKey: Keys.deferredThreshold) }
    }

    // MARK: - Estimates

    public var pessimismMultiplier: Double = 1.5 {
        didSet { defaults.set(pessimismMultiplier.clamped(to: 1.0...3.0), forKey: Keys.pessimismMultiplier) }
    }

    // MARK: - Voice

    public var whisperModel: String = "small" {
        didSet { defaults.set(whisperModel, forKey: Keys.whisperModel) }
    }

    // MARK: - AI

    public var aiModel: String = "claude-opus-4-6" {
        didSet { defaults.set(aiModel, forKey: Keys.aiModel) }
    }

    public var aiTrustLevel: String = "confirmAll" {
        didSet { defaults.set(aiTrustLevel, forKey: Keys.aiTrustLevel) }
    }

    public var aiProvider: String = "anthropic" {
        didSet { defaults.set(aiProvider, forKey: Keys.aiProvider) }
    }

    public var aiApiKey: String = "" {
        didSet {
            KeychainHelper.save(key: Keys.aiApiKey, value: aiApiKey)
            // Sync AI API key to iCloud KV store for cross-device access
            let kvStore = NSUbiquitousKeyValueStore.default
            kvStore.set(aiApiKey, forKey: Keys.aiApiKey)
            kvStore.synchronize()
        }
    }

    // MARK: - Notifications

    public var notificationsEnabled: Bool = true {
        didSet { defaults.set(notificationsEnabled, forKey: Keys.notificationsEnabled) }
    }

    public var maxDailyNotifications: Int = 2 {
        didSet { defaults.set(maxDailyNotifications.clamped(to: 1...5), forKey: Keys.maxDailyNotifications) }
    }

    public var quietHoursStart: Int = 21 {
        didSet { defaults.set(quietHoursStart.clamped(to: 0...23), forKey: Keys.quietHoursStart) }
    }

    public var quietHoursEnd: Int = 9 {
        didSet { defaults.set(quietHoursEnd.clamped(to: 0...23), forKey: Keys.quietHoursEnd) }
    }

    public var notifyWaitingCheckBack: Bool = true {
        didSet { defaults.set(notifyWaitingCheckBack, forKey: Keys.notifyWaitingCheckBack) }
    }

    public var notifyDeadlineApproaching: Bool = true {
        didSet { defaults.set(notifyDeadlineApproaching, forKey: Keys.notifyDeadlineApproaching) }
    }

    public var notifyCheckInReminder: Bool = true {
        didSet { defaults.set(notifyCheckInReminder, forKey: Keys.notifyCheckInReminder) }
    }

    public var notifyPhaseCompletion: Bool = true {
        didSet { defaults.set(notifyPhaseCompletion, forKey: Keys.notifyPhaseCompletion) }
    }

    // MARK: - CloudKit Sync

    public var syncEnabled: Bool = false {
        didSet { defaults.set(syncEnabled, forKey: Keys.syncEnabled) }
    }

    // MARK: - Life Planner Sync

    public var lifePlannerSyncEnabled: Bool = false {
        didSet { defaults.set(lifePlannerSyncEnabled, forKey: Keys.lifePlannerSyncEnabled) }
    }

    public var lifePlannerSyncMethod: String = "mysql" {
        didSet { defaults.set(lifePlannerSyncMethod, forKey: Keys.lifePlannerSyncMethod) }
    }

    public var lifePlannerAPIEndpoint: String = "" {
        didSet { defaults.set(lifePlannerAPIEndpoint, forKey: Keys.lifePlannerAPIEndpoint) }
    }

    public var lifePlannerAPIKey: String = "" {
        didSet { KeychainHelper.save(key: Keys.lifePlannerAPIKey, value: lifePlannerAPIKey) }
    }

    public var lifePlannerFilePath: String = "" {
        didSet { defaults.set(lifePlannerFilePath, forKey: Keys.lifePlannerFilePath) }
    }

    // MARK: - Integration API

    public var integrationAPIEnabled: Bool = false {
        didSet { defaults.set(integrationAPIEnabled, forKey: Keys.integrationAPIEnabled) }
    }

    public var integrationAPIPort: Int = 8420 {
        didSet { defaults.set(integrationAPIPort.clamped(to: 1024...65535), forKey: Keys.integrationAPIPort) }
    }

    public var integrationAPIKey: String = "" {
        didSet { KeychainHelper.save(key: Keys.integrationAPIKey, value: integrationAPIKey) }
    }

    // MARK: - Codebase

    public var defaultCodebaseSizeLimitMB: Int = 25 {
        didSet { defaults.set(defaultCodebaseSizeLimitMB.clamped(to: 5...200), forKey: Keys.defaultCodebaseSizeLimitMB) }
    }

    // MARK: - Secret Key Helpers

    /// Load a secret key from Keychain, falling back to iCloud KV store (if `syncFromCloud`),
    /// then UserDefaults (migration). Migrated values are moved to Keychain and removed from UserDefaults.
    private func loadSecretKey(_ key: String, syncFromCloud: Bool = false) -> String {
        // 1. Try Keychain
        if let value = KeychainHelper.load(key: key), !value.isEmpty {
            return value
        }

        // 2. Try iCloud KV store (only for aiApiKey)
        if syncFromCloud {
            let kvStore = NSUbiquitousKeyValueStore.default
            kvStore.synchronize()
            if let cloudValue = kvStore.string(forKey: key), !cloudValue.isEmpty {
                KeychainHelper.save(key: key, value: cloudValue)
                return cloudValue
            }
        }

        // 3. Migrate from UserDefaults
        if let legacyValue = defaults.string(forKey: key), !legacyValue.isEmpty {
            KeychainHelper.save(key: key, value: legacyValue)
            defaults.removeObject(forKey: key)
            return legacyValue
        }

        return ""
    }

    /// Observe iCloud KV store changes to pick up aiApiKey updates from other devices.
    private func observeCloudKeyValueChanges() {
        NotificationCenter.default.addObserver(
            forName: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
            object: NSUbiquitousKeyValueStore.default,
            queue: .main
        ) { [weak self] notification in
            guard let changedKeys = notification.userInfo?[NSUbiquitousKeyValueStoreChangedKeysKey] as? [String] else { return }
            if changedKeys.contains(Keys.aiApiKey) {
                if let cloudValue = NSUbiquitousKeyValueStore.default.string(forKey: Keys.aiApiKey), !cloudValue.isEmpty {
                    KeychainHelper.save(key: Keys.aiApiKey, value: cloudValue)
                    MainActor.assumeIsolated {
                        self?.aiApiKey = cloudValue
                    }
                }
            }
        }
        // Trigger initial sync
        NSUbiquitousKeyValueStore.default.synchronize()
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
    static let aiProvider = "settings.aiProvider"
    static let aiApiKey = "settings.aiApiKey"
    static let notificationsEnabled = "settings.notificationsEnabled"
    static let maxDailyNotifications = "settings.maxDailyNotifications"
    static let quietHoursStart = "settings.quietHoursStart"
    static let quietHoursEnd = "settings.quietHoursEnd"
    static let notifyWaitingCheckBack = "settings.notifyWaitingCheckBack"
    static let notifyDeadlineApproaching = "settings.notifyDeadlineApproaching"
    static let notifyCheckInReminder = "settings.notifyCheckInReminder"
    static let notifyPhaseCompletion = "settings.notifyPhaseCompletion"
    static let syncEnabled = "settings.syncEnabled"
    static let lifePlannerSyncEnabled = "settings.lifePlannerSyncEnabled"
    static let lifePlannerSyncMethod = "settings.lifePlannerSyncMethod"
    static let lifePlannerAPIEndpoint = "settings.lifePlannerAPIEndpoint"
    static let lifePlannerAPIKey = "settings.lifePlannerAPIKey"
    static let lifePlannerFilePath = "settings.lifePlannerFilePath"
    static let integrationAPIEnabled = "settings.integrationAPIEnabled"
    static let integrationAPIPort = "settings.integrationAPIPort"
    static let integrationAPIKey = "settings.integrationAPIKey"
    static let defaultCodebaseSizeLimitMB = "settings.defaultCodebaseSizeLimitMB"
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

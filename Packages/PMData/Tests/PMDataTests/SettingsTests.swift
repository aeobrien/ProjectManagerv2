import Testing
import Foundation
@testable import PMData

@Suite("SettingsManager")
struct SettingsManagerTests {

    @MainActor func freshSettings() -> SettingsManager {
        let defaults = UserDefaults(suiteName: UUID().uuidString)!
        return SettingsManager(defaults: defaults)
    }

    @Test("Default values match technical brief")
    @MainActor
    func defaultValues() {
        let s = freshSettings()
        #expect(s.maxFocusSlots == 5)
        #expect(s.maxPerCategory == 2)
        #expect(s.maxVisibleTasksPerProject == 3)
        #expect(s.stalenessThresholdDays == 7)
        #expect(s.checkInGentlePromptDays == 3)
        #expect(s.checkInModeratePromptDays == 7)
        #expect(s.checkInProminentPromptDays == 14)
        #expect(s.pessimismMultiplier == 1.5)
        #expect(s.deferredThreshold == 3)
        #expect(s.whisperModel == "small")
        #expect(s.aiModel == "")
        #expect(s.aiTrustLevel == "confirmAll")
        #expect(s.notificationsEnabled == true)
        #expect(s.maxDailyNotifications == 2)
        #expect(s.quietHoursStart == 21)
        #expect(s.quietHoursEnd == 9)
        #expect(s.lifePlannerSyncEnabled == false)
        #expect(s.lifePlannerSyncMethod == "mysql")
        #expect(s.integrationAPIEnabled == false)
        #expect(s.integrationAPIPort == 8420)
        #expect(s.returnBriefingThresholdDays == 14)
        #expect(s.doneColumnRetentionDays == 7)
        #expect(s.doneColumnMaxItems == 20)
    }

    @Test("Setting values persists")
    @MainActor
    func setAndGet() {
        let s = freshSettings()
        s.maxFocusSlots = 3
        #expect(s.maxFocusSlots == 3)

        s.pessimismMultiplier = 2.0
        #expect(s.pessimismMultiplier == 2.0)

        s.whisperModel = "medium"
        #expect(s.whisperModel == "medium")

        s.notificationsEnabled = false
        #expect(s.notificationsEnabled == false)

        s.integrationAPIPort = 9000
        #expect(s.integrationAPIPort == 9000)
    }

    @Test("Out-of-range values are clamped when loaded from defaults")
    @MainActor
    func clamping() {
        let suiteName = UUID().uuidString
        let defaults = UserDefaults(suiteName: suiteName)!
        let s = SettingsManager(defaults: defaults)

        // Set out-of-range values — they persist clamped to defaults
        s.maxFocusSlots = 0
        s.pessimismMultiplier = 0.5
        s.integrationAPIPort = 100
        s.doneColumnMaxItems = 1

        // A new instance loading from those defaults gets the clamped values
        let s2 = SettingsManager(defaults: defaults)
        #expect(s2.maxFocusSlots == 1)
        #expect(s2.pessimismMultiplier == 1.0)
        #expect(s2.integrationAPIPort == 1024)
        #expect(s2.doneColumnMaxItems == 5)

        // Also check upper bounds
        s.maxFocusSlots = 100
        s.pessimismMultiplier = 5.0
        s.integrationAPIPort = 70000

        let s3 = SettingsManager(defaults: defaults)
        #expect(s3.maxFocusSlots == 10)
        #expect(s3.pessimismMultiplier == 3.0)
        #expect(s3.integrationAPIPort == 65535)
    }

    @Test("Changes persist to UserDefaults and new instances read them")
    @MainActor
    func sharedDefaults() {
        let suiteName = UUID().uuidString
        let defaults = UserDefaults(suiteName: suiteName)!
        let s1 = SettingsManager(defaults: defaults)

        s1.maxFocusSlots = 4
        // A new instance reading the same defaults should pick up the change
        let s2 = SettingsManager(defaults: defaults)
        #expect(s2.maxFocusSlots == 4)
    }
}

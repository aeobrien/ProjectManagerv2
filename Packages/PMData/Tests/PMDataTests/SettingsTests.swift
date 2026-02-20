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
        #expect(s.quietHoursStart == 20)
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

    @Test("Values are clamped to valid ranges")
    @MainActor
    func clamping() {
        let s = freshSettings()

        s.maxFocusSlots = 0
        #expect(s.maxFocusSlots == 1) // clamped to min

        s.maxFocusSlots = 100
        #expect(s.maxFocusSlots == 10) // clamped to max

        s.pessimismMultiplier = 0.5
        #expect(s.pessimismMultiplier == 1.0)

        s.pessimismMultiplier = 5.0
        #expect(s.pessimismMultiplier == 3.0)

        s.integrationAPIPort = 100
        #expect(s.integrationAPIPort == 1024)

        s.integrationAPIPort = 70000
        #expect(s.integrationAPIPort == 65535)

        s.doneColumnMaxItems = 1
        #expect(s.doneColumnMaxItems == 5)
    }

    @Test("Different instances with same defaults share state")
    @MainActor
    func sharedDefaults() {
        let suiteName = UUID().uuidString
        let defaults = UserDefaults(suiteName: suiteName)!
        let s1 = SettingsManager(defaults: defaults)
        let s2 = SettingsManager(defaults: defaults)

        s1.maxFocusSlots = 4
        #expect(s2.maxFocusSlots == 4)
    }
}

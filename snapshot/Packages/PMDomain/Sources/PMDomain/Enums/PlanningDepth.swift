import Foundation

/// How much structural planning a project needs.
public enum PlanningDepth: String, Codable, Sendable, CaseIterable {
    case fullRoadmap
    case milestonePlan
    case taskList
    case openEmergent
}

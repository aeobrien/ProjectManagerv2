import SwiftUI
import PMDomain

/// Data needed to render a task card, avoiding direct entity coupling.
public struct TaskCardData: Sendable {
    public let name: String
    public let projectName: String
    public let projectSlotIndex: Int?
    public let milestoneName: String?
    public let deadline: Date?
    public let estimateMinutes: Int?
    public let timeboxMinutes: Int?
    public let effortType: EffortType?
    public let status: ItemStatus
    public let priority: Priority
    public let blockedType: BlockedType?
    public let deferralCount: Int
    public let deferredThreshold: Int

    public init(
        name: String,
        projectName: String,
        projectSlotIndex: Int? = nil,
        milestoneName: String? = nil,
        deadline: Date? = nil,
        estimateMinutes: Int? = nil,
        timeboxMinutes: Int? = nil,
        effortType: EffortType? = nil,
        status: ItemStatus = .notStarted,
        priority: Priority = .normal,
        blockedType: BlockedType? = nil,
        deferralCount: Int = 0,
        deferredThreshold: Int = 3
    ) {
        self.name = name
        self.projectName = projectName
        self.projectSlotIndex = projectSlotIndex
        self.milestoneName = milestoneName
        self.deadline = deadline
        self.estimateMinutes = estimateMinutes
        self.timeboxMinutes = timeboxMinutes
        self.effortType = effortType
        self.status = status
        self.priority = priority
        self.blockedType = blockedType
        self.deferralCount = deferralCount
        self.deferredThreshold = deferredThreshold
    }

    public var isOverdue: Bool {
        guard let deadline else { return false }
        return deadline < Date() && status != .completed
    }

    public var isApproachingDeadline: Bool {
        guard let deadline else { return false }
        let daysUntil = Calendar.current.dateComponents([.day], from: Date(), to: deadline).day ?? 0
        return daysUntil >= 0 && daysUntil <= 2 && status != .completed
    }

    public var isFrequentlyDeferred: Bool {
        deferralCount >= deferredThreshold
    }
}

/// A compact card view for displaying a task on the Focus Board.
public struct TaskCardView: View {
    let data: TaskCardData

    public init(data: TaskCardData) {
        self.data = data
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Top row: status icon + name + priority
            HStack(spacing: 6) {
                Image(systemName: data.status.iconName)
                    .foregroundStyle(data.status.color)
                    .font(.caption)

                Text(data.name)
                    .font(.headline)
                    .lineLimit(2)

                Spacer()

                if data.priority == .high {
                    Image(systemName: data.priority.iconName)
                        .foregroundStyle(data.priority.color)
                        .font(.caption)
                }
            }

            // Project + milestone context
            HStack(spacing: 4) {
                Circle()
                    .fill(SlotColour.forIndex(data.projectSlotIndex))
                    .frame(width: 8, height: 8)

                Text(data.projectName)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if let milestone = data.milestoneName {
                    Text("·")
                        .foregroundStyle(.quaternary)
                    Text(milestone)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            // Badges row
            HStack(spacing: 6) {
                if let effortType = data.effortType {
                    EffortBadge(effortType: effortType)
                }

                if let deadline = data.deadline {
                    DeadlineBadge(deadline: deadline, isOverdue: data.isOverdue, isApproaching: data.isApproachingDeadline)
                }

                if let estimate = data.estimateMinutes {
                    TimeBadge(minutes: estimate, isTimebox: false)
                }

                if let timebox = data.timeboxMinutes {
                    TimeBadge(minutes: timebox, isTimebox: true)
                }

                if data.status == .blocked, let blockedType = data.blockedType {
                    BlockedBadge(type: blockedType)
                }

                if data.isFrequentlyDeferred {
                    DeferredBadge(count: data.deferralCount)
                }
            }
        }
        .padding(10)
        .background(.background, in: RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(borderColor, lineWidth: borderWidth)
        )
    }

    private var borderColor: Color {
        if data.isOverdue { return SemanticColour.overdue }
        if data.status == .blocked { return SemanticColour.blocked }
        if data.isApproachingDeadline { return SemanticColour.warning }
        return .clear
    }

    private var borderWidth: CGFloat {
        borderColor == .clear ? 0 : 1.5
    }
}

// MARK: - Inline Badges

struct EffortBadge: View {
    let effortType: EffortType

    var body: some View {
        Label {
            Text(effortType.rawValue.camelCaseToWords)
                .font(.caption2)
        } icon: {
            effortType.icon
                .font(.caption2)
        }
        .foregroundStyle(effortType.color)
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(effortType.color.opacity(0.12), in: Capsule())
    }
}

struct DeadlineBadge: View {
    let deadline: Date
    let isOverdue: Bool
    let isApproaching: Bool

    var body: some View {
        Label {
            Text(deadline, style: .date)
                .font(.caption2)
        } icon: {
            Image(systemName: isOverdue ? "exclamationmark.circle.fill" : "calendar")
                .font(.caption2)
        }
        .foregroundStyle(isOverdue ? SemanticColour.overdue : isApproaching ? SemanticColour.warning : .secondary)
    }
}

struct TimeBadge: View {
    let minutes: Int
    let isTimebox: Bool

    var body: some View {
        Label {
            Text(formatted)
                .font(.caption2)
        } icon: {
            Image(systemName: isTimebox ? "timer" : "clock")
                .font(.caption2)
        }
        .foregroundStyle(.secondary)
    }

    private var formatted: String {
        if minutes >= 60 {
            let h = minutes / 60
            let m = minutes % 60
            return m > 0 ? "\(h)h \(m)m" : "\(h)h"
        }
        return "\(minutes)m"
    }
}

struct BlockedBadge: View {
    let type: BlockedType

    var body: some View {
        Label {
            Text("Blocked")
                .font(.caption2)
        } icon: {
            type.icon
                .font(.caption2)
        }
        .foregroundStyle(SemanticColour.blocked)
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(SemanticColour.blocked.opacity(0.12), in: Capsule())
    }
}

struct DeferredBadge: View {
    let count: Int

    var body: some View {
        Label {
            Text("Deferred \(count)x")
                .font(.caption2)
        } icon: {
            Image(systemName: "arrow.uturn.backward")
                .font(.caption2)
        }
        .foregroundStyle(SemanticColour.deferred)
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(SemanticColour.deferred.opacity(0.12), in: Capsule())
    }
}

// MARK: - String Helper

extension String {
    /// Converts "camelCase" to "Camel Case"
    var camelCaseToWords: String {
        unicodeScalars.reduce("") { result, scalar in
            if CharacterSet.uppercaseLetters.contains(scalar) && !result.isEmpty {
                return result + " " + String(scalar)
            }
            return result + String(scalar)
        }.localizedCapitalized
    }
}

// MARK: - Preview

#Preview("Task Card — Normal") {
    VStack(spacing: 12) {
        TaskCardView(data: TaskCardData(
            name: "Implement login screen",
            projectName: "Auth System",
            projectSlotIndex: 0,
            milestoneName: "MVP",
            estimateMinutes: 90,
            effortType: .deepFocus,
            status: .inProgress,
            priority: .high
        ))

        TaskCardView(data: TaskCardData(
            name: "Design icons",
            projectName: "UI Refresh",
            projectSlotIndex: 2,
            effortType: .creative,
            status: .notStarted
        ))

        TaskCardView(data: TaskCardData(
            name: "Fix API timeout",
            projectName: "Backend",
            projectSlotIndex: 1,
            deadline: Date().addingTimeInterval(-86400),
            effortType: .deepFocus,
            status: .blocked,
            blockedType: .missingInfo
        ))

        TaskCardView(data: TaskCardData(
            name: "Send status update",
            projectName: "Weekly Report",
            projectSlotIndex: 3,
            effortType: .communication,
            deferralCount: 4,
            deferredThreshold: 3
        ))
    }
    .padding()
    .frame(width: 320)
}

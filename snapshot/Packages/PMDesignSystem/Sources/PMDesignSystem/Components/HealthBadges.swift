import SwiftUI
import PMDomain

// MARK: - Health Signal Badge

/// A compact badge for displaying project health signals.
public struct HealthBadge: View {
    let signal: HealthSignalType

    public init(_ signal: HealthSignalType) {
        self.signal = signal
    }

    public var body: some View {
        Label {
            Text(signal.label)
                .font(.caption2)
                .fontWeight(.medium)
        } icon: {
            Image(systemName: signal.iconName)
                .font(.caption2)
        }
        .foregroundStyle(signal.color)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(signal.color.opacity(0.12), in: Capsule())
    }
}

/// Types of health signals that can be shown as badges.
public enum HealthSignalType: Sendable {
    case stale(days: Int)
    case blockedTasks(count: Int)
    case overdueTasks(count: Int)
    case approachingDeadline
    case checkInOverdue(days: Int)
    case diversityOverride
    case frequentlyDeferred(count: Int)

    public var label: String {
        switch self {
        case .stale(let days): "Stale (\(days)d)"
        case .blockedTasks(let count): "\(count) Blocked"
        case .overdueTasks(let count): "\(count) Overdue"
        case .approachingDeadline: "Deadline Soon"
        case .checkInOverdue(let days): "Check-in (\(days)d)"
        case .diversityOverride: "Diversity Override"
        case .frequentlyDeferred(let count): "\(count) Deferred"
        }
    }

    public var iconName: String {
        switch self {
        case .stale: "clock.badge.exclamationmark"
        case .blockedTasks: "xmark.circle.fill"
        case .overdueTasks: "exclamationmark.triangle.fill"
        case .approachingDeadline: "calendar.badge.clock"
        case .checkInOverdue: "text.bubble.fill"
        case .diversityOverride: "exclamationmark.triangle"
        case .frequentlyDeferred: "arrow.uturn.backward"
        }
    }

    public var color: Color {
        switch self {
        case .stale: SemanticColour.stale
        case .blockedTasks: SemanticColour.blocked
        case .overdueTasks: SemanticColour.overdue
        case .approachingDeadline: SemanticColour.warning
        case .checkInOverdue: SemanticColour.warning
        case .diversityOverride: SemanticColour.warning
        case .frequentlyDeferred: SemanticColour.deferred
        }
    }
}

// MARK: - Health Badge Row

/// Displays a horizontal collection of health signal badges.
public struct HealthBadgeRow: View {
    let signals: [HealthSignalType]

    public init(signals: [HealthSignalType]) {
        self.signals = signals
    }

    public var body: some View {
        if !signals.isEmpty {
            HStack(spacing: 6) {
                ForEach(Array(signals.enumerated()), id: \.offset) { _, signal in
                    HealthBadge(signal)
                }
            }
        }
    }
}

// MARK: - Diversity Override Banner

/// A prominent banner warning about category diversity violations.
public struct DiversityBanner: View {
    let categoryName: String
    let projectCount: Int
    let limit: Int

    public init(categoryName: String, projectCount: Int, limit: Int) {
        self.categoryName = categoryName
        self.projectCount = projectCount
        self.limit = limit
    }

    public var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(SemanticColour.warning)

            VStack(alignment: .leading, spacing: 2) {
                Text("Category Limit Exceeded")
                    .font(.subheadline)
                    .fontWeight(.medium)

                Text("\(categoryName) has \(projectCount) focused projects (limit: \(limit))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(10)
        .background(SemanticColour.warning.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(SemanticColour.warning.opacity(0.3), lineWidth: 1)
        )
    }
}

// MARK: - Preview

#Preview("Health Badges") {
    VStack(alignment: .leading, spacing: 16) {
        Text("Individual Badges").font(.headline)
        HStack {
            HealthBadge(.stale(days: 12))
            HealthBadge(.blockedTasks(count: 3))
            HealthBadge(.overdueTasks(count: 2))
        }
        HStack {
            HealthBadge(.approachingDeadline)
            HealthBadge(.checkInOverdue(days: 8))
            HealthBadge(.frequentlyDeferred(count: 5))
        }

        Divider()

        Text("Badge Row").font(.headline)
        HealthBadgeRow(signals: [
            .stale(days: 10),
            .blockedTasks(count: 2),
            .checkInOverdue(days: 5)
        ])

        Divider()

        Text("Diversity Banner").font(.headline)
        DiversityBanner(categoryName: "Software", projectCount: 3, limit: 2)
    }
    .padding()
    .frame(width: 400)
}

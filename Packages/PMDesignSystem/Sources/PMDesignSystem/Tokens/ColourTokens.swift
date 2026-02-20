import SwiftUI
import PMDomain

// MARK: - Focus Slot Colours

/// Five distinct colours for focus board project slots.
public enum SlotColour: Int, CaseIterable, Sendable {
    case slot0 = 0, slot1, slot2, slot3, slot4

    public var color: Color {
        switch self {
        case .slot0: .blue
        case .slot1: .purple
        case .slot2: .teal
        case .slot3: .orange
        case .slot4: .pink
        }
    }

    public static func forIndex(_ index: Int?) -> Color {
        guard let index, let slot = SlotColour(rawValue: index) else { return .secondary }
        return slot.color
    }
}

// MARK: - Status Colours

public extension ItemStatus {
    var color: Color {
        switch self {
        case .notStarted: .secondary
        case .inProgress: .blue
        case .blocked: .red
        case .waiting: .orange
        case .completed: .green
        }
    }
}

// MARK: - Lifecycle State Colours

public extension LifecycleState {
    var color: Color {
        switch self {
        case .focused: .blue
        case .queued: .purple
        case .idea: .mint
        case .completed: .green
        case .paused: .orange
        case .abandoned: .secondary
        }
    }
}

// MARK: - Effort Type Colours

public extension EffortType {
    var color: Color {
        switch self {
        case .deepFocus: .indigo
        case .creative: .purple
        case .administrative: .gray
        case .communication: .cyan
        case .physical: .green
        case .quickWin: .yellow
        }
    }
}

// MARK: - Priority Colours

public extension Priority {
    var color: Color {
        switch self {
        case .high: .red
        case .normal: .primary
        case .low: .secondary
        }
    }
}

// MARK: - Kanban Column Colours

public extension KanbanColumn {
    var color: Color {
        switch self {
        case .toDo: .secondary
        case .inProgress: .blue
        case .done: .green
        }
    }
}

// MARK: - Check-In Depth Colours

public extension CheckInDepth {
    var color: Color {
        switch self {
        case .quickLog: .teal
        case .fullConversation: .indigo
        }
    }
}

// MARK: - Semantic Colours

public enum SemanticColour {
    public static let stale = Color.orange
    public static let overdue = Color.red
    public static let blocked = Color.red
    public static let warning = Color.orange
    public static let success = Color.green
    public static let info = Color.blue
    public static let deferred = Color.yellow
}

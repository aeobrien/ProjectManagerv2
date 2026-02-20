import SwiftUI
import PMDomain

// MARK: - Effort Type Icons (SF Symbols)

public extension EffortType {
    var iconName: String {
        switch self {
        case .deepFocus: "brain.head.profile"
        case .creative: "paintbrush"
        case .administrative: "tray.full"
        case .communication: "bubble.left.and.bubble.right"
        case .physical: "hammer"
        case .quickWin: "bolt"
        }
    }

    var icon: Image { Image(systemName: iconName) }
}

// MARK: - Item Status Icons

public extension ItemStatus {
    var iconName: String {
        switch self {
        case .notStarted: "circle"
        case .inProgress: "circle.lefthalf.filled"
        case .blocked: "xmark.circle.fill"
        case .waiting: "clock.fill"
        case .completed: "checkmark.circle.fill"
        }
    }

    var icon: Image { Image(systemName: iconName) }
}

// MARK: - Lifecycle State Icons

public extension LifecycleState {
    var iconName: String {
        switch self {
        case .focused: "star.fill"
        case .queued: "list.bullet"
        case .idea: "lightbulb"
        case .completed: "checkmark.seal.fill"
        case .paused: "pause.circle"
        case .abandoned: "archivebox"
        }
    }

    var icon: Image { Image(systemName: iconName) }
}

// MARK: - Priority Icons

public extension Priority {
    var iconName: String {
        switch self {
        case .high: "exclamationmark.triangle.fill"
        case .normal: "minus"
        case .low: "arrow.down"
        }
    }

    var icon: Image { Image(systemName: iconName) }
}

// MARK: - Kanban Column Icons

public extension KanbanColumn {
    var iconName: String {
        switch self {
        case .toDo: "circle"
        case .inProgress: "play.circle"
        case .done: "checkmark.circle"
        }
    }

    var icon: Image { Image(systemName: iconName) }
}

// MARK: - Check-In Depth Icons

public extension CheckInDepth {
    var iconName: String {
        switch self {
        case .quickLog: "text.bubble"
        case .fullConversation: "text.bubble.fill"
        }
    }

    var icon: Image { Image(systemName: iconName) }
}

// MARK: - Blocked Type Icons

public extension BlockedType {
    var iconName: String {
        switch self {
        case .poorlyDefined: "questionmark.circle"
        case .tooLarge: "arrow.up.left.and.arrow.down.right"
        case .missingInfo: "doc.questionmark"
        case .missingResource: "person.crop.circle.badge.questionmark"
        case .decisionRequired: "arrow.triangle.branch"
        }
    }

    var icon: Image { Image(systemName: iconName) }
}

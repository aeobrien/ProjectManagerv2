import SwiftUI

// MARK: - Section Header

/// A styled section header with optional action button.
public struct PMSectionHeader: View {
    let title: String
    let subtitle: String?
    let actionLabel: String?
    let action: (() -> Void)?

    public init(
        _ title: String,
        subtitle: String? = nil,
        actionLabel: String? = nil,
        action: (() -> Void)? = nil
    ) {
        self.title = title
        self.subtitle = subtitle
        self.actionLabel = actionLabel
        self.action = action
    }

    public var body: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.title3)
                    .fontWeight(.semibold)

                if let subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            if let actionLabel, let action {
                Button(actionLabel, action: action)
                    .font(.subheadline)
            }
        }
    }
}

// MARK: - Card Container

/// A container with background, corner radius, and subtle shadow.
public struct PMCard<Content: View>: View {
    let content: Content

    public init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    public var body: some View {
        content
            .padding(12)
            .background(.background, in: RoundedRectangle(cornerRadius: 10))
            .shadow(color: .black.opacity(0.06), radius: 3, y: 1)
    }
}

// MARK: - Empty State View

/// A centered placeholder for empty lists and states.
public struct PMEmptyState: View {
    let iconName: String
    let title: String
    let message: String
    let actionLabel: String?
    let action: (() -> Void)?

    public init(
        icon: String,
        title: String,
        message: String,
        actionLabel: String? = nil,
        action: (() -> Void)? = nil
    ) {
        self.iconName = icon
        self.title = title
        self.message = message
        self.actionLabel = actionLabel
        self.action = action
    }

    public var body: some View {
        VStack(spacing: 12) {
            Image(systemName: iconName)
                .font(.system(size: 40))
                .foregroundStyle(.tertiary)

            Text(title)
                .font(.headline)

            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 260)

            if let actionLabel, let action {
                Button(actionLabel, action: action)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    .padding(.top, 4)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}

// MARK: - Confirmation Dialog

/// Data for a destructive confirmation dialog.
public struct ConfirmationData: Sendable {
    public let title: String
    public let message: String
    public let confirmLabel: String
    public let role: ButtonRole

    public init(title: String, message: String, confirmLabel: String = "Delete", role: ButtonRole = .destructive) {
        self.title = title
        self.message = message
        self.confirmLabel = confirmLabel
        self.role = role
    }
}

/// View modifier to attach a standard confirmation dialog.
public struct PMConfirmationModifier: ViewModifier {
    @Binding var isPresented: Bool
    let data: ConfirmationData
    let onConfirm: () -> Void

    public func body(content: Content) -> some View {
        content.confirmationDialog(data.title, isPresented: $isPresented) {
            Button(data.confirmLabel, role: data.role) { onConfirm() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(data.message)
        }
    }
}

public extension View {
    func pmConfirmation(isPresented: Binding<Bool>, data: ConfirmationData, onConfirm: @escaping () -> Void) -> some View {
        modifier(PMConfirmationModifier(isPresented: isPresented, data: data, onConfirm: onConfirm))
    }
}

// MARK: - Preview

#Preview("Common Layouts") {
    VStack(spacing: 20) {
        PMSectionHeader("Focus Board", subtitle: "3 of 5 slots filled", actionLabel: "Add") {}

        PMCard {
            VStack(alignment: .leading) {
                Text("Card content goes here")
                Text("With multiple lines").foregroundStyle(.secondary)
            }
        }

        Divider()

        PMEmptyState(
            icon: "tray",
            title: "No Projects Yet",
            message: "Create your first project to get started with focused work.",
            actionLabel: "New Project"
        ) {}
    }
    .padding()
    .frame(width: 360, height: 500)
}

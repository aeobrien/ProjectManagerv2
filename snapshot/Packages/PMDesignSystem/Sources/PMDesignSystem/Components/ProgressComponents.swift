import SwiftUI

// MARK: - Progress Bar

/// A styled progress bar used for milestones, phases, and projects.
public struct PMProgressBar: View {
    let progress: Double
    let tint: Color

    /// Creates a progress bar.
    /// - Parameters:
    ///   - progress: Value from 0.0 to 1.0.
    ///   - tint: Bar fill colour. Defaults to `.blue`.
    public init(progress: Double, tint: Color = .blue) {
        self.progress = min(max(progress, 0), 1)
        self.tint = tint
    }

    public var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(tint.opacity(0.15))

                Capsule()
                    .fill(tint)
                    .frame(width: geo.size.width * progress)
            }
        }
        .frame(height: 6)
    }
}

// MARK: - Progress Label

/// Displays a progress percentage as text.
public struct PMProgressLabel: View {
    let progress: Double
    let style: LabelStyle

    public enum LabelStyle: Sendable {
        case percent    // "75%"
        case fraction(total: Int) // "3/4"
    }

    public init(progress: Double, style: LabelStyle = .percent) {
        self.progress = min(max(progress, 0), 1)
        self.style = style
    }

    public var body: some View {
        Text(formatted)
            .font(.caption)
            .foregroundStyle(.secondary)
            .monospacedDigit()
    }

    private var formatted: String {
        switch style {
        case .percent:
            "\(Int(progress * 100))%"
        case .fraction(let total):
            "\(Int(Double(total) * progress))/\(total)"
        }
    }
}

// MARK: - Progress Row

/// A combined progress bar with label, used inline.
public struct PMProgressRow: View {
    let title: String
    let progress: Double
    let tint: Color

    public init(title: String, progress: Double, tint: Color = .blue) {
        self.title = title
        self.progress = progress
        self.tint = tint
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title)
                    .font(.subheadline)
                Spacer()
                PMProgressLabel(progress: progress)
            }
            PMProgressBar(progress: progress, tint: tint)
        }
    }
}

// MARK: - Preview

#Preview("Progress Components") {
    VStack(spacing: 20) {
        Text("Progress Bars").font(.headline)
        PMProgressBar(progress: 0.0, tint: .red)
        PMProgressBar(progress: 0.25, tint: .orange)
        PMProgressBar(progress: 0.5, tint: .blue)
        PMProgressBar(progress: 0.75, tint: .purple)
        PMProgressBar(progress: 1.0, tint: .green)

        Divider()

        Text("Progress Labels").font(.headline)
        HStack {
            PMProgressLabel(progress: 0.75)
            PMProgressLabel(progress: 0.75, style: .fraction(total: 8))
        }

        Divider()

        Text("Progress Rows").font(.headline)
        PMProgressRow(title: "Phase 1: Design", progress: 0.6, tint: .purple)
        PMProgressRow(title: "Phase 2: Build", progress: 0.3, tint: .blue)
        PMProgressRow(title: "Phase 3: Test", progress: 0.0, tint: .green)
    }
    .padding()
    .frame(width: 300)
}

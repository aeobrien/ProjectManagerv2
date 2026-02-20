import SwiftUI
import PMServices
import PMDesignSystem

/// Reusable voice input component with microphone button, waveform, and editable transcript.
public struct VoiceInputView: View {
    @Bindable var manager: VoiceInputManager
    var onTranscriptReady: ((String) -> Void)?

    public init(manager: VoiceInputManager, onTranscriptReady: ((String) -> Void)? = nil) {
        self.manager = manager
        self.onTranscriptReady = onTranscriptReady
    }

    public var body: some View {
        VStack(spacing: 12) {
            // Waveform / Status
            waveformArea

            // Controls
            controlBar

            // Editable transcript
            if case .completed = manager.state {
                transcriptEditor
            }

            // Error
            if case .error(let message) = manager.state {
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
    }

    // MARK: - Waveform

    private var waveformArea: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(.quaternary)
                .frame(height: 60)

            if manager.isRecording {
                WaveformView(levels: manager.audioLevels)
                    .frame(height: 50)
                    .padding(.horizontal, 8)
            } else if manager.isProcessing {
                ProgressView("Transcribing...")
                    .font(.caption)
            } else if case .completed = manager.state {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                    Text("Transcription complete")
                        .font(.caption)
                }
            } else {
                Text("Tap the microphone to start recording")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Controls

    private var controlBar: some View {
        HStack(spacing: 16) {
            if manager.isRecording {
                // Stop button
                Button {
                    manager.stopRecording()
                } label: {
                    Image(systemName: "stop.circle.fill")
                        .font(.system(size: 36))
                        .foregroundStyle(.red)
                }
                .buttonStyle(.plain)

                // Cancel
                Button("Cancel") {
                    manager.cancel()
                }
                .buttonStyle(.bordered)
            } else if manager.isProcessing {
                Button("Cancel") {
                    manager.cancel()
                }
                .buttonStyle(.bordered)
            } else {
                // Record button
                Button {
                    if manager.canRecord {
                        manager.startRecording()
                    }
                } label: {
                    Image(systemName: "mic.circle.fill")
                        .font(.system(size: 36))
                        .foregroundStyle(manager.canRecord ? .blue : .secondary)
                }
                .buttonStyle(.plain)
                .disabled(!manager.canRecord)

                if case .completed = manager.state {
                    Button("Use Transcript") {
                        onTranscriptReady?(manager.editableTranscript)
                    }
                    .buttonStyle(.borderedProminent)

                    Button("Re-record") {
                        manager.reset()
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
    }

    // MARK: - Transcript Editor

    private var transcriptEditor: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Edit transcript:")
                .font(.caption)
                .foregroundStyle(.secondary)

            TextEditor(text: $manager.editableTranscript)
                .font(.body)
                .frame(minHeight: 60)
                .scrollContentBackground(.hidden)
                .padding(8)
                .background(.quaternary, in: RoundedRectangle(cornerRadius: 8))
        }
    }
}

// MARK: - Waveform View

struct WaveformView: View {
    let levels: [Float]

    var body: some View {
        GeometryReader { geo in
            HStack(alignment: .center, spacing: 1) {
                ForEach(Array(displayLevels(width: geo.size.width).enumerated()), id: \.offset) { _, level in
                    RoundedRectangle(cornerRadius: 1)
                        .fill(.blue.opacity(0.7))
                        .frame(width: 2, height: max(2, CGFloat(level) * geo.size.height))
                }
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
    }

    private func displayLevels(width: CGFloat) -> [Float] {
        let maxBars = Int(width / 3)
        if levels.count <= maxBars { return levels }
        return Array(levels.suffix(maxBars))
    }
}

// MARK: - Preview

#Preview("Voice Input - Idle") {
    VoiceInputView(manager: VoiceInputManager())
        .padding()
        .frame(width: 400)
}

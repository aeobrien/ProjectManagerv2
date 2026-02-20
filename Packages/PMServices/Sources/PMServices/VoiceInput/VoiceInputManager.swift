import Foundation
import AVFoundation
@preconcurrency import WhisperKit
import PMUtilities
import os

/// State machine for voice recording and transcription.
public enum VoiceInputState: Sendable, Equatable {
    case idle
    case recording
    case processing
    case completed(String)
    case error(String)
}

/// Observable manager for voice recording and Whisper transcription.
@Observable
@MainActor
public final class VoiceInputManager {
    // MARK: - State

    public private(set) var state: VoiceInputState = .idle
    public private(set) var audioLevels: [Float] = []
    public var editableTranscript: String = ""

    /// The Whisper model size to use.
    public var modelSize: String = "small"

    // MARK: - Private

    private var audioRecorder: AVAudioRecorder?
    private var levelTimer: Timer?
    private var whisperKit: WhisperKit?
    private var recordingURL: URL?

    // MARK: - Init

    public init(modelSize: String = "small") {
        self.modelSize = modelSize
    }

    // MARK: - Recording

    /// Start recording audio from the microphone.
    public func startRecording() {
        guard state == .idle || isTerminalState else { return }

        state = .recording
        audioLevels = []
        editableTranscript = ""

        let tempDir = FileManager.default.temporaryDirectory
        let url = tempDir.appendingPathComponent("voice_capture_\(UUID().uuidString).wav")
        recordingURL = url

        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatLinearPCM),
            AVSampleRateKey: 16000.0,
            AVNumberOfChannelsKey: 1,
            AVLinearPCMBitDepthKey: 16,
            AVLinearPCMIsFloatKey: false
        ]

        do {
            #if os(macOS)
            // macOS doesn't require audio session setup
            #else
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playAndRecord, mode: .default)
            try session.setActive(true)
            #endif

            audioRecorder = try AVAudioRecorder(url: url, settings: settings)
            audioRecorder?.isMeteringEnabled = true
            audioRecorder?.record()

            // Sample audio levels for waveform
            levelTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.sampleAudioLevel()
                }
            }

            Log.voice.info("Started recording to \(url.lastPathComponent)")
        } catch {
            state = .error("Failed to start recording: \(error.localizedDescription)")
            Log.voice.error("Recording failed: \(error)")
        }
    }

    /// Stop recording and begin transcription.
    public func stopRecording() {
        guard state == .recording else { return }

        levelTimer?.invalidate()
        levelTimer = nil
        audioRecorder?.stop()

        state = .processing
        Log.voice.info("Stopped recording, starting transcription")

        Task {
            await transcribe()
        }
    }

    /// Cancel the current recording without transcribing.
    public func cancel() {
        levelTimer?.invalidate()
        levelTimer = nil
        audioRecorder?.stop()
        cleanupRecording()
        state = .idle
        audioLevels = []
        editableTranscript = ""
    }

    /// Reset to idle state for a new recording.
    public func reset() {
        cleanupRecording()
        state = .idle
        audioLevels = []
        editableTranscript = ""
    }

    // MARK: - Transcription

    private func transcribe() async {
        guard let url = recordingURL else {
            state = .error("No recording found.")
            return
        }

        do {
            if whisperKit == nil {
                let model = self.modelSize
                Log.voice.info("Loading Whisper model: \(model)")
                let config = WhisperKitConfig(model: "openai_whisper-\(model)")
                whisperKit = try await WhisperKit(config)
            }

            guard let kit = whisperKit else {
                state = .error("Failed to initialize WhisperKit.")
                return
            }

            let results = try await kit.transcribe(audioPath: url.path)
            let text = results.map(\.text).joined(separator: " ").trimmingCharacters(in: .whitespacesAndNewlines)

            if text.isEmpty {
                state = .error("No speech detected.")
            } else {
                editableTranscript = text
                state = .completed(text)
                Log.voice.info("Transcription completed: \(text.prefix(50))...")
            }
        } catch {
            state = .error("Transcription failed: \(error.localizedDescription)")
            Log.voice.error("Transcription error: \(error)")
        }

        cleanupRecording()
    }

    // MARK: - Helpers

    private func sampleAudioLevel() {
        audioRecorder?.updateMeters()
        let level = audioRecorder?.averagePower(forChannel: 0) ?? -160
        // Normalize from dB (-160...0) to 0...1
        let normalized = max(0, min(1, (level + 50) / 50))
        audioLevels.append(normalized)
        // Keep a reasonable buffer for waveform display
        if audioLevels.count > 200 {
            audioLevels.removeFirst()
        }
    }

    private func cleanupRecording() {
        if let url = recordingURL {
            try? FileManager.default.removeItem(at: url)
            recordingURL = nil
        }
    }

    private var isTerminalState: Bool {
        switch state {
        case .completed, .error: true
        default: false
        }
    }

    /// The final transcript text, if completed.
    public var transcriptText: String? {
        if case .completed(let text) = state { return text }
        return nil
    }

    /// Whether the manager is in a state where recording can start.
    public var canRecord: Bool {
        state == .idle || isTerminalState
    }

    /// Whether transcription is in progress.
    public var isProcessing: Bool {
        state == .processing
    }

    /// Whether recording is active.
    public var isRecording: Bool {
        state == .recording
    }
}

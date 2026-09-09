import Foundation
import AVFoundation
@preconcurrency import WhisperKit
import PMUtilities
import os

/// State machine for voice recording and transcription.
public enum VoiceInputState: Sendable, Equatable {
    case idle
    case requestingPermission
    case loadingModel
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
    public var modelSize: String = "tiny"

    // MARK: - Private

    private var audioRecorder: AVAudioRecorder?
    private var levelTimer: Timer?
    private var whisperKit: WhisperKit?
    private var recordingURL: URL?

    // MARK: - Init

    public init(modelSize: String = "tiny") {
        self.modelSize = modelSize
    }

    // MARK: - Preload

    /// Preload and prewarm the Whisper model so first transcription is fast.
    /// Prewarming compiles CoreML models for the device's Neural Engine.
    public func preloadModel() async {
        guard whisperKit == nil else { return }
        do {
            let model = self.modelSize
            let start = CFAbsoluteTimeGetCurrent()
            Log.voice.info("Preloading Whisper model: \(model) (with prewarm)")
            let config = WhisperKitConfig(model: "openai_whisper-\(model)", prewarm: true)
            whisperKit = try await WhisperKit(config)
            let duration = CFAbsoluteTimeGetCurrent() - start
            Log.voice.info("Whisper model preloaded + prewarmed in \(String(format: "%.1f", duration))s")
        } catch {
            Log.voice.error("Failed to preload Whisper model: \(error)")
        }
    }

    // MARK: - Recording

    /// Start recording audio from the microphone.
    public func startRecording() {
        guard state == .idle || isTerminalState else { return }

        state = .requestingPermission
        audioLevels = []
        editableTranscript = ""

        Task {
            let permitted = await requestMicrophonePermission()
            guard permitted else {
                state = .error("Microphone access denied. Enable it in System Settings > Privacy & Security > Microphone.")
                Log.voice.error("Microphone permission denied")
                return
            }
            beginRecording()
        }
    }

    /// Request microphone permission and return whether it was granted.
    private func requestMicrophonePermission() async -> Bool {
        #if os(macOS)
        if #available(macOS 14.0, *) {
            let status = AVCaptureDevice.authorizationStatus(for: .audio)
            switch status {
            case .authorized:
                return true
            case .notDetermined:
                return await AVCaptureDevice.requestAccess(for: .audio)
            case .denied, .restricted:
                return false
            @unknown default:
                return false
            }
        }
        return true
        #else
        let session = AVAudioSession.sharedInstance()
        let status = session.recordPermission
        switch status {
        case .granted:
            return true
        case .undetermined:
            return await withCheckedContinuation { continuation in
                session.requestRecordPermission { granted in
                    continuation.resume(returning: granted)
                }
            }
        case .denied:
            return false
        @unknown default:
            return false
        }
        #endif
    }

    /// Actually begin the recording session after permission is confirmed.
    private func beginRecording() {
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
            #if os(iOS)
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playAndRecord, mode: .default)
            try session.setActive(true)
            #endif

            audioRecorder = try AVAudioRecorder(url: url, settings: settings)
            audioRecorder?.isMeteringEnabled = true
            audioRecorder?.record()

            state = .recording

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
                state = .loadingModel
                let modelStart = CFAbsoluteTimeGetCurrent()
                Log.voice.info("Loading Whisper model: \(model)")
                let config = WhisperKitConfig(model: "openai_whisper-\(model)")
                whisperKit = try await WhisperKit(config)
                let modelDuration = CFAbsoluteTimeGetCurrent() - modelStart
                Log.voice.info("Whisper model loaded in \(String(format: "%.1f", modelDuration))s")
                state = .processing
            }

            guard let kit = whisperKit else {
                state = .error("Failed to initialize WhisperKit.")
                return
            }

            let transcribeStart = CFAbsoluteTimeGetCurrent()
            let results = try await kit.transcribe(audioPath: url.path)
            let transcribeDuration = CFAbsoluteTimeGetCurrent() - transcribeStart
            let text = results.map(\.text).joined(separator: " ").trimmingCharacters(in: .whitespacesAndNewlines)
            Log.voice.info("Transcription took \(String(format: "%.1f", transcribeDuration))s")

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

    /// Whether the model is currently being loaded/downloaded.
    public var isLoadingModel: Bool {
        state == .loadingModel
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

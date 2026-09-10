# Phase 10: Voice Input — Manual Test Brief

## Automated Tests
- **12 tests** in 1 suite, passing via `cd Packages/PMServices && swift test`

### Suites
1. **VoiceInputManagerTests** (12 tests) — Validates initial state defaults, state equality, computed properties (canRecord, isRecording, isProcessing), cancel/reset behaviour, model size configuration, and stop-when-not-recording guard.

**Note:** Tests cover state machine logic only. Actual AVAudioRecorder recording, microphone permission prompts, and WhisperKit transcription require manual testing on a real device with Apple Silicon.

## Manual Verification Checklist
- [ ] VoiceInputManager initializes with `state = .idle`, empty transcript, and empty audio levels
- [ ] Tapping the microphone button triggers the macOS system permission dialog on first launch
- [ ] Denying microphone permission shows error: "Microphone access denied..."
- [ ] Granting permission transitions to recording state
- [ ] Waveform display data updates in real time while recording is active
- [ ] Stopping a recording transitions to processing state and produces a transcript
- [ ] First transcription shows "Loading speech model..." while WhisperKit downloads/loads the model
- [ ] Subsequent transcriptions skip model loading and go straight to "Transcribing..."
- [ ] WhisperKit transcription (Apple Silicon only) produces a non-empty transcript from recorded audio
- [ ] VoiceInputView shows recording controls (mic button, stop, cancel) and they toggle correctly
- [ ] After transcription completes, the transcript text is editable in the TextEditor
- [ ] "Use Transcript" button passes edited text to the consuming feature (Quick Capture / Chat)
- [ ] "Re-record" button resets to idle for a new recording
- [ ] Cancel during recording returns to idle without transcribing
- [ ] Voice input works from Quick Capture view (toggle between text/voice)
- [ ] Voice input works from AI Chat input bar

## Files Created/Modified
### New Files
- `Packages/PMServices/Sources/PMServices/VoiceInput/VoiceInputManager.swift` — AVAudioRecorder wrapper with WhisperKit transcription, microphone permission handling, waveform data, model loading state, and recording state management
- `Packages/PMFeatures/Sources/PMFeatures/VoiceInput/VoiceInputView.swift` — Reusable SwiftUI recording component with waveform visualization, recording controls, model loading indicator, and editable transcript

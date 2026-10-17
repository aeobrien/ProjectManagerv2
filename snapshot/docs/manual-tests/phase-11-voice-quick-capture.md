# Phase 11: Voice Quick Capture — Manual Test Brief

## Automated Tests
- **0 new tests** — voice integration covered by existing QuickCaptureViewModel tests in PMFeatures

### Suites
1. **QuickCaptureViewModelTests** (existing suite) — Includes toggle voice mode test verifying switching between text and voice input within QuickCaptureView.

## Manual Verification Checklist
- [ ] QuickCaptureView displays a toggle to switch between text input and voice input modes
- [ ] Tapping the voice toggle switches the UI from the text field to the VoiceInputView
- [ ] Tapping the toggle again switches back to text input mode
- [ ] Recording a voice note in QuickCaptureView populates the transcript into the capture field
- [ ] Editing the transcript after voice recording is reflected in the project capture data
- [ ] Submitting a quick capture created via voice input creates the project correctly
- [ ] Voice toggle state resets when QuickCaptureView is dismissed and re-opened

## Files Created/Modified
### Modified Files
- `Packages/PMFeatures/Sources/PMFeatures/QuickCapture/QuickCaptureView.swift` — Added voice toggle to switch between text and voice input modes, integrating VoiceInputView

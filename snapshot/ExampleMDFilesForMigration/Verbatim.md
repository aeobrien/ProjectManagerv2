# Verbatim

## Version History
- v0.1 - 14 Jun 2025 - Migrated to structured format
## Core Concept
Verbatim is a cross-platform voice note and transcription app designed to capture spontaneous thoughts in structured formats. Users select a recording type—such as "Journal," "To-Do," or "Project Proposal"—and speak freely. The app records audio, transcribes it using OpenAI’s Whisper API, and optionally processes it through GPT-4 to generate structured text (e.g. lists or summaries). Recordings are synced between macOS and iOS via CloudKit, with features tailored to frictionless capture, AI-assisted thinking, and integration into workflows like Obsidian.
## Tags
#App #Productivity #Self_Improvement #Mental_Health
## Guiding Principles & Intentions
- **Frictionless Capture**: Prioritise immediacy—record first, organise later.
    
- **Structured Thought from Chaos**: Use AI to convert brain dumps into useful formats.
    
- **Ownership of Ideas**: Store recordings locally, and optionally export to Obsidian vaults.
    
- **Cross-Platform Continuity**: Ensure seamless syncing and identical functionality across macOS and iOS.
    
- **Offline Resilience**: Maintain full core functionality even without internet access.
## Key Features & Functionality
- **Recording Types**: Pre-defined and user-editable types (e.g. Journal, To-Do, Storyboard). Type determines tagging and AI post-processing.
    
- **Transcription Engine**: Audio (.m4a mono 128kbps) sent to Whisper API for transcription.
    
- **Offline Queue**: If offline, recordings are queued locally and processed later.
    
- **Dual Output for AI-Enhanced Types**: Some types (e.g. To-Do) are also submitted to GPT-4 for structured output. Both raw and formatted text are saved.
    
- **Recording Browser**: Organised by date, collapsible by section. Filter by type or transcription status.
    
- **Settings Panel**: Manage types, configure behaviour, view queue status.
    
- **CloudKit Sync**: Sync recordings and states between macOS and iOS.
    
- **Quick Input (macOS)**: ⌘⇧V opens overlay for instant recording and transcription. Inserts directly into the current text field.
    
- **Obsidian Integration (macOS)**: Export recordings of selected types to folders in user-defined Obsidian vaults, using custom templates.
## Architecture & Structure
- **Frontend**: SwiftUI for both iOS and macOS
    
- **Audio Capture**: AVFoundation
    
- **Transcription**: Whisper API (via OpenAI)
    
- **AI Post-Processing**: GPT-4 completions with predefined prompts per recording type
    
- **Data Storage**: Core Data (local), CloudKit (sync)
    
- **Export System**: FileWriter module for .md generation and folder path routing (macOS)
    
- **Queue System**: Local database queue for offline transcription jobs
    
- **Obsidian Template Parsing**: Simple token replacement engine for Markdown export
## Implementation Roadmap
### Phase 1: Core Capture & Transcription

- Build audio recording system
    
- Integrate Whisper API transcription
    
- Implement basic recording type system
    
- Build queue for offline handling
    

### Phase 2: Interface & Filtering

- Create Recordings page with date-grouped UI
    
- Add filters (type, transcription status)
    
- Implement tag system
    

### Phase 3: AI Enhancement

- Add GPT-4 processing for specific types (e.g. To-Do, Project Proposal)
    
- Display dual outputs where applicable
    
- Allow user to toggle AI processing on/off per type
    

### Phase 4: Sync & Cross-Platform

- Implement CloudKit syncing
    
- Test sync behaviour for edits, tags, audio, and text
    

### Phase 5: macOS-Specific Features

- Build ⌘⇧V Quick Input overlay
    
- Implement real-time paste into focused field
    
- Add Obsidian export with template system
    

### Phase 6: Polish & Release

- Add Settings screen for managing types
    
- Final UI refinement
    
- Build onboarding flow
    
- Publish to App Store + notarize macOS app
## Current Status & Progress

## Next Steps
- [ ] Microjournal questions not one at a time
- [ ] Speed up audio for cheaper transcription
- [ ] If queueing for transcription later, say so and return to menu
- [x] Consolidate macos and ios projects into one
- [x] Microjournal crashing app
- [x] Fix massive fuck up when I got Claude to add functionality to the wrong app, Jesus Christ (I think I can just roll back to last commit)
- [x] When pausing a recording and leaving the app for a few minutes and then coming back, it stops recognising audio input and seems to corrupt the whole file
- [ ] Integrate with obsidian
- [x] Reimplement markdown in verbatim reader
- [x] Add culminating notes
- [x] Sync with macos version
- [x] Fix silence removal
- [x] Make recording searchable
- [x] Fix dark mode
- [x] Implement new project overview structure
## Challenges & Solutions
- **Offline-first reliability**: Risk of data loss or sync issues
    
    - _Solution_: Queue + transactional file handling with regular autosave
        
- **AI Output Interpretation**: GPT formatting may be inconsistent
    
    - _Solution_: Use templated prompts with stricter expected structure
        
- **Active text field paste (macOS)**: Permissions and targeting
    
    - _Solution_: Use Accessibility API and offer permissions guidance during onboarding
        
- **Obsidian path configuration**: User may input incorrect paths
    
    - _Solution_: Use native file pickers and validate folder presence
## User/Audience Experience
- **iOS**: Open app, select type, record. Review and tag recordings later. Use for journaling, idea capture, and task dumping.
    
- **macOS**: Use full app or ⌘⇧V overlay for immediate recording + insert into other apps. Export relevant recordings into Obsidian without friction.
    
- **Cross-device**: Make a recording on iPhone, view or export it later on Mac. Sync is seamless.
    
- **Review Flow**: Daily browsing via date-organised feed with filters. Easy to revisit ideas or extract structured data.
## Success Metrics
- Consistent transcription accuracy above 90%
    
- Daily active use for capture or review
    
- High sync reliability across devices
    
- Majority of users customising recording types or Obsidian templates
    
- Positive user feedback on Quick Input speed and Obsidian export utility
## Research & References
- OpenAI Whisper API
    
- GPT-4 prompt tuning guides
    
- Accessibility API for macOS automation
    
- CloudKit syncing best practices
    
- Obsidian vault folder structure and template systems
    
- User behaviour studies on voice journaling & task capture
## Open Questions & Considerations
- Should GPT-enhanced output be editable by the user post-generation?
    
- What’s the ideal fallback behaviour when Whisper fails to transcribe?
    
- Should users be able to define their own GPT prompts per recording type?
    
- How should recordings be archived or backed up long-term?
    
- Would Android or web be useful future platforms?
## Project Log
### 21 Jun 2025 at 16:18
GitHub Commit to VoiceRecorder by aeobrien ([1b13f05]): Sync progress.

### 20 Jun 2025 at 18:06
GitHub Commit to VoiceRecorder by aeobrien ([6b050bb]): Fixed Dark Mode.

### 20 Jun 2025 at 17:36
GitHub Commit to VoiceRecorder by aeobrien ([d5817e5]): Removed silent removal stats immediately after recording.

### 15 Jun 2025 at 21:45
GitHub Commit to VoiceRecorder by aeobrien ([935297e]): Implemented cumulative notes and updated project proposal prompt.

### 9 Jun 2025 at 14:49
GitHub Commit to VoiceRecorder by aeobrien ([956eb52]): Updated UI, refactored RedesignedRecordingsView.swift to avoid insane amounts of...

### 7 Jun 2025 at 18:48
GitHub Commit to VoiceRecorder by aeobrien ([a479620]): Added icons, made changes to silence removal system

### 31 May 2025 at 11:01
GitHub Commit to VoiceRecorder by aeobrien ([4eaeb8a]): Cleaned up post-recording screen navigation.

### 18 May 2025 at 02:35
GitHub Commit to VoiceRecorder by aeobrien ([dc8ce00]): Recombined microjournal responses into single entries

### 18 May 2025 at 01:12
GitHub Commit to VoiceRecorder by aeobrien ([3e6b23e]): Updated transcriping queuing.

### 2 May 2025 at 23:51
GitHub Commit to VoiceRecorder by aeobrien ([954195f]): 2nd May 2025

### 15 Jun 2025
- Started implementing MacOS sync, but with various niggles – Claude Code managed to destroy the recordingsview and microjournaldetailview in the process, and so far sync only works one way. 

### 15 Jun 2025
- App up and running with minimal bugs
- Various bits and pieces to polish, main obstacle is MacOS integration/sync

### 14 Jun 2025
Migrated to structured format
## External Files
[Any files related to the project outside of the Obsidian folder and their locations]
## Repositories
### Local Repositories
[Local repository paths and descriptions]

### GitHub Repositories
https://github.com/aeobrien/VoiceRecorder.git
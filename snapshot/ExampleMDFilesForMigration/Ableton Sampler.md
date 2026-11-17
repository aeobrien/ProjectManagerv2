# Ableton Sampler

## Version History
- v0.1 - 2025-06-14 - Initial prototype with recording, transient detection, and basic mapping/export
    
- v0.2 - [TBD] - Add filename-based mapping logic and loop region editing
## Core Concept
A macOS SwiftUI application for quickly creating complex Ableton Sampler patches (.adv files) using recorded or imported audio. It aims to eliminate manual mapping effort by automating tasks like velocity zoning, round robin layering, and loop region setup. The app exports valid Ableton .adv Sampler files through custom XML generation and packaging.
## Tags
#Music #App
## Guiding Principles & Intentions
- Reduce friction in building expressive Sampler instruments
    
- Prioritise clear visual feedback and intuitive UI
    
- Keep Ableton-native format compatibility
    
- Build with modular extensibility for advanced features
    
- Support both real-time audio recording and sample import workflows
## Key Features & Functionality
- **Visual MIDI Keyboard**: Displays mapped keys and supports drag-and-drop audio assignment
    
- **Audio Segment Editor**: Automatic and manual transient detection for slicing audio into regions
    
- **Mapping Modes**: Map segments to:
    
    - Sequential keys
        
    - Velocity layers
        
    - Round robin groups
        
- **Recording Support**: Record directly into the app using AudioKit and detect transients from input
    
- **Sampler XML Export**: Generate and gzip XML into .adv files compatible with Ableton Sampler
    
- **MIDI Playback**: Trigger and preview mappings using connected MIDI devices
## Architecture & Structure
- **Frontend**: SwiftUI interface with PianoKeyView, AudioSegmentEditorView, DragDrop handling
    
- **Core Logic**:
    
    - `SamplerViewModel`: manages mappings, file paths, export logic
        
    - `MultiSamplePartData`: data model for Sampler zones
        
    - `AudioRecorderManager`: handles permissions, recording, and file output
        
- **Audio Analysis**:
    
    - Transient detection based on RMS peaks per window segment
        
    - Sensitivity control via UI slider
        
- **Export Pipeline**:
    
    - Internal representation converted to XML
        
    - XML gzipped and written with .adv extension
## Implementation Roadmap
### Phase 1: Foundations & Basic Functionality

-  Import WAV and CAF files
    
-  Transient detection and slicing
    
-  Manual/auto region selection
    
-  Basic Sampler XML generation and .adv export
    

### Phase 2: Filename-Based Auto-Mapping

-  Implement parser for key, velocity, and round robin from filenames (e.g. `36_0-40_A.wav`)
    
-  Integrate with drag-and-drop flow
    
-  UI for verifying parsed mappings
    

### Phase 3: Loop & Parameter Editing

-  Add loop region setting per segment
    
-  UI for envelope, pan, pitch settings
    
-  Update `MultiSamplePartData` model to support advanced parameters
    

### Phase 4: Workflow & UX Enhancements

-  Preview sample from keyboard view
    
-  Export/import full mapping as project preset
    
-  UI polish and colour-coded key states
    

### Phase 5: Testing & Documentation

-  Add unit tests for XML generation and segment mapping
    
-  UI tests for drag/drop and playback
    
-  Write complete README with install/build/run instructions
## Current Status & Progress

## Next Steps
- [ ] Tweak audio audition – first X of waveform (defined) then fade out, then start again from silence
- [ ] Add snap to ZPC tickbox in inspetion mode
- [ ] Add auto trim checkbox
- [x] Break down problems into individual sections and tackle each one in smaller projects (2025-07-28)
- [x] Fix highlighting system for group creation (2025-07-28)
- [x] Fix group assignements button not working (2025-07-28)
- [x] Check that sampler patch export is still working (2025-07-28)
- [x]  Build filename parser for auto-mapping (2025-06-29)
- [ ]  Integrate loop point setting into UI and XML
- [x]  Begin XML testing framework (2025-07-28)
- [x] Implement grouped transient mapping (2025-07-28)
- [x] Fix zoom issues (2025-07-28)
- [x] Fix disappearing transient markers at high zooms (2025-07-28)
- [x] Fix group assignment re-sizing handles issue (resizing disproportionate to mouse movement) (2025-07-28)
- [x] Create annotated XML structure document
## Challenges & Solutions
- **Challenge**: Mapping complex structures from non-standard audio files
    
    - **Solution**: Use a structured filename convention and transient-based grouping as fallback
        
- **Challenge**: Valid .adv XML generation without official schema
    
    - **Solution**: Export reference .adv patches from Ableton and use as XML benchmarks
        
- **Challenge**: Usability of transient detection
    
    - **Solution**: Provide adjustable sensitivity and manual override interface
## User/Audience Experience
- Drop audio or record samples directly
    
- Detect and group transients
    
- Visually map segments to keys, velocities, and round robins
    
- Export directly into Ableton as a usable Sampler patch
    
- Minimal manual effort, high clarity and control
## Success Metrics
- Ableton loads .adv files without error
    
- User can build a 5-zone velocity-layered patch in under 5 minutes
    
- Filename parser works on >90% of test files
    
- Exported patches require no additional manual tweaking in Ableton
## Research & References
- AudioKit documentation (recording and waveform analysis)
    
- Reverse-engineered .adv files
    
- Transient detection algorithms using RMS and peak analysis
    
- Forum threads on multisample mapping in Live
    
- GitHub: [Ableton Sampler Format Explorers]
## Open Questions & Considerations
- Consider cross-export to EXS24/Kontakt formats
    
- Create CLI tool for batch patch generation
    
- Could auto-create Simpler patches as well (if XML format known)
    
- Explore pitch detection for multi-note recordings
## Project Log
### 23 Apr 2025 at 18:08
GitHub Commit to AbletonSampler by aeobrien ([34de604]): Drag and drop sample for transient detection and velocity/RR mapping incorporate...

### 23 Apr 2025 at 15:39
GitHub Commit to AbletonSampler by aeobrien ([b0fd166]): Added basic SampleDetailView.

### 21 Apr 2025 at 22:10
GitHub Commit to AbletonSampler by aeobrien ([ebf711e]): Implemented MIDI in/out.

### 21 Apr 2025 at 08:51
GitHub Commit to AbletonSampler by aeobrien ([83a0013]): Fixed 88 key view.

### 21 Apr 2025 at 00:44
GitHub Commit to AbletonSampler by aeobrien ([b85d08d]): Added piano roll view, round robin functionality.

### 20 Apr 2025 at 23:30
GitHub Commit to AbletonSampler by aeobrien ([8cbc6d4]): Moveable markers and two mapping methods.

### 20 Apr 2025 at 22:56
GitHub Commit to AbletonSampler by aeobrien ([1cc338f]): Intial audio regions via waveform display implementation, with rudimentary mappi...

### 20 Apr 2025 at 19:01
GitHub Commit to AbletonSampler by aeobrien ([492dea8]): Initial Semi-Working Version

### 20 Apr 2025 at 18:50
GitHub Commit to AbletonSampler by aeobrien ([6383854]): Initial Commit

### 15 Jun 2025
- Phase 1 mostly complete – file drag and drop, waveform display, transient detection, drag-and-drop, mapping all functional

### 2025-06-12
- Refactored `SamplerViewModel` to improve XML output
- Added `AudioSegmentEditorView.detectAndSetTransients()` RMS-based detection

### 2025-06-14
- Confirmed basic .adv files open in Ableton
- Assembled core status summary and roadmap
- Began planning filename-based auto-mapping logic
## External Files
[Any files related to the project outside of the Obsidian folder and their locations]
## Repositories
### Local Repositories
[Local repository paths and descriptions]

### GitHub Repositories
https://github.com/aeobrien/AbletonSampler
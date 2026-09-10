# ChecklistManifesto

## Version History
- v0.1 - 14 Jun 2025 - Migrated to structured format
## Core Concept
_Checklist Manifesto_ is a user-friendly, repeatable checklist app designed to support externalised thinking, reduce reliance on memory, and improve task consistency. Inspired by Atul Gawande’s _The Checklist Manifesto_, the app provides reusable checklists for recurring tasks — from packing to procedural workflows — with automatic reset, nested sub-items, multiple checkbox states, and completion tracking. It is designed to make complex routines manageable and forgettable steps visible.
## Tags
#Productivity #App
## Guiding Principles & Intentions
- **Externalise Process**: Free up mental load by relying on well-designed checklists.
    
- **Repeatable Utility**: Create permanent checklists for recurring contexts (e.g. shopping, travel, admin).
    
- **Structural Clarity**: Use nesting and hierarchy to reflect task grouping.
    
- **State Tracking**: Multi-tick logic allows nuanced progress tracking (e.g. "gathered" vs. "packed").
    
- **Minimal Maintenance**: Auto-reset keeps lists relevant without manual upkeep.
    
- **Data Portability**: JSON import/export supports backup and sharing.
## Key Features & Functionality
### 1. Persistent, Reusable Checklists

- Create lists that retain their structure after use
    
- Define per-list auto-reset intervals (e.g. daily, weekly, custom)
    

### 2. Hierarchical Subdivision

- Nest items under headings (e.g. "Toiletries" under “Packing”)
    
- Auto-complete parent item when all children are ticked
    

### 3. Dual Checkbox States

- Each list item can support up to two user-defined checkbox states
    
    - e.g. first tick = "collected", second tick = "packed"
        
- Tick logic flows up from children to parents, but not bidirectionally
    

### 4. Tag-Based Organisation

- Lists can be tagged and browsed by tag (e.g. "Travel", "Monthly Admin")
    
- Lists can appear under multiple tags
    

### 5. Completion Tracking

- Each list displays total item count and percentage completion
    
- Real-time feedback as items are ticked
    

### 6. JSON Import/Export

- Share or back up checklists via JSON
    
- Supports both structure and tick state
    

### 7. Optional Features

- Manual reset option
    
- List duplication for variation
    
- Sort/reorder items within lists
## Architecture & Structure
- **Frontend**: Built in **SwiftUI**, optimised for iOS devices
    
- **Data Storage**: Local persistence using **CoreData** or **AppStorage**, iCloud support optional
    
- **Data Model**:
    
    - `Checklist`: name, tags, reset interval, items
        
    - `ChecklistItem`: title, parent ID, tick states (array), children (optional)
        
- **Logic Layer**:
    
    - Tick propagation engine (child-to-parent only)
        
    - Auto-reset engine (scheduled resets)
        
    - Completion calculation engine
        
- **Import/Export Layer**:
    
    - JSON schema with nested items and tick states
        
    - File and clipboard import/export
## Implementation Roadmap
### Phase 1: Core App Framework

- Build basic checklist creation and editing UI
    
- Implement tick states and child-parent logic
    
- Display nested items and apply progress calculations
    

### Phase 2: Reset Logic & Data Layer

- Add auto-reset functionality with timers or time checks
    
- Define CoreData model for persistence
    
- Implement tagging and list duplication
    

### Phase 3: Import/Export & UX Enhancements

- Build JSON import/export functionality
    
- Add sort/reorder, optional manual reset
    
- Add completion percentage and visual feedback
    

### Phase 4: Polish & Beta Testing

- Add animations, accessibility refinements, onboarding
    
- Conduct beta testing for edge cases and UX feedback
    
- Finalise app icon, branding, and App Store materials
## Current Status & Progress

## Next Steps
- [ ] Fix persistence problems
- [ ] Populate lists
- [ ] Create logo and splash screen
## Challenges & Solutions
- **Challenge 1: Propagating Checkbox State Across Nesting Levels**  
    _Solution_: Use recursive logic to calculate parent status based on child completion without making state bi-directional.
    
- **Challenge 2: Auto-Reset Scheduling**  
    _Solution_: Store a `lastCompletedDate` per list and check against `resetInterval` each time the list is accessed.
    
- **Challenge 3: Handling Deep Nesting Cleanly in UI**  
    _Solution_: Use collapsible sections and consistent indentation to reflect hierarchy, preserving readability.
    
- **Challenge 4: Complex Tick Logic Customisation**  
    _Solution_: Allow user to define tick labels per level; keep logic consistent under-the-hood while allowing semantic variance in display.
    
- **Challenge 5: JSON Schema Robustness**  
    _Solution_: Define strict schema for nesting, tick states, and tags; validate on import to prevent malformed lists.
## User/Audience Experience
- **Overview Screen**: Lists sorted by tags or custom order, with visual indication of progress
    
- **List View**: Clean, collapsible hierarchy with tickable items
    
- **Customisation**: Configure ticks, reset interval, and tag visibility
    
- **Interaction Flow**:
    
    1. User creates checklist with structure and tick logic
        
    2. Checks off items during task
        
    3. List auto-resets based on defined interval
        
    4. Lists can be reused, duplicated, or shared as templates
## Success Metrics
- Users consistently return to reuse checklists for repeat tasks
    
- Lists with multiple tiers function intuitively and clearly
    
- Auto-reset works reliably and reflects time logic as expected
    
- Users report reduced cognitive load and improved reliability
    
- App reviews indicate satisfaction with flexibility and structure
## Research & References
- Atul Gawande’s _The Checklist Manifesto_
    
- Competitive apps (e.g. Things, Todoist, Packing Pro)
    
- Apple Human Interface Guidelines (iOS structure and accessibility)
    
- JSON schemas for hierarchical task structures
    
- User feedback from similar productivity tools
## Open Questions & Considerations
- Should list item completion history be tracked over time (analytics)?
    
- Would integration with calendar/reminders enhance usability or bloat?
    
- Should iCloud sync be included in v1 or saved for later?
    
- How best to visualise percentage complete in nested lists?
    
- Should templates be shared via AirDrop/QR or only through JSON?
## Project Log
### 7 Jun 2025 at 18:46
GitHub Commit to Checklist-Manifesto by aeobrien ([526c5e3]): Fully implemented CRUD, enabled autocollapse for completed task groups, added ic...

### 7 Jun 2025 at 16:01
GitHub Commit to Checklist-Manifesto by aeobrien ([79d9058]): Initial Commit

### 7 Jun 2025 at 13:41
GitHub Commit to Checklist-Manifesto by aeobrien ([a4d9f82]): Initial Commit

### 15 Jun 2025
- Functioning app up and running, some items persistently checking on reset

### 14 Jun 2025
Migrated to structured format
## External Files
[Any files related to the project outside of the Obsidian folder and their locations]
## Repositories
### Local Repositories
[Local repository paths and descriptions]

### GitHub Repositories
https://github.com/aeobrien/Checklist-Manifesto
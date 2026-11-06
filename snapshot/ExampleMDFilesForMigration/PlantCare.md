# PlantCare

## Version History
- v0.1 - 15 Jun 2025 - Migrated to structured format
## Core Concept
PlantMinder is a user-friendly plant care assistant app designed to help users manage and maintain their houseplants with greater confidence and consistency. It works by linking a structured model of the user's home (rooms and window directions) with detailed care profiles for each plant. The app then guides users through a smart care routine that adapts based on each plant’s needs, last care date, environmental conditions, and user behaviour. PlantMinder helps prevent overwatering, optimises plant placement, and supports proactive plant maintenance.
## Tags
#Productivity #App
## Guiding Principles & Intentions
- **Low-effort, high-confidence**: Make plant care simple for users without requiring constant research or memory.
    
- **Environment-aware**: Tailor care recommendations based on real-world placement of plants within the home.
    
- **Flexible and forgiving**: Offer advice while allowing users to override automated suggestions.
    
- **Scalable and extensible**: Design the app to support additional features like reminders, community-sourced data, and AI feedback over time.
## Key Features & Functionality
- **Room & Window Mapping**:  
    Users define rooms in their home and specify windows with cardinal directions (e.g., south-facing).
    
- **Plant Profiles**:  
    Each plant entry includes:
    
    - Name
        
    - Preferred light type (direct, indirect, low)
        
    - Preferred light direction(s)
        
    - Watering frequency and instructions
        
    - Humidity and rotation preferences
        
    - Care notes
        
    - Room assignment
        
- **Care Routine Walkthrough**:  
    A guided process that steps through each room, listing the plants within and their current care requirements (watering, rotation, misting, dusting). Each task is tickable and logs the action time.
    
- **Main Interface**:
    
    - App logo and title
        
    - Start Care Routine button
        
    - Access to:
        
        - Rooms view (edit/add rooms and assign windows)
            
        - Plants view (full searchable list with statuses)
            
- **Smart Watering Tracking**:
    
    - Automatic calculation of when each plant next needs water
        
    - Warnings when attempting to water too early
        
    - Override option for manual early watering
        
- **Search & Organisation**:
    
    - Searchable plant list with filters
        
    - Room view shows number of plants and windows per room
## Architecture & Structure
- **Rooms**:
    
    - Name
        
    - List of windows (each with direction)
        
    - List of assigned plants
        
- **Plants**:
    
    - Name
        
    - Care metadata (light, direction, watering, misting, dusting, etc.)
        
    - Assigned room
        
    - Last watered / rotated / dusted timestamps
        
- **Routine Engine**:
    
    - Iterates through rooms and plants
        
    - Calculates due tasks based on current date and care intervals
        
    - Flags overdue, due, and not-yet-due tasks
        
    - Tracks user actions (tick boxes for watering, misting, etc.)
## Implementation Roadmap
### Phase 1: Core Functionality

- Create model structure for rooms, windows, and plants
    
- Build core views: Home, Rooms, Plants
    
- Implement care routine walkthrough with task tracking
    
- Add watering logic and due date display
    

### Phase 2: Reminders & Smart Advice

- Weekly reminder to run care routine
    
- Daily notifications for plants that need care
    
- Separate tracking for misting, dusting, rotation
    
- Early watering override system with warnings
    

### Phase 3: Data Integration

- API connection for automatic plant information enrichment
    
- UI for importing plant data from public sources
    
- UI suggestions for optimal room assignment based on plant light/direction needs
    

### Phase 4: AI Integration (Long-Term)

- LLM question/answer system using context from plant profile and environment
    
- Editable response-based notes updates
    
- Suggest placement changes or problem diagnoses based on user input
## Current Status & Progress

## Next Steps
- [ ] Routine continuing when it's already finished.
- [ ] Auto review pics after routine
- [x] In runner, make progress bar based on spaces, not plant care steps (2025-07-31)
- [ ] Add camera access not just photo roll
- [x] Can’t add plants to outdoor zones, also make it easier to add them to anywhere!!  (Might have done this already!) (2025-07-23)
- [x] Update all watering instructions to reflect updated specific requirements (2025-07-23)
- [x] Change AI prompt for new plants to reflect specific requirement for watering instructions – all instruction fields to contain a guiding principle the user can use, and an indicator of how much to water, ie. Water sparingly, letting the soil dry out completely between waterings, or Water deeply when top 1cm is dry, or Water a moderate amount, keeping oil moist but not soggy, etc. So the user has specific instructions for how to judge if that plant needs watering right now, and if so, how much.  (2025-07-23)
- [x] Turn off dusting and misting for outdoor plants (2025-07-23)
- [ ] Improve AI update plant listing
- [x] Fix icloud documents backup
- [x] Add outdoor zones to plant care routine
- [x] Add visual description of all plants
- [x] Add indicator for when picture has been added to plant.
- [x] Fix immediate registering of care steps.
- [x] Improve AI advice system for length, follow-up questions and not returning to same page after request has been sent
- [x] add general review based on all plants and all pictures at end of routine.
- [x] Only show relevant plant care steps.
- [x] don’t show a step if not due for more than five days.
- [x] only show overdue steps in red.
- [x] Add full database submission for suggested improvements for example does a plant that needs misting not have misting instructions.
- [x] Close add plant page after plant added.
- [x] Number copies.
- [x] Include visual description field in add from AI.
- [x] Fold add from AI into add page.
- [x] Add icloud documents backup
- [x] Can't add plants to rooms/zones?
- [x] Add iCloud Documents backup/restore functionality
- [x] Add photo step to plantcare routine
- [x] Add naming conventions
- [x] Incorporate porch and garden/outdoor plants
- [x] Add photo capability to AI questions (2025-07-06)
- [x] Plantcare directions in routine are getting cut off (2025-07-06)
- [x] Fix message at end of routine to not be dependent on how many steps have been completed (because sometimes it's better to not complete them!) (2025-07-06)
- [x] Watering period changes not persisting
- [x] Implement weekly reminder to run care routine/daily notifications for individual plans
- [x] Implement separate tracking for misting, dusting, rotation
- [x] Early watering warning system within routine runner (with user override)
- [x] Implement API connection for automatic plant information retrieval
- [x] Automatic suggestions for optimal room assignment based on plant light/direction needs
- [x] LLM question/answer system using context from plant profile and environment
- [x] Editable response-based notes updates
- [x] Submit photos/care data care on finishing room, not on finishing whole routine (2025-07-23)
- [x] Save routine position so if the user leaves and resumes, they can pick up where they left off (and photos/plant care steps aren’t lost) (2025-07-23)
- [x] Auto submit all pictures for health check at end of routine (2025-07-23)
- [x] Turn health check (all AI settings?) on and off in settings (2025-07-23)
## Challenges & Solutions
|Challenge|Proposed Solution|
|---|---|
|Plants with overlapping or vague care needs|Use default options with user overrides and allow care metadata to be highly flexible|
|Too many tickable care types = cluttered UI|Group and visually separate care types; collapse tasks that aren’t due|
|Overwatering risk from early/manual inputs|Warning system with logic to detect too-frequent care actions, plus manual override|
|Room-direction mapping might be confusing|Use diagrams or compass UI to simplify window direction input|
|Reminder fatigue|Combine routine and urgent plant reminders into one unified, low-frequency notification system|
## User/Audience Experience
- New users onboard by inputting their rooms, windows, and plants
    
- On regular care days, they open the app and tap “Start Care Routine”
    
- The app guides them room by room with precise care instructions
    
- They check off completed tasks, receive tips or alerts, and finish the round
    
- Between care routines, the user can check plant status or add/update data
## Success Metrics
- Daily/weekly user retention
    
- Number of plants added and maintained over time
    
- Care routines completed vs. skipped
    
- Reduction in overwatering (via early warning override logging)
    
- Positive qualitative feedback on simplicity and usefulness
## Research & References
- Plant care APIs (e.g. Trefle, OpenPlantDB)
    
- UX patterns for task tracking/checklist apps
    
- Light exposure guidelines for common houseplants
    
- Calendar-based habit tracking models
## Open Questions & Considerations
- Should “light direction” allow multiple values (e.g. SE + E) per plant?
    
- Should rooms support non-cardinal window descriptions (e.g. “corner window”)?
    
- Would users want custom watering intervals (e.g. every 10 days)?
    
- Would integrating a soil moisture tracking method (manual input or sensor) add real value or just complexity?
    
- How to elegantly support users with large plant collections vs. just a few?
## Project Log
### 15 Jun 2025
- Migrated to structured format
## External Files
[Any files related to the project outside of the Obsidian folder and their locations]
## Repositories
### Local Repositories
[Local repository paths and descriptions]

### GitHub Repositories
https://github.com/aeobrien/PlantCare.git
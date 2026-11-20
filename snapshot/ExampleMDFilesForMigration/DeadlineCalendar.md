# DeadlineCalendar

## Version History
- v0.1 - 15 Jun 2025 - Migrated to structured format
## Core Concept
Deadline Calendar is a SwiftUI-based iOS app designed to help users track deadlines across multiple projects in a single, unified chronological view. It simplifies deadline management by allowing users to build reusable task templates based on final delivery dates, while also integrating task-based prioritisation and a Kanban-style workflow. It is especially well-suited to creators or professionals juggling multiple project pipelines where each project follows a familiar structure.
## Tags
#Productivity #App
## Guiding Principles & Intentions
- **Chronological Clarity**: Display upcoming tasks in a clean, unified timeline across all projects
    
- **Template Efficiency**: Automate recurring project structures via reverse-calculated deadlines
    
- **Flexible Task Handling**: Accommodate both project-based and ad hoc tasks
    
- **Focus & Prioritisation**: Surface what matters most, when it matters most
    
- **Non-Intrusive Assistance**: Support productivity with gentle guidance, not micromanagement
## Key Features & Functionality
### Deadline View

- **Chronological Task List**: Displays all deadlines sorted by due date
    
- **Toggle View Mode**: Show either due dates or countdown (days remaining)
    
- **Visual Urgency Indicators**: Tasks change colour as due dates approach
    
- **Mark as Complete**: Completed tasks disappear from the list
    

### Task Templates

- **Project-Based Task Creation**: Add all related tasks by entering final delivery date
    
- **Backdated Scheduling**: Each task’s due date calculated based on fixed offset from master deadline
    
- **Custom Templates**: Define and reuse project structures for recurring workflows
    
- **Standalone Tasks**: Add non-template tasks for one-off responsibilities
    

### Trigger-Based Tasks

- **Conditional Activation**: Delay task visibility until prerequisite action is manually confirmed
    
- **Task Unblocking**: Tapping a trigger enables any dependent tasks
    

### Planned Functionality

#### Notifications _(Pending)_

- Smart reminders when tasks are due soon
    

#### Widget _(Pending)_

- Rebuild of homescreen widget to display next few upcoming tasks
    

---
## Architecture & Structure
### Technical Architecture

- **Platform**: iOS (SwiftUI)
    
- **Architecture Pattern**: MVVM with `@StateObject` and `@ObservedObject`
    
- **Data Layer**: `@AppStorage`, expanding to CoreData for metadata persistence
    
- **Navigation**: TabView with scoped view responsibilities
    
- **Persistence Strategy**: Modular extensions to existing data models
    

### Key Modules

- `DeadlineListView`: Chronological task display
    
- `TemplateEngine`: Handles backward deadline generation
    
- `TaskTrigger`: Manages manual task activation
    
- _(Planned)_ `KanbanBoardView`: Drag-and-drop lane-based display
    
- _(Planned)_ `FocusEngine`: One-task-at-a-time prioritisation system
    
- _(Planned)_ `TaskScoring`: Weighs urgency, effort, importance
    

---
## Implementation Roadmap
### Phase 1: Core Functionality ✅

- Task creation
    
- Reverse-template scheduling
    
- Chronological view with urgency indicators
    
- Trigger-based visibility
    
- Completion logic
    

### Phase 2: Notification & Widget System 🔜

- Smart notifications for upcoming tasks
    
- Homescreen widget showing top upcoming items
    

### Phase 3: Kanban Integration 🔜

- Metadata model expansion
    
- `Kanban` tab with two-column layout
    
- Task card UI and sorting logic
    

### Phase 4: Focus System & Prioritisation 🔜

- Scoring algorithm for task focus
    
- Single-task execution UI
    
- In-session controls and timer integration
    

### Phase 5: Manual Open Task Support 🔜

- New task UI for non-deadline items
    
- Logic for `Open` lane population
    

---
## Current Status & Progress

## Next Steps
- [x] Can't untrigger triggered triggers
- [x] Add icloud documents backup (2025-07-07)
- [x] Faster widget refresh (2025-07-07)
- [x] Add project colours to settings page (2025-07-06)
- [x] General UI tidy (2025-07-07)
- [x] Faster refresh of deadlines on load (2025-07-07)
- [x] Add dates to triggers
- [x] Test notification in the wild (2025-07-07)
- [x] add notification formatting (2025-07-06)
- [x] add test functionality for testing what it looks like
- [x] Notifications are showing "no upcoming deadlines" despite there being deadlines overdue and upcoming (2025-06-29)
- [x] Widget adding "Standalone Deadlines" into names
- [x] Notification format is unreadable
- [x] Widget not displaying overdue deadlines
- [x] Add decativate trigger functionality
- [x] Remove "standalone deadlines" text
- [x] General UI sweep
- [x] Move add standalone project button
- [x] Could sub deadlines be automatically reordered by date in template editor
- [x] Cross out activated triggers in project trigger view
- [x] Add one off tasks
- [x] Deadlines due today not appearing on widget
- [x] Notification not working – notification today congratulated me on staying on top of all my deadlines when I have one deadline overdue and one due today.
- [x] Some deadlines are not showing up in the main app. They're showing up in the widget, but not in the main app, and I'm not sure why. So I need to check that the logic for those is both the same, and that it's not missing anything.
- [x] Deadlines due today not appearing in widget
- [x] Implement notifications
- [x] Reinstate Widget
- [x] Implement tap deadline in deadline timeline to go to project AND edit the tapped deadline
- [x] After edit, project overview not updating immediately with edited information
## Challenges & Solutions
### Technical

- **Non-Breaking Expansion**: New properties added with backward compatibility
    
- **Task Prioritisation Logic**: Clean scoring model balancing multiple factors
    
- **Task-State Management**: Parking, blocking, and completion handled cleanly
    

### User Experience

- **Avoiding Overload**: One-task Focus tab prevents overwhelm
    
- **Visual Clarity**: Colour-coding and task scoring support informed decision making
    
- **Flexible Workflows**: Support both rigid deadlines and fluid personal tasks
    

---
## User/Audience Experience
Typical user workflow:

1. Create a new project from a template by selecting final delivery date
    
2. View all upcoming subtasks in a single timeline
    
3. Unblock tasks as prerequisites are completed
    
4. Mark completed tasks and review progress
    
5. (Future) Use the Kanban view for strategic task management
    
6. (Future) Switch to Focus tab when deep work is needed
    

Tabs:

- `Deadlines`: chronological view of all upcoming tasks
    
- `Kanban`: visual board for high-level work planning _(planned)_
    
- `Focus`: single-task guided prioritisation _(planned)_
    
- `Settings`: for future expansion
    

---
## Success Metrics
- **Template Usage Rate**: Frequency of template-based project creation
    
- **Task Completion Rate**: % of tasks completed before due
    
- **Focus Engagement**: Frequency of use of focus sessions (once implemented)
    
- **Deadline Overdue Count**: How many deadlines are missed
    
- **Task Velocity**: Time between task unblocking and completion
    

---
## Research & References
- Behavioural psych: goal gradient theory for motivation
    
- HCI research on cognitive load and decision fatigue
    
- Project management patterns (Gantt, reverse planning)
    
- Kanban methodology for WIP visualisation
    
- iOS app design principles and HIG compliance
    

---
## Open Questions & Considerations
- Combining deadline tracking with personal goal management opens up hybrid use
    
- Template system helps automate complex workflows with minimal user input
    
- Future AI-based task suggestions could help promote flow and reduce burnout
    
- Focus mode integrates well with Pomodoro-style workflows
    
- Kanban lane caps prevent cognitive overload and decision paralysis
    

---
## Project Log
### 23 Jun 2025 at 16:11
GitHub Commit to DeadlineCalendar by aeobrien ([70c22dd]): Fixed activated triggers strikethrough display, added modal for sub-deadline det...

### 23 Jun 2025 at 15:33
GitHub Commit to DeadlineCalendar by aeobrien ([34cad43]): Implemented standalone deadlines and individual project trigger views with progr...

### 22 Jun 2025 at 14:25
GitHub Commit to DeadlineCalendar by aeobrien ([0340c05]): Refactoring.

### 21 Jun 2025 at 13:27
GitHub Commit to DeadlineCalendar by aeobrien ([e359d68]): Added package.swift and .gitignore.

### 17 Jun 2025 at 01:26
GitHub Commit to DeadlineCalendar by aeobrien ([764a6c8]): Fixed inconsistencies between app and widget.

### 15 Jun 2025 at 17:30
GitHub Commit to DeadlineCalendar by aeobrien ([77aadd6]): Merge remote-tracking branch 'refs/remotes/origin/main'

### 30 May 2025 at 00:29
GitHub Commit to DeadlineCalendar by aeobrien ([b7fff9b]): Added state variable to control the display format (days remaining vs. due date)

### 30 May 2025 at 00:29
GitHub Commit to DeadlineCalendar by aeobrien ([27cb50a]): Added state variable to control the display format (days remaining vs. due date)

### 19 Apr 2025 at 14:47
GitHub Commit to DeadlineCalendar by aeobrien ([1230d9d]): Initial Commit

### 23 Jun 2025
Developed trigger system, added standalone deadlines. 

App fully functional, ready for integration into Crux.

### 15 Jun 2025
- Completed task template engine and reverse-calculated scheduling
- Integrated trigger system for blocked task activation
- Implemented visual urgency indicators and chronological task list
- Began planning architecture for Kanban and Focus modules
- Notifications and widget system scoped for Phase 2 implementation
## External Files
[Any files related to the project outside of the Obsidian folder and their locations]
## Repositories
### Local Repositories
[Local repository paths and descriptions]

### GitHub Repositories
https://github.com/aeobrien/DeadlineCalendar
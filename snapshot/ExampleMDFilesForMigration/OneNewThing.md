# OneNewThing

## Version History
- v0.1 - 14 Jun 2025 - Migrated to structured format
## Core Concept
OneNewThing is a mobile app designed to help users experience 52 new things across a year—one per week. Users create or import a list of experiences and receive one randomised task each week. With reminders, tracking, reflection tools, and voice journaling, the app promotes curiosity, novelty, and self-reflection, aiming to gently shift users out of routine and into a more exploratory, engaged life.
## Tags
#Self_Improvement #Mental_Health #App
## Guiding Principles & Intentions
* **Consistency through variety**: Build a habit of doing new things without needing to over-plan.

* **Gentle challenge**: Provide low-pressure nudges into personal growth and newness.

* **Reflection matters**: Support meaning-making through micro-journaling and voice notes.

* **Simplicity**: Keep the UI and feature set lightweight, clean, and focused.

* **Privacy-first**: Store user data securely, with optional backups.
## Key Features & Functionality
* **Personal Experience List**

* Add/edit up to 52 custom experiences

* Categorise by theme (adventure, skill, sensory, social, etc.)

* **Weekly Task Generator**

* Auto-selects one new experience each week

* Allows 2 re-rolls per week if needed

* **Reminders & Deadlines**

* Push notifications to complete tasks

* One-week completion window per task

* **Completion Tracking**

* Visual progress bar / radial tracker

* List view with completed vs pending activities

* **Reflection Tools**

* Micro-journaling prompts per completed task

* Voice memo support for reflection capture

* All responses time-stamped and stored

* **Backup & Data Sync**

* Optional MySQL backup integration

* Cloud-hosted backend for future-proofing
## Architecture & Structure
* **Frontend**

* React Native for cross-platform app

* Clean tabbed interface (Tasks / Reflections / Settings)

* **Backend**

* Node.js with Express for API logic

* REST endpoints for tasks, completions, notes

* **Database**

* MySQL for structured storage

* Tables: `users`, `experiences`, `reflections`, `tasks`, `settings`

* **Hosting**

* AWS or Heroku for deployment

* Firebase Cloud Messaging for push notifications
## Implementation Roadmap
### Phase 1: Research & Planning

* Competitor analysis

* Define personas and use cases

* Create initial wireframes

### Phase 2: Prototype MVP

* Build experience list creation UI

* Implement weekly task generator

* Add task tracking and re-roll logic

### Phase 3: Backend & Reminders

* Build REST API and database schema

* Add weekly push notifications and deadline logic

### Phase 4: Reflection & Journaling

* Add voice memo and journaling prompt functionality

* Store reflections and allow retrieval per task

### Phase 5: User Testing

* Closed beta test

* Gather UX feedback and iterate

### Phase 6: Launch

* Prepare for App Store / Play Store submission

* Final polish and release

### Phase 7: Post-Launch Support

* Monitor bugs and user feedback

* Plan updates and feature expansion
## Current Status & Progress

## Next Steps
- [x] Progress tracker/bookmark system
- [ ] Rename/add details to all activities
- [x] Fix single roll problem
- [x] Find better way of choosing own tasks
- [x] Fix time remaining
- [x] Make notifications more urgent/frequent as time runs out
## Challenges & Solutions
* **User Dropoff Over Time**

* *Solution*: Add optional gamification, streak tracking, social sharing, and motivational prompts

* **Data Loss / Sync Issues**

* *Solution*: Offer encrypted cloud backup to MySQL

* Use local caching to handle offline use

* **Task Relevance / Difficulty Mismatch**

* *Solution*: Let users rate or flag experiences as too difficult and offer re-rolls
## User/Audience Experience
* **First Use**

* Smooth onboarding with tips for choosing meaningful tasks

* Encouragement to start small

* **Ongoing Use**

* Weekly task reminder

* Task view with action, status, deadline, and reflection section

* **Completion**

* Satisfying check-off with confetti or similar light flourish

* Prompted to reflect via short guided text or voice
## Success Metrics
* Weekly active users maintaining streaks

* Percentage of completed experiences per user

* Number of reflections logged (text or voice)

* Positive reviews and user testimonials

* Retention over full 52-week cycle
## Research & References
* Behavioural psychology on novelty and habit stacking

* Stoic and modern journaling frameworks

* Apps with similar cadence (e.g. "1 Second Everyday", "52 Lists")

* User research notes and wireframe iterations
## Open Questions & Considerations
* Should tasks expire automatically if not done within the week?

* Would a companion web dashboard for backup/export add value?

* Should users be able to import lists from friends or templates?

* Is there benefit to social features or is solitude part of the appeal?

* Do some users want thematic arcs (e.g., “month of courage”, “month of creativity”)?
## Project Log
### 15 Jun 2025
- Basic app up and running
- A few problems with repetition period, choosing your own task, not allowing multiple rolls, and lack of data on activities.

### 14 Jun 2025
Migrated to structured format
## External Files
[Any files related to the project outside of the Obsidian folder and their locations]
## Repositories
### Local Repositories
[Local repository paths and descriptions]

### GitHub Repositories
https://github.com/aeobrien/1NewThing
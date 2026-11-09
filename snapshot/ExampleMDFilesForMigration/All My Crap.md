# All My Crap

## Version History
- v0.1 - 22 Jun 2025 - Initial project creation
## Core Concept
All My Crap is an iOS cataloging app designed to help users meticulously organize and track the locations of their possessions within their living or working spaces. It functions as a comprehensive inventory system, allowing users to list down rooms and specific storage areas or containers within those rooms, down to very detailed subcontainers, to pinpoint exactly where an item is stored.
## Tags
#Productivity #App
## Guiding Principles & Intentions
- To provide a seamless organizational tool that reduces the time spent searching for items.
- To create an intuitive user experience that simplifies cataloging possessions through a hierarchical structure.
- To offer peace of mind and efficiency in managing and locating personal belongings.
## Key Features & Functionality
- **Room and Container Cataloging**: Users can add rooms (e.g., living room, studio, kitchen) and within those, specific containers and subcontainers (e.g., drawers, cupboards) to organize items.
- **Item Addition with Hierarchical Selection**: Add items to the inventory with the ability to select the exact room, container, and subcontainer they are stored in.
- **Duplicate Item Alert**: Alerts users if an item being added already exists or if a similar item is in the system, suggesting consolidation.
- **Search Functionality**: Enables users to search for items and view their exact locations within the hierarchical structure of rooms and containers.
- **Full CRUD Interface**: Provides capabilities to create, read, update, and delete (CRUD) both items and their locations.
- **Item and Container Movement**: Allows users to easily move items or containers to different locations within the hierarchy.
- **Hierarchical Limit**: Imposes a limit of 15 layers of hierarchy to ensure manageability and performance.
## Architecture & Structure
- The app will utilize a hierarchical database structure to manage the nesting of rooms, containers, and subcontainers.
- A CRUD interface will be implemented for managing items and their locations within the hierarchy.
## Implementation Roadmap
1. **Phase 1**: Develop the basic iOS application framework with CRUD functionalities.
2. **Phase 2**: Implement the hierarchical structure for rooms, containers, and subcontainers.
3. **Phase 3**: Add search functionality and duplicate item alerts.
4. **Phase 4**: Integrate the ability to move items and containers within the hierarchy.
5. **Phase 5**: Conduct user testing and iterate based on feedback.
6. **Phase 6**: Finalize the app for release in the App Store.
## Current Status & Progress

## Next Steps
- [x] Add tags for items (based on minimisation) (2025-06-28)
- [x] Add review checkbox/date for each sublocation (2025-06-28)
- [x] Add multiple items as list (2025-06-28)
- [x] Begin development of the basic application framework.
- [x] Design the database schema for the hierarchical structure.
- [x] Implement duplicate checking
- [x] Commit and push
- [x] Can’t add items to containers (because I can’t get in!)
- [x] Not immediately showing new containers/items
- [ ] Finish testing (target: 2026-03-01)
  - [ ] Finish cataloguing the spare room
  - [ ] Finish cataloguing the box room
  - [ ] Trial every action type (sell, charity, fix, move, throw away)
  - [ ] An experiment with adding and deleting single items
## Challenges & Solutions
- **Challenge**: Managing a deep hierarchy without impacting performance.
  - **Solution**: Implement efficient database indexing and limit the hierarchy to 15 layers.
- **Challenge**: Ensuring intuitive user experience in navigating and managing the hierarchy.
  - **Solution**: Develop a user-friendly interface with drag-and-drop capabilities for moving items and containers.
## User/Audience Experience
Users will interact with the app through a clean and intuitive interface, where they can easily add rooms, containers, and items, and navigate the hierarchy to find or move possessions. The search function and alerts for duplicate items enhance the user experience by making the management of items straightforward and effective.
## Success Metrics
- Reduction in the time users spend searching for items.
- User satisfaction ratings and feedback.
- Number of active users and engagement metrics.
- Feedback loop effectiveness in implementing user-requested features.
## Research & References
- Inventory management systems and organizational apps for inspiration on functionality and design.
- User interface design best practices for mobile apps to ensure an intuitive user experience.
## Open Questions & Considerations
- How to handle large inventories without overwhelming the user?
- Potential for integration with IoT devices for automatic item tracking.
- Consideration for a future Android version or web interface.
## Project Log
### 9 Feb 2026 at 23:09
Project updated via wizard (Next Steps): I want to add a new parent task to this project, which is to finish testing. Now the child tasks und...

### 22 Jun 2025 at 22:50
GitHub Commit to AllMyCrap by aeobrien ([6b579d9]): Initial commit

### 22 Jun 2025 at 16:13
GitHub Commit to AllMyCrap by aeobrien ([f1513d0]): Initial Commit

### 28 Jun 2025
- Conceptualization phase completed.

### 22 Jun 2025
Project created
## External Files
- Design mockups and user flow diagrams (Location TBD).
## Repositories
https://github.com/aeobrien/AllMyCrap
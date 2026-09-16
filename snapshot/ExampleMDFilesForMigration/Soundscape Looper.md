# Soundscape Looper

## Version History
- v0.1 - 6 Aug 2025 - Initial project creation
## Core Concept
Soundscape Looper is an innovative app designed to function similarly to a granular synthesizer. Users can import an audio file, set an anchor point, and create multiple looping voices. Each voice functions as a loop with its own beat subdivision, allowing for complex rhythmic patterns that can gradually move out of phase with each other, inspired by compositions like those of Steve Reich. The app enables the creation of textured soundscapes with specific, customizable rhythms, offering both musical and non-musical loop length definitions.
## Tags

## Guiding Principles & Intentions
- To enable users to create complex, evolving soundscapes easily.
- To offer a high degree of customization for rhythmic patterns.
- To inspire creativity through a user-friendly interface.
## Key Features & Functionality
- **Audio File Import**: Users can import their desired audio files to manipulate.
- **Anchor Point Setting**: Allows for the selection of a starting point in the audio file from which loops are generated.
- **Multiple Voices**: By default, two voices are available, with the option to add more, each acting as a separate loop.
- **Global Tempo Setting**: Users can set a global tempo that affects all loops.
- **Beat Subdivision Customization**: For each voice, users can set different beat subdivisions (e.g., eighth notes, quarter notes, dotted eighth notes, etc.), allowing for complex rhythmic patterns.
- **Loop Modes**: Multiple looping modes including start to finish, reverse, and ping pong (forwards then backwards).
- **Phase Shift Patterns**: Ability to create patterns that gradually move out of phase with one another.
- **Seamless Loop Transitioning**: As the anchor point moves, loops change seamlessly, waiting for the end of the current loop before adapting.
- **Wander Mode**: A feature where the anchor point and individual loops can wander within defined parameters, constantly altering the soundscape.
- **Rhythmic Evolution**: Loops can progress through a sequence of rhythmic values, further diversifying the soundscape texture.
- **Non-Musical Loop Length Definition**: Users can define loop lengths in milliseconds, not just by musical notation.
## Architecture & Structure
Placeholder for technical architecture or organizational structure details.
## Implementation Roadmap
Placeholder for phase-by-phase implementation plan details.
## Current Status & Progress
Placeholder for summary of the project's current status and progress.
## Next Steps
- [ ] Enable anchor point wandering, per voice wandering – for now, define max time values and wandering speed and position of anchor point or voices should move between default position and that location.
- [ ] Add loop length variation
- [ ] Add per loop envelopes
- [ ] Add per loop filters
## Challenges & Solutions
- **Challenge**: Ensuring smooth transition when loops adapt to a new anchor point.
  - **Solution**: Implement a system that waits for the current loop to end before adapting to the new anchor point.
- **Challenge**: Creating a user interface that is intuitive yet offers deep customization.
  - **Solution**: Conduct user testing to refine the UI, focusing on balancing simplicity and advanced features.
## User/Audience Experience
Users will experience an intuitive platform that allows them to import audio files and easily manipulate them into complex soundscapes. The interface will facilitate creativity in setting up rhythmic patterns, adjusting loop characteristics, and experimenting with evolving textures over time.
## Success Metrics
- User engagement levels and time spent in the app.
- Number of soundscapes created and shared.
- Feedback and ratings in app stores.
- Increase in user base over time.
## Research & References
Placeholder for supporting materials, inspiration sources, technical documentation details.
## Open Questions & Considerations
- How to effectively implement the wander mode without overwhelming the user.
- Potential for integrating AI to suggest loop patterns based on the imported audio file.
## Project Log
### 6 Aug 2025
Project created
## External Files
Placeholder for any files related to the project outside of the project folder and their locations.
## Repositories
Placeholder for local and GitHub repositories related to this project.
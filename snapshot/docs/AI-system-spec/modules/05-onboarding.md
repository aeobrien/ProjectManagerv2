# 2. Onboarding (New Project Creation)

**Entry point:** OnboardingView — presented as a sheet when the user creates a new project from the Focus Board.

**This is the most complex AI flow.** It has multiple stages:

## Stage 1: Brain Dump
The user writes a free-form description of their project idea. They can also provide a repository URL. If coming from a markdown import, the brain dump text is pre-filled with the imported content.

## Stage 2: AI Discovery Conversation (multi-turn, 1–3 exchanges)
The manager sends the brain dump as the first user message. The system prompt tells the AI to:
- Reflect back understanding of the project
- Call out strengths
- Ask 2–3 targeted follow-up questions to fill specific gaps needed for a vision statement (purpose, scope exclusions, definition of done, target user, design principles, mental model, key workflows, ethical centre)
- When it has enough information, propose the project structure using ACTION blocks

The conversation continues for up to 3 exchanges (configurable). On the final exchange, the system prompt forces the AI to stop asking questions and produce the structure.

**Signal convention:** The AI includes CREATE_PHASE, CREATE_MILESTONE, and CREATE_TASK action blocks when it's ready to propose the structure. This triggers the transition to the next stage.

## Stage 3: Structure Proposal
The parsed actions are displayed as a list of proposed phases, milestones, and tasks. The user can toggle items on/off, edit the project name, select a category, and fill in the definition of done. (Category and DoD are NOT auto-filled by the AI — they're manual fields.)

## Stage 4: Create
The accepted items are created in the database. The project is saved with its hierarchy.

## Stage 5: Document Generation (automatic for medium/complex projects)
Two separate single-shot LLM calls:
1. **Vision Statement:** The system prompt is just the behavioural contract. The user message contains the vision statement template (a detailed structural guide for a 200–400 line document) plus the brain dump text, the full conversation transcript, and a summary of the proposed structure.
2. **Technical Brief** (for complex projects only): Continuation of the same conversation, with the technical brief template.

The generated documents are saved to the project.

**What's different about onboarding:** It does NOT use ActionExecutor for the structure creation — it has its own direct repo calls. The actions are only parsed to extract the proposed structure (names of phases/milestones/tasks), not to create real entities. Real entities are created in the "Create" step from the user-approved list.

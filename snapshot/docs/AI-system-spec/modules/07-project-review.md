# 4. Project Review

**Entry point:** ProjectReviewView — accessible from the Focus Board.

**Flow:** Multi-turn (initial review + follow-up questions).

**Important distinction:** This reviews the ENTIRE portfolio of focused projects, not just one. The manager gathers data across ALL focused projects and runs client-side pattern detection:
- **Stalls:** Projects with 7+ days since last check-in
- **Blocked accumulation:** Projects with 3+ blocked tasks
- **Deferral patterns:** 5+ deferred tasks across all projects
- **Waiting accumulation:** 3+ waiting items approaching check-back dates

The AI is given a structured summary of all focused projects' stats plus these detected patterns. It provides analytical commentary and recommendations.

**What's notable:** Despite the system prompt including action block documentation, the ProjectReviewManager **never parses or executes actions** from the AI response. The review is purely advisory/informational. This seems like a gap — the AI is told about actions but its proposals are ignored.

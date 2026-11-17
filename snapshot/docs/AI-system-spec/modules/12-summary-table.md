# Summary: What Uses What

| Feature | Conv. Type | Multi-turn? | Uses ContextAssembler | Uses ActionParser | Executes Actions | Creates Data |
|---------|-----------|-------------|----------------------|-------------------|------------------|-------------|
| Main Chat | varies | Yes | Yes | Yes | Yes (trust levels) | Via ActionExecutor |
| Onboarding Discovery | `.onboarding` | Yes (1–3) | Yes (exchange-aware) | Yes (structure only) | No (direct repo) | Phases/milestones/tasks/docs |
| Onboarding Doc Gen | N/A (direct) | No (1–2 shots) | No | No | No | Documents |
| Check-In | `.checkInQuickLog`/`.checkInFull` | No (single) | Yes | Yes | Yes (via confirmation) | CheckInRecord + actions |
| Project Review | `.review` | Yes | Yes | **No** | **No** | None (advisory) |
| Retrospective | `.retrospective` | Yes | Yes | **No** | **No** | Phase notes |
| Return Briefing | `.reEntry` | No (single) | Yes | No | No | None (display only) |
| Adversarial Review | N/A | Yes | **No** | **No** | **No** | Document updates |
| Vision Discovery | `.visionDiscovery` | Yes (planned) | Yes (exchange-aware) | No | No | Not wired up |

import Foundation
import PMDomain
import PMUtilities

/// Monitors for stale paused sessions and auto-summarises them.
public actor AutoSummarisationService {
    private let repo: SessionRepositoryProtocol
    private let summaryService: SummaryGenerationService
    private let lifecycleManager: SessionLifecycleManager

    public let timeoutInterval: TimeInterval
    public let maxRetries: Int
    public let checkInterval: TimeInterval

    private var timerTask: Task<Void, Never>?

    public init(
        repo: SessionRepositoryProtocol,
        summaryService: SummaryGenerationService,
        lifecycleManager: SessionLifecycleManager,
        timeoutInterval: TimeInterval = 24 * 60 * 60,
        maxRetries: Int = 3,
        checkInterval: TimeInterval = 15 * 60
    ) {
        self.repo = repo
        self.summaryService = summaryService
        self.lifecycleManager = lifecycleManager
        self.timeoutInterval = timeoutInterval
        self.maxRetries = maxRetries
        self.checkInterval = checkInterval
    }

    /// Starts the background monitoring loop.
    public func start() {
        guard timerTask == nil else { return }
        timerTask = Task { [weak self] in
            // Run immediately on start
            await self?.processPendingSessions()

            while !Task.isCancelled {
                guard let self = self else { return }
                try? await Task.sleep(nanoseconds: UInt64(self.checkInterval * 1_000_000_000))
                if Task.isCancelled { break }
                await self.processPendingSessions()
            }
        }
        Log.ai.info("AutoSummarisationService started (interval: \(self.checkInterval)s, timeout: \(self.timeoutInterval)s)")
    }

    /// Stops the background monitoring loop.
    public func stop() {
        timerTask?.cancel()
        timerTask = nil
        Log.ai.info("AutoSummarisationService stopped")
    }

    /// Finds and processes all sessions eligible for auto-summarisation.
    public func processPendingSessions() async {
        do {
            // Find paused sessions past timeout
            let cutoff = Date().addingTimeInterval(-timeoutInterval)
            let stale = try await repo.fetchSessionsPendingSummarisation(olderThan: cutoff)

            // Also find sessions already marked pendingAutoSummary (from prior failures)
            let pending = try await repo.fetchSessionsWithStatus(.pendingAutoSummary)

            let allToProcess = stale + pending
            guard !allToProcess.isEmpty else { return }

            Log.ai.info("Auto-summarisation: processing \(allToProcess.count) sessions")

            for session in allToProcess {
                await summariseWithRetry(session)
            }
        } catch {
            Log.ai.error("Auto-summarisation scan failed: \(error.localizedDescription)")
        }
    }

    /// Attempts to summarise a session with retries and exponential backoff.
    private func summariseWithRetry(_ session: Session) async {
        for attempt in 0..<maxRetries {
            do {
                // Generate summary first — if this fails, session state stays unchanged
                _ = try await summaryService.generateSummary(
                    for: session.id,
                    completionStatus: .incompleteAutoSummarised
                )

                // Summary succeeded — now transition to terminal state
                _ = try await lifecycleManager.transitionSession(session.id, to: .autoSummarised)

                Log.ai.info("Auto-summarised session \(session.id) on attempt \(attempt + 1)")
                return
            } catch {
                Log.ai.error("Auto-summarisation attempt \(attempt + 1)/\(self.maxRetries) failed for session \(session.id): \(error.localizedDescription)")

                if attempt < maxRetries - 1 {
                    let delay = UInt64(pow(2.0, Double(attempt + 1))) * 1_000_000_000
                    try? await Task.sleep(nanoseconds: delay)
                }
            }
        }

        // All retries exhausted — mark as pendingAutoSummary for next cycle
        Log.ai.error("Auto-summarisation exhausted all \(self.maxRetries) retries for session \(session.id), marking pendingAutoSummary")
        do {
            _ = try await lifecycleManager.transitionSession(session.id, to: .pendingAutoSummary)
        } catch {
            Log.ai.error("Failed to mark session \(session.id) as pendingAutoSummary: \(error.localizedDescription)")
        }
    }
}

import Foundation
import Network

/// Observable wrapper around NWPathMonitor for tracking network connectivity.
@Observable
public final class NetworkMonitor: @unchecked Sendable {
    /// Whether the device currently has a network connection.
    public private(set) var isConnected: Bool = true

    /// Called when connectivity is restored after being offline.
    public var onReconnect: (@Sendable () -> Void)?

    private let monitor: NWPathMonitor
    private let queue: DispatchQueue

    public init() {
        self.monitor = NWPathMonitor()
        self.queue = DispatchQueue(label: "com.projectmanager.app.networkmonitor")
    }

    /// Start monitoring network status.
    public func start() {
        monitor.pathUpdateHandler = { [weak self] path in
            guard let self else { return }
            let wasConnected = self.isConnected
            let nowConnected = path.status == .satisfied

            self.isConnected = nowConnected

            if !wasConnected && nowConnected {
                Log.sync.info("Network reconnected")
                self.onReconnect?()
            } else if wasConnected && !nowConnected {
                Log.sync.info("Network disconnected")
            }
        }
        monitor.start(queue: queue)
        Log.sync.info("NetworkMonitor started")
    }

    /// Stop monitoring.
    public func stop() {
        monitor.cancel()
        Log.sync.info("NetworkMonitor stopped")
    }
}

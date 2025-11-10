//
//  NetworkMonitor.swift
//  Molten
//
//  Created by Assistant on 11/9/25.
//  Network connectivity monitoring
//

import Foundation
import Network

/// Protocol for network connectivity monitoring
@MainActor
protocol NetworkMonitorProtocol {
    /// Check if device has network connectivity
    func checkConnection() -> Bool

    /// Check if current connection is expensive (cellular, hotspot, etc.)
    func checkIsExpensive() -> Bool
}

/// Default implementation using NWPathMonitor
@MainActor
final class NetworkMonitor: NetworkMonitorProtocol {
    private let monitor: NWPathMonitor
    private let queue: DispatchQueue
    private var currentPath: NWPath?

    init() {
        self.monitor = NWPathMonitor()
        self.queue = DispatchQueue(label: "com.molten.networkmonitor")

        monitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor in
                self?.currentPath = path
            }
        }
        monitor.start(queue: queue)
    }

    deinit {
        monitor.cancel()
    }

    func checkConnection() -> Bool {
        guard let path = currentPath else {
            // If we don't have a path yet, check synchronously
            let path = monitor.currentPath
            return path.status == .satisfied
        }
        return path.status == .satisfied
    }

    func checkIsExpensive() -> Bool {
        guard let path = currentPath else {
            // If we don't have a path yet, check synchronously
            let path = monitor.currentPath
            return path.isExpensive
        }
        return path.isExpensive
    }
}

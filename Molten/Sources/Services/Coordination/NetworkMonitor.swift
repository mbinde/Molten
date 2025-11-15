//
//  NetworkMonitor.swift
//  Molten
//
//  Created by Assistant on 11/8/25.
//  Monitors network connectivity and type
//

import Foundation
import Network
import Combine

/// Protocol for network monitoring (for dependency injection)
@MainActor
protocol NetworkMonitorProtocol: ObservableObject {
    var isConnected: Bool { get }
    var isOnWiFi: Bool { get }
    var isExpensive: Bool { get }
    var isConstrained: Bool { get }
    var connectionDescription: String { get }
    func canDownloadCatalog() -> Bool
}

/// Monitors network connectivity and type
@MainActor
class NetworkMonitor: NetworkMonitorProtocol {

    static let shared = NetworkMonitor()

    // MARK: - Properties

    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "com.molten.networkmonitor")

    @Published private(set) var isConnected: Bool = false
    @Published private(set) var isOnWiFi: Bool = false
    @Published private(set) var connectionType: NWInterface.InterfaceType?
    @Published private(set) var isExpensive: Bool = false
    @Published private(set) var isConstrained: Bool = false

    // MARK: - Initialization

    private init() {
        monitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor in
                self?.updateConnectionState(path)
            }
        }
        monitor.start(queue: queue)

        // Get initial path state synchronously to avoid race condition
        // where app checks isConnected before first update arrives
        // Safe to call directly since NetworkMonitor is @MainActor
        updateConnectionState(monitor.currentPath)
    }

    deinit {
        monitor.cancel()
    }

    // MARK: - Private Methods

    private func updateConnectionState(_ path: NWPath) {
        isConnected = path.status == .satisfied
        isOnWiFi = path.usesInterfaceType(.wifi)
        isExpensive = path.isExpensive
        isConstrained = path.isConstrained

        // Determine connection type
        if path.usesInterfaceType(.wifi) {
            connectionType = .wifi
        } else if path.usesInterfaceType(.cellular) {
            connectionType = .cellular
        } else if path.usesInterfaceType(.wiredEthernet) {
            connectionType = .wiredEthernet
        } else {
            connectionType = nil
        }
    }

    // MARK: - Public API

    /// Check if catalog download is allowed based on current network and user preferences
    func canDownloadCatalog() -> Bool {
        guard isConnected else {
            return false
        }

        let policy = CatalogUpdatePreferences.shared.downloadPolicy
        return policy.allowsDownload(isOnWiFi: isOnWiFi)
    }

    /// Get human-readable connection description
    var connectionDescription: String {
        guard isConnected else {
            return "No connection"
        }

        switch connectionType {
        case .wifi:
            return "WiFi"
        case .cellular:
            if isExpensive {
                return "Cellular (expensive)"
            }
            return "Cellular"
        case .wiredEthernet:
            return "Ethernet"
        default:
            return "Connected"
        }
    }
}

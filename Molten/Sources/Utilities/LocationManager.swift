//
//  LocationManager.swift
//  Molten
//
//  Extracted from StoreListView for reusability
//  Manages Core Location services for user location tracking
//

import SwiftUI
import CoreLocation
import Combine

/// Manages user location tracking and authorization
///
/// Wraps CLLocationManager to provide SwiftUI-friendly location services:
/// - Request location permissions
/// - Track user's current location
/// - Monitor authorization status changes
@MainActor
class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published var location: CLLocation?
    @Published var isAuthorized = false

    private let manager = CLLocationManager()

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyKilometer

        // Check initial authorization status
        updateAuthorizationStatus(manager.authorizationStatus)
    }

    func requestPermission() {
        manager.requestWhenInUseAuthorization()
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        Task { @MainActor in
            updateAuthorizationStatus(status)
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        let lastLocation = locations.last
        Task { @MainActor in
            location = lastLocation
        }
    }

    private func updateAuthorizationStatus(_ status: CLAuthorizationStatus) {
        switch status {
        case .authorizedWhenInUse, .authorizedAlways:
            isAuthorized = true
            manager.startUpdatingLocation()
        case .denied, .restricted:
            isAuthorized = false
            manager.stopUpdatingLocation()
        case .notDetermined:
            isAuthorized = false
        @unknown default:
            isAuthorized = false
        }
    }
}

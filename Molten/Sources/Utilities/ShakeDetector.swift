//
//  ShakeDetector.swift
//  Molten
//
//  Detects device shake gesture for bug reporting
//

#if os(iOS)
import UIKit
import SwiftUI

/// Notification posted when device shake is detected
extension Notification.Name {
    static let deviceShaken = Notification.Name("DeviceShaken")
}

/// UIWindow subclass that detects shake gestures
class ShakeDetectorWindow: UIWindow {
    override func motionEnded(_ motion: UIEvent.EventSubtype, with event: UIEvent?) {
        super.motionEnded(motion, with: event)

        if motion == .motionShake {
            NotificationCenter.default.post(name: .deviceShaken, object: nil)
        }
    }
}

/// View modifier that listens for shake gestures
struct ShakeDetectionModifier: ViewModifier {
    let onShake: () -> Void

    func body(content: Content) -> some View {
        content
            .onReceive(NotificationCenter.default.publisher(for: .deviceShaken)) { _ in
                onShake()
            }
    }
}

extension View {
    /// Enables shake gesture detection
    /// - Parameter action: Action to perform when device is shaken
    func onShake(perform action: @escaping () -> Void) -> some View {
        modifier(ShakeDetectionModifier(onShake: action))
    }
}
#endif

import Foundation
#if canImport(UIKit)
import UIKit
#endif

/// Legacy haptics manager - use HapticService.shared instead
/// This class now wraps HapticService for backward compatibility
@available(*, deprecated, message: "Use HapticService.shared instead")
class HapticsManager {
    
    init() {
        // Deprecated: Use HapticService.shared instead
        print("⚠️ HapticsManager is deprecated. Use HapticService.shared instead.")
    }
    
    // MARK: - Private Methods
    
    private func isHapticsSupportedDevice() -> Bool {
        // Delegate to HapticService
        return true // HapticService handles platform detection internally
    }
    
    // MARK: - Public Methods (Compatibility Layer)
    
    func playImpact(style: ImpactStyle = .medium) {
        // Convert to HapticService style and delegate
        let hapticStyle = ImpactFeedbackStyle.from(legacyStyle: style)
        HapticService.shared.impact(hapticStyle)
    }
    
    func playSelection() {
        HapticService.shared.selection()
    }
    
    func playNotification(type: NotificationType) {
        // Convert to HapticService type and delegate
        let hapticType = NotificationFeedbackType.from(legacyType: type)
        HapticService.shared.notification(hapticType)
    }
    
    // MARK: - Helper Methods
    
    var isHapticsAvailable: Bool {
        #if canImport(UIKit)
        return UIDevice.current.userInterfaceIdiom == .phone
        #else
        return false
        #endif
    }
    
    static var shared: HapticsManager = {
        return HapticsManager()
    }()
}

// MARK: - Custom Enums for Cross-Platform Support

enum ImpactStyle {
    case light
    case medium
    case heavy
    case soft
    case rigid
}

enum NotificationType {
    case success
    case warning
    case error
}
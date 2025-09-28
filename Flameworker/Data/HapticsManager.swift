import Foundation
#if canImport(UIKit)
import UIKit
#endif

class HapticsManager {
    #if canImport(UIKit)
    private var impactFeedback: UIImpactFeedbackGenerator?
    private var selectionFeedback: UISelectionFeedbackGenerator?
    private var notificationFeedback: UINotificationFeedbackGenerator?
    #endif
    
    init() {
        #if canImport(UIKit)
        // Only initialize haptics on supported devices
        guard isHapticsSupportedDevice() else { return }
        
        if #available(iOS 10.0, *) {
            self.impactFeedback = UIImpactFeedbackGenerator(style: .medium)
            self.selectionFeedback = UISelectionFeedbackGenerator()
            self.notificationFeedback = UINotificationFeedbackGenerator()
            
            // Prepare the generators for better performance
            self.impactFeedback?.prepare()
            self.selectionFeedback?.prepare()
            self.notificationFeedback?.prepare()
        }
        #endif
    }
    
    // MARK: - Private Methods
    
    private func isHapticsSupportedDevice() -> Bool {
        #if canImport(UIKit)
        // Check device type - haptics are not supported on Mac
        guard UIDevice.current.userInterfaceIdiom != .mac else { return false }
        
        // Check iOS version
        guard #available(iOS 10.0, *) else { return false }
        
        // Check if running on simulator (optional - simulators don't have haptics)
        #if targetEnvironment(simulator)
        return false
        #endif
        
        // Check device model for haptic support
        // iPhones 6s and later support haptics, iPads do not (except iPad Pro with trackpad)
        let deviceType = UIDevice.current.userInterfaceIdiom
        switch deviceType {
        case .phone:
            // Most iPhones from 6s onwards support haptics
            return true
        case .pad:
            // iPads generally don't support haptic feedback except for specific interactions
            return false
        default:
            return false
        }
        #else
        // macOS doesn't support haptic feedback in the same way
        return false
        #endif
    }
    
    // MARK: - Public Methods
    
    func playImpact(style: ImpactStyle = .medium) {
        #if canImport(UIKit)
        guard let impactFeedback = impactFeedback else { return }
        
        let uiStyle: UIImpactFeedbackGenerator.FeedbackStyle
        switch style {
        case .light:
            uiStyle = .light
        case .medium:
            uiStyle = .medium
        case .heavy:
            uiStyle = .heavy
        case .soft:
            if #available(iOS 13.0, *) {
                uiStyle = .soft
            } else {
                uiStyle = .light
            }
        case .rigid:
            if #available(iOS 13.0, *) {
                uiStyle = .rigid
            } else {
                uiStyle = .heavy
            }
        }
        
        // Create new generator with desired style
        let generator = UIImpactFeedbackGenerator(style: uiStyle)
        generator.prepare()
        generator.impactOccurred()
        #endif
    }
    
    func playSelection() {
        #if canImport(UIKit)
        selectionFeedback?.selectionChanged()
        #endif
    }
    
    func playNotification(type: NotificationType) {
        #if canImport(UIKit)
        let uiType: UINotificationFeedbackGenerator.FeedbackType
        switch type {
        case .success:
            uiType = .success
        case .warning:
            uiType = .warning
        case .error:
            uiType = .error
        }
        notificationFeedback?.notificationOccurred(uiType)
        #endif
    }
    
    // MARK: - Helper Methods
    
    var isHapticsAvailable: Bool {
        #if canImport(UIKit)
        return impactFeedback != nil
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
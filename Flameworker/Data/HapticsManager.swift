import UIKit

class HapticsManager {
    private var impactFeedback: UIImpactFeedbackGenerator?
    private var selectionFeedback: UISelectionFeedbackGenerator?
    private var notificationFeedback: UINotificationFeedbackGenerator?
    
    init() {
        // Only initialize haptics on devices that support it
        if UIDevice.current.userInterfaceIdiom != .mac {
            // Check if the device supports haptics
            if #available(iOS 10.0, *) {
                // Additional check for haptic capability
                let hapticCapability = UIDevice.current.value(forKey: "_feedbackSupportLevel") as? Int ?? 0
                
                if hapticCapability > 0 {
                    self.impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                    self.selectionFeedback = UISelectionFeedbackGenerator()
                    self.notificationFeedback = UINotificationFeedbackGenerator()
                    
                    // Prepare the generators for better performance
                    self.impactFeedback?.prepare()
                    self.selectionFeedback?.prepare()
                    self.notificationFeedback?.prepare()
                }
            }
        }
    }
    
    // MARK: - Public Methods
    
    func playImpact(style: UIImpactFeedbackGenerator.FeedbackStyle = .medium) {
        guard let impactFeedback = impactFeedback else { return }
        
        // Update style if needed
        if impactFeedback.style != style {
            self.impactFeedback = UIImpactFeedbackGenerator(style: style)
            self.impactFeedback?.prepare()
        }
        
        impactFeedback.impactOccurred()
    }
    
    func playSelection() {
        selectionFeedback?.selectionChanged()
    }
    
    func playNotification(type: UINotificationFeedbackGenerator.FeedbackType) {
        notificationFeedback?.notificationOccurred(type)
    }
    
    // MARK: - Helper Methods
    
    var isHapticsAvailable: Bool {
        return impactFeedback != nil
    }
    
    static var shared: HapticsManager = {
        return HapticsManager()
    }()
}

// MARK: - UIImpactFeedbackGenerator Extension
extension UIImpactFeedbackGenerator {
    var style: FeedbackStyle {
        // This is a workaround since style is not directly accessible
        // In practice, you might want to track this separately
        return .medium
    }
}
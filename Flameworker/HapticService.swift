//
//  HapticService.swift
//  Flameworker
//
//  Created by Assistant on 9/28/25.
//

import UIKit
import CoreHaptics
import SwiftUI

/// Service for managing haptic feedback patterns loaded from HapticPatternLibrary.plist
class HapticService {
    static let shared = HapticService()
    
    private var hapticEngine: CHHapticEngine?
    private var patternLibrary: [String: HapticPattern] = [:]
    
    private init() {
        setupHapticEngine()
        loadPatternLibrary()
    }
    
    // MARK: - Haptic Engine Setup
    
    private func setupHapticEngine() {
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else {
            print("⚠️ Device doesn't support haptics")
            return
        }
        
        do {
            hapticEngine = try CHHapticEngine()
            try hapticEngine?.start()
            
            // Handle engine reset
            hapticEngine?.resetHandler = { [weak self] in
                print("🔄 Haptic engine reset")
                do {
                    try self?.hapticEngine?.start()
                } catch {
                    print("❌ Failed to restart haptic engine: \(error)")
                }
            }
            
            // Handle engine stop
            hapticEngine?.stoppedHandler = { reason in
                print("⏹️ Haptic engine stopped: \(reason)")
            }
            
        } catch {
            print("❌ Failed to initialize haptic engine: \(error)")
        }
    }
    
    // MARK: - Pattern Library Loading
    
    private func loadPatternLibrary() {
        guard let url = Bundle.main.url(forResource: "HapticPatternLibrary", withExtension: "plist"),
              let data = try? Data(contentsOf: url),
              let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any],
              let patterns = plist["HapticPatterns"] as? [String: [String: Any]] else {
            print("❌ Failed to load HapticPatternLibrary.plist")
            return
        }
        
        for (name, patternData) in patterns {
            if let pattern = parseHapticPattern(from: patternData) {
                patternLibrary[name] = pattern
                print("✅ Loaded haptic pattern: \(name)")
            } else {
                print("⚠️ Failed to parse haptic pattern: \(name)")
            }
        }
        
        print("📚 Loaded \(patternLibrary.count) haptic patterns")
    }
    
    private func parseHapticPattern(from data: [String: Any]) -> HapticPattern? {
        guard let type = data["type"] as? String else { return nil }
        
        let description = data["description"] as? String ?? ""
        
        switch type {
        case "impact":
            guard let styleString = data["style"] as? String else { return nil }
            let style = UIImpactFeedbackGenerator.FeedbackStyle.from(string: styleString)
            return .impact(style: style, description: description)
            
        case "notification":
            guard let styleString = data["style"] as? String else { return nil }
            let style = UINotificationFeedbackGenerator.FeedbackType.from(string: styleString)
            return .notification(type: style, description: description)
            
        case "selection":
            return .selection(description: description)
            
        case "custom":
            guard let patternArray = data["pattern"] as? [[String: Any]] else { return nil }
            let events = patternArray.compactMap { eventData -> CHHapticEvent? in
                guard let eventType = eventData["eventType"] as? String,
                      let intensity = eventData["intensity"] as? Double,
                      let delay = eventData["delay"] as? Double else {
                    return nil
                }
                
                let hapticEventType: CHHapticEvent.EventType
                switch eventType {
                case "impact":
                    hapticEventType = .hapticTransient
                default:
                    hapticEventType = .hapticTransient
                }
                
                let intensityParameter = CHHapticEventParameter(parameterID: .hapticIntensity, value: Float(intensity))
                let sharpnessParameter = CHHapticEventParameter(parameterID: .hapticSharpness, value: 1.0)
                
                return CHHapticEvent(eventType: hapticEventType,
                                   parameters: [intensityParameter, sharpnessParameter],
                                   relativeTime: delay)
            }
            return .custom(events: events, description: description)
            
        default:
            return nil
        }
    }
    
    // MARK: - Public Interface
    
    /// Play a haptic pattern by name from the pattern library
    func playPattern(named patternName: String) {
        guard let pattern = patternLibrary[patternName] else {
            print("⚠️ Haptic pattern '\(patternName)' not found")
            return
        }
        
        executePattern(pattern)
    }
    
    /// Play a simple impact feedback
    func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle = .medium) {
        let generator = UIImpactFeedbackGenerator(style: style)
        generator.impactOccurred()
    }
    
    /// Play a notification feedback
    func notification(_ type: UINotificationFeedbackGenerator.FeedbackType) {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(type)
    }
    
    /// Play selection feedback
    func selection() {
        let generator = UISelectionFeedbackGenerator()
        generator.selectionChanged()
    }
    
    // MARK: - Private Execution
    
    private func executePattern(_ pattern: HapticPattern) {
        switch pattern {
        case .impact(let style, _):
            impact(style)
            
        case .notification(let type, _):
            notification(type)
            
        case .selection(_):
            selection()
            
        case .custom(let events, _):
            playCustomPattern(events: events)
        }
    }
    
    private func playCustomPattern(events: [CHHapticEvent]) {
        guard let hapticEngine = hapticEngine else {
            print("⚠️ Haptic engine not available")
            return
        }
        
        do {
            let pattern = try CHHapticPattern(events: events, parameters: [])
            let player = try hapticEngine.makePlayer(with: pattern)
            try player.start(atTime: 0)
        } catch {
            print("❌ Failed to play custom haptic pattern: \(error)")
        }
    }
    
    // MARK: - Available Patterns
    
    /// Get all available pattern names
    var availablePatterns: [String] {
        return Array(patternLibrary.keys).sorted()
    }
    
    /// Get pattern description
    func description(for patternName: String) -> String? {
        return patternLibrary[patternName]?.description
    }
}

// MARK: - Supporting Types

enum HapticPattern {
    case impact(style: UIImpactFeedbackGenerator.FeedbackStyle, description: String)
    case notification(type: UINotificationFeedbackGenerator.FeedbackType, description: String)
    case selection(description: String)
    case custom(events: [CHHapticEvent], description: String)
    
    var description: String {
        switch self {
        case .impact(_, let desc),
             .notification(_, let desc),
             .selection(let desc),
             .custom(_, let desc):
            return desc
        }
    }
}

// MARK: - Extensions

extension UIImpactFeedbackGenerator.FeedbackStyle {
    static func from(string: String) -> UIImpactFeedbackGenerator.FeedbackStyle {
        switch string.lowercased() {
        case "light": return .light
        case "medium": return .medium
        case "heavy": return .heavy
        case "soft": 
            if #available(iOS 13.0, *) {
                return .soft
            } else {
                return .light
            }
        case "rigid":
            if #available(iOS 13.0, *) {
                return .rigid
            } else {
                return .heavy
            }
        default: return .medium
        }
    }
}

extension UINotificationFeedbackGenerator.FeedbackType {
    static func from(string: String) -> UINotificationFeedbackGenerator.FeedbackType {
        switch string.lowercased() {
        case "success": return .success
        case "warning": return .warning
        case "error": return .error
        default: return .warning
        }
    }
}

// MARK: - SwiftUI Integration

/// View modifier to add haptic feedback to any SwiftUI view
struct HapticFeedback: ViewModifier {
    let patternName: String
    let trigger: Bool
    
    func body(content: Content) -> some View {
        content
            .onChange(of: trigger) { newValue in
                if newValue {
                    HapticService.shared.playPattern(named: patternName)
                }
            }
    }
}

extension View {
    /// Add haptic feedback that triggers when the boolean changes to true
    func hapticFeedback(pattern: String, trigger: Bool) -> some View {
        modifier(HapticFeedback(patternName: pattern, trigger: trigger))
    }
    
    /// Add a simple tap gesture with haptic feedback
    func onTapWithHaptic(pattern: String = "lightTap", perform action: @escaping () -> Void) -> some View {
        self.onTapGesture {
            HapticService.shared.playPattern(named: pattern)
            action()
        }
    }
}
//
//  HapticService.swift
//  Flameworker
//
//  Created by Assistant on 9/28/25.
//

import Foundation
import SwiftUI
import OSLog
#if canImport(UIKit)
import UIKit
#endif
#if canImport(CoreHaptics)
import CoreHaptics
#endif

#if canImport(CoreHaptics)
/// Strongly-typed alias for custom haptic events when CoreHaptics is available
public typealias CustomHapticEvent = CHHapticEvent
#else
/// Fallback placeholder when CoreHaptics isn't available
public struct CustomHapticEvent {}
#endif

/// Service for managing haptic feedback patterns loaded from HapticPatternLibrary.plist
class HapticService {
    static let shared = HapticService()
    
    #if canImport(CoreHaptics)
    private var hapticEngine: CHHapticEngine?
    #endif
    private var patternLibrary: [String: HapticPattern] = [:]
    private let log = Logger.haptics
    
    private init() {
        setupHapticEngine()
        loadPatternLibrary()
    }
    
    // MARK: - Haptic Engine Setup
    
    private func setupHapticEngine() {
        #if canImport(CoreHaptics) && canImport(UIKit)
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else {
            log.warning("Device doesn't support haptics")
            return
        }
        
        do {
            hapticEngine = try CHHapticEngine()
            try hapticEngine?.start()
            log.info("Haptic engine started")
            
            // Handle engine reset
            hapticEngine?.resetHandler = { [weak self] in
                self?.log.info("Haptic engine reset")
                do {
                    try self?.hapticEngine?.start()
                } catch {
                    self?.log.error("Failed to restart haptic engine: \(String(describing: error))")
                }
            }
            
            // Handle engine stop
            hapticEngine?.stoppedHandler = { [weak self] reason in
                self?.log.warning("Haptic engine stopped: \(String(describing: reason))")
            }
            
        } catch {
            log.error("Failed to initialize haptic engine: \(String(describing: error))")
        }
        #else
        log.warning("Haptics not supported on this platform")
        #endif
    }
    
    // MARK: - Pattern Library Loading
    
    private func loadPatternLibrary() {
        guard let url = Bundle.main.url(forResource: "HapticPatternLibrary", withExtension: "plist"),
              let data = try? Data(contentsOf: url),
              let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any],
              let patterns = plist["HapticPatterns"] as? [String: [String: Any]] else {
            log.error("Failed to load HapticPatternLibrary.plist")
            return
        }
        
        for (name, patternData) in patterns {
            if let pattern = parseHapticPattern(from: patternData) {
                self.patternLibrary[name] = pattern
                log.debug("Loaded haptic pattern: \(name)")
            } else {
                log.warning("Failed to parse haptic pattern: \(name)")
            }
        }
        
        log.info("Loaded \(self.patternLibrary.count) haptic patterns")
    }
    
    private func parseHapticPattern(from data: [String: Any]) -> HapticPattern? {
        guard let type = data["type"] as? String else { return nil }
        
        let description = data["description"] as? String ?? ""
        
        #if canImport(UIKit)
        switch type {
        case "impact":
            guard let styleString = data["style"] as? String else { return nil }
            let style = ImpactFeedbackStyle.from(string: styleString)
            return .impact(style: style, description: description)
            
        case "notification":
            guard let styleString = data["style"] as? String else { return nil }
            let style = NotificationFeedbackType.from(string: styleString)
            return .notification(type: style, description: description)
            
        case "selection":
            return .selection(description: description)
            
        case "custom":
            #if canImport(CoreHaptics)
            guard let patternArray = data["pattern"] as? [[String: Any]] else { return nil }
            let events = patternArray.compactMap { eventData -> CustomHapticEvent? in
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
            #else
            return nil
            #endif
            
        default:
            return nil
        }
        #else
        // On non-iOS platforms, return nil for all patterns
        return nil
        #endif
    }
    
    // MARK: - Public Interface
    
    /// Play a haptic pattern by name from the pattern library
    func playPattern(named patternName: String) {
        guard let pattern = self.patternLibrary[patternName] else {
            log.warning("Haptic pattern '\(patternName)' not found")
            return
        }
        
        executePattern(pattern)
    }
    
    /// Play a simple impact feedback
    func impact(_ style: ImpactFeedbackStyle = .medium) {
        #if canImport(UIKit)
        let uiStyle = style.toUIKit()
        let generator = UIImpactFeedbackGenerator(style: uiStyle)
        generator.impactOccurred()
        #endif
    }
    
    /// Play a notification feedback
    func notification(_ type: NotificationFeedbackType) {
        #if canImport(UIKit)
        let uiType = type.toUIKit()
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(uiType)
        #endif
    }
    
    /// Play selection feedback
    func selection() {
        #if canImport(UIKit)
        let generator = UISelectionFeedbackGenerator()
        generator.selectionChanged()
        #endif
    }
    
    // MARK: - Private Execution
    
    private func executePattern(_ pattern: HapticPattern) {
        #if canImport(UIKit)
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
        #endif
    }
    
    private func playCustomPattern(events: [CustomHapticEvent]) {
        #if canImport(CoreHaptics)
        guard let hapticEngine = hapticEngine else {
            log.warning("Haptic engine not available")
            return
        }
        
        let hapticEvents = events
        
        do {
            let pattern = try CHHapticPattern(events: hapticEvents, parameters: [])
            let player = try hapticEngine.makePlayer(with: pattern)
            try player.start(atTime: 0)
        } catch {
            log.error("Failed to play custom haptic pattern: \(String(describing: error))")
        }
        #endif
    }
    
    // MARK: - Available Patterns
    
    /// Get all available pattern names
    var availablePatterns: [String] {
        return Array(self.patternLibrary.keys).sorted()
    }
    
    /// Get pattern description
    func description(for patternName: String) -> String? {
        return self.patternLibrary[patternName]?.description
    }
}

// MARK: - Supporting Types

enum HapticPattern {
    case impact(style: ImpactFeedbackStyle, description: String)
    case notification(type: NotificationFeedbackType, description: String)
    case selection(description: String)
    case custom(events: [CustomHapticEvent], description: String)
    
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

// Cross-platform feedback styles
enum ImpactFeedbackStyle {
    case light
    case medium
    case heavy
    case soft
    case rigid
    
    #if canImport(UIKit)
    func toUIKit() -> UIImpactFeedbackGenerator.FeedbackStyle {
        switch self {
        case .light: return .light
        case .medium: return .medium
        case .heavy: return .heavy
        case .soft:
            if #available(iOS 13.0, *) {
                return .soft
            } else {
                return .light
            }
        case .rigid:
            if #available(iOS 13.0, *) {
                return .rigid
            } else {
                return .heavy
            }
        }
    }
    #endif
    
    static func from(string: String) -> ImpactFeedbackStyle {
        switch string.lowercased() {
        case "light": return .light
        case "medium": return .medium
        case "heavy": return .heavy
        case "soft": return .soft
        case "rigid": return .rigid
        default: return .medium
        }
    }
}

enum NotificationFeedbackType {
    case success
    case warning
    case error
    
    #if canImport(UIKit)
    func toUIKit() -> UINotificationFeedbackGenerator.FeedbackType {
        switch self {
        case .success: return .success
        case .warning: return .warning
        case .error: return .error
        }
    }
    #endif
    
    static func from(string: String) -> NotificationFeedbackType {
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


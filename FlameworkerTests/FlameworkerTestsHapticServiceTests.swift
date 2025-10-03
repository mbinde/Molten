//
//  HapticServiceTests.swift
//  FlameworkerTests
//
//  Created by Assistant on 10/3/25.
//

import Testing
@testable import Flameworker

@Suite("HapticService Tests")
struct HapticServiceTests {
    
    // MARK: - Singleton Tests
    
    @Test("HapticService shared instance is singleton")
    func hapticServiceIsSingleton() {
        let instance1 = HapticService.shared
        let instance2 = HapticService.shared
        
        #expect(instance1 === instance2)
    }
    
    // MARK: - Pattern Library Tests
    
    @Test("Available patterns returns sorted array")
    func availablePatternsIsSorted() {
        let patterns = HapticService.shared.availablePatterns
        let sortedPatterns = patterns.sorted()
        
        #expect(patterns == sortedPatterns)
    }
    
    @Test("Pattern description for unknown pattern returns nil")
    func unknownPatternReturnsNil() {
        let description = HapticService.shared.description(for: "nonexistent_pattern")
        
        #expect(description == nil)
    }
    
    // MARK: - Cross-Platform Style Tests
    
    @Test("ImpactFeedbackStyle from string conversion")
    func impactStyleFromString() {
        #expect(ImpactFeedbackStyle.from(string: "light") == .light)
        #expect(ImpactFeedbackStyle.from(string: "medium") == .medium)
        #expect(ImpactFeedbackStyle.from(string: "heavy") == .heavy)
        #expect(ImpactFeedbackStyle.from(string: "soft") == .soft)
        #expect(ImpactFeedbackStyle.from(string: "rigid") == .rigid)
        #expect(ImpactFeedbackStyle.from(string: "unknown") == .medium) // default
    }
    
    @Test("NotificationFeedbackType from string conversion")
    func notificationTypeFromString() {
        #expect(NotificationFeedbackType.from(string: "success") == .success)
        #expect(NotificationFeedbackType.from(string: "warning") == .warning)
        #expect(NotificationFeedbackType.from(string: "error") == .error)
        #expect(NotificationFeedbackType.from(string: "unknown") == .warning) // default
    }
    
    // MARK: - HapticPattern Tests
    
    @Test("HapticPattern description extraction")
    func hapticPatternDescription() {
        let impactPattern = HapticPattern.impact(style: .medium, description: "Medium impact")
        let notificationPattern = HapticPattern.notification(type: .success, description: "Success notification")
        let selectionPattern = HapticPattern.selection(description: "Selection feedback")
        let customPattern = HapticPattern.custom(events: [], description: "Custom pattern")
        
        #expect(impactPattern.description == "Medium impact")
        #expect(notificationPattern.description == "Success notification")
        #expect(selectionPattern.description == "Selection feedback")
        #expect(customPattern.description == "Custom pattern")
    }
    
    // MARK: - Legacy Compatibility Tests
    
    @Test("Legacy impact style conversion")
    func legacyImpactStyleConversion() {
        // These tests assume the legacy types exist
        // If they don't exist yet, these tests will guide their implementation
        
        #expect(ImpactFeedbackStyle.from(legacyStyle: .light) == .light)
        #expect(ImpactFeedbackStyle.from(legacyStyle: .medium) == .medium)
        #expect(ImpactFeedbackStyle.from(legacyStyle: .heavy) == .heavy)
        #expect(ImpactFeedbackStyle.from(legacyStyle: .soft) == .soft)
        #expect(ImpactFeedbackStyle.from(legacyStyle: .rigid) == .rigid)
    }
    
    @Test("Legacy notification type conversion")
    func legacyNotificationTypeConversion() {
        #expect(NotificationFeedbackType.from(legacyType: .success) == .success)
        #expect(NotificationFeedbackType.from(legacyType: .warning) == .warning)
        #expect(NotificationFeedbackType.from(legacyType: .error) == .error)
    }
}

// MARK: - Legacy Types for Compatibility Testing

// These enums represent the legacy types that the HapticService needs to support
enum ImpactStyle {
    case light, medium, heavy, soft, rigid
}

enum NotificationType {
    case success, warning, error
}

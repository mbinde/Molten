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
    
    // MARK: - Basic Functionality Tests
    
    @Test("HapticService can play basic feedback without crashing")
    @MainActor
    func hapticServiceBasicFeedback() {
        let service = HapticService.shared
        
        // These should not crash on simulator/test environment
        service.impact(.light)
        service.impact(.medium)
        service.impact(.heavy)
        service.selection()
        service.notification(.success)
        service.notification(.warning)
        service.notification(.error)
        
        // Test passes if no crash occurs
        #expect(true)
    }
    
    @Test("HapticService pattern playback handles unknown patterns gracefully")
    func hapticServiceUnknownPatterns() {
        let service = HapticService.shared
        
        // Should not crash with unknown pattern name
        service.playPattern(named: "nonexistentPattern")
        
        #expect(true, "Should handle unknown patterns gracefully")
    }
    
    // MARK: - SwiftUI Integration Tests
    
    @Test("HapticFeedback view modifier can be created")
    func hapticFeedbackModifierCreation() {
        let modifier = HapticFeedback(patternName: "testPattern", trigger: false)
        
        #expect(modifier.patternName == "testPattern")
        #expect(modifier.trigger == false)
    }
}



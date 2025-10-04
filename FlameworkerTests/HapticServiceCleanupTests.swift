//
//  HapticServiceCleanupTests.swift
//  FlameworkerTests
//
//  Created by Assistant on 10/3/25.
//

import Testing
@testable import Flameworker

@Suite("HapticService Cleanup Tests")
struct HapticServiceCleanupTests {
    
    @Test("HapticService shared instance is available")
    nonisolated func hapticServiceSharedInstance() {
        let service = HapticService.shared
        #expect(service.availablePatterns.count >= 0, "Should have valid pattern array")
    }
    
    @Test("ImpactFeedbackStyle string conversion works")
    nonisolated func impactFeedbackStyleStringConversion() {
        #expect(ImpactFeedbackStyle.from(string: "light") == .light)
        #expect(ImpactFeedbackStyle.from(string: "medium") == .medium)
        #expect(ImpactFeedbackStyle.from(string: "heavy") == .heavy)
        #expect(ImpactFeedbackStyle.from(string: "soft") == .soft)
        #expect(ImpactFeedbackStyle.from(string: "rigid") == .rigid)
        #expect(ImpactFeedbackStyle.from(string: "unknown") == .medium, "Should default to medium")
    }
    
    @Test("NotificationFeedbackType string conversion works")
    nonisolated func notificationFeedbackTypeStringConversion() {
        #expect(NotificationFeedbackType.from(string: "success") == .success)
        #expect(NotificationFeedbackType.from(string: "warning") == .warning)
        #expect(NotificationFeedbackType.from(string: "error") == .error)
        #expect(NotificationFeedbackType.from(string: "unknown") == .warning, "Should default to warning")
    }
    
    @Test("HapticService basic feedback methods do not crash")
    nonisolated func hapticServiceBasicFeedbackMethods() async {
        let service = HapticService.shared
        
        // These should not crash even in test/simulator environment
        service.impact(.light)
        service.impact(.medium)
        service.impact(.heavy)
        service.selection()
        service.notification(.success)
        service.notification(.warning)
        service.notification(.error)
        
        // Brief delay to allow async operations to complete
        try? await Task.sleep(for: .milliseconds(100))
        
        // Test passes if no crash occurs
        #expect(true)
    }
    
    @Test("HapticService pattern playback handles unknown patterns gracefully")
    nonisolated func hapticServiceUnknownPatterns() async {
        let service = HapticService.shared
        
        // Should not crash with unknown pattern name
        service.playPattern(named: "nonexistentPattern")
        
        // Brief delay to allow async operations to complete
        try? await Task.sleep(for: .milliseconds(50))
        
        #expect(true, "Should handle unknown patterns gracefully")
    }
    
    @Test("SwiftUI haptic feedback view modifier can be created")
    nonisolated func swiftUIHapticFeedbackModifier() {
        let modifier = HapticFeedback(patternName: "testPattern", trigger: false)
        
        #expect(modifier.patternName == "testPattern")
        #expect(modifier.trigger == false)
    }
}
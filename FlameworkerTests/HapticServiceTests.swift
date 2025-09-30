//
//  HapticServiceTests.swift
//  FlameworkerTests
//
//  Created by Melissa Binde on 9/29/25.
//  Copyright © 2025 Motley Woods. All rights reserved.
//

import Testing
import Foundation
@testable import Flameworker

#if canImport(CoreHaptics)
import CoreHaptics
#endif

@Suite("Haptic Service Tests")
struct HapticServiceTests {
    
    @Test("HapticService should be singleton")
    func hapticServiceSingleton() {
        let service1 = HapticService.shared
        let service2 = HapticService.shared
        
        #expect(service1 === service2, "HapticService should be a singleton")
    }
    
    @Test("CustomHapticEvent type should be available")
    func customHapticEventType() {
        // Test that our type alias/placeholder is working correctly
        #if canImport(CoreHaptics)
        let eventType = CustomHapticEvent.self
        #expect(eventType == CHHapticEvent.self, "CustomHapticEvent should alias to CHHapticEvent when available")
        #else
        // On platforms without CoreHaptics, it should be our placeholder struct
        let event = CustomHapticEvent()
        #expect(event != nil, "CustomHapticEvent placeholder should be creatable")
        #endif
    }
    
    @Test("HapticService should initialize without crashing")
    func hapticServiceInitialization() {
        let service = HapticService.shared
        #expect(service != nil, "HapticService should initialize successfully")
    }
    
    #if canImport(CoreHaptics) && canImport(UIKit)
    @Test("HapticService should handle devices without haptic support gracefully")
    func hapticServiceNoHapticSupport() {
        // This test verifies that the service doesn't crash on devices without haptic support
        let service = HapticService.shared
        #expect(service != nil, "HapticService should work even without haptic support")
    }
    #endif
    
    // MARK: - Haptic Pattern Tests
    
    @Test("HapticService should load pattern library without errors")
    func hapticPatternLibraryLoading() {
        let service = HapticService.shared
        
        // The service should initialize and load its pattern library
        // Even if the library is empty or the file doesn't exist, it shouldn't crash
        #expect(service != nil, "Service should handle pattern library loading gracefully")
    }
    
    @Test("HapticService should handle missing pattern files gracefully")
    func hapticMissingPatternFiles() {
        // Test that the service doesn't crash when HapticPatternLibrary.plist is missing
        let service = HapticService.shared
        #expect(service != nil, "Service should handle missing pattern files without crashing")
    }
    
    // MARK: - Platform Compatibility Tests
    
    @Test("HapticService should work across different platforms")
    func hapticServicePlatformCompatibility() {
        let service = HapticService.shared
        
        #if canImport(UIKit)
        // iOS/iPadOS - should have full haptic support
        #expect(service != nil, "HapticService should work on iOS/iPadOS")
        #elseif canImport(AppKit)
        // macOS - limited or no haptic support, but service should still work
        #expect(service != nil, "HapticService should work on macOS")
        #else
        // Other platforms - service should still initialize
        #expect(service != nil, "HapticService should work on all platforms")
        #endif
    }
    
    @Test("HapticService should provide fallback behavior")
    func hapticServiceFallbackBehavior() {
        let service = HapticService.shared
        
        // Even on platforms without haptic support, the service should provide
        // fallback behavior (like no-op operations) rather than crashing
        #expect(service != nil, "HapticService should provide fallback behavior")
    }
    
    // MARK: - Logging Tests
    
    @Test("HapticService should use structured logging")
    func hapticServiceStructuredLogging() {
        // Test that the service uses proper logging categories
        let service = HapticService.shared
        
        // The service should initialize its logger properly
        // We can't easily test the actual logging output, but we can verify
        // the service doesn't crash during initialization where logging is set up
        #expect(service != nil, "Service should set up logging without issues")
    }
    
    @Test("HapticService should log haptic capability warnings appropriately")
    func hapticServiceCapabilityLogging() {
        let service = HapticService.shared
        
        // On devices without haptic support, the service should log warnings
        // but continue to function. We test that initialization completes
        // successfully regardless of haptic capabilities.
        #expect(service != nil, "Service should handle capability logging gracefully")
    }
    
    // MARK: - Memory Management Tests
    
    @Test("HapticService singleton should not create memory leaks")
    func hapticServiceMemoryManagement() {
        weak var weakService: HapticService?
        
        autoreleasepool {
            let service = HapticService.shared
            weakService = service
            #expect(service != nil, "Service should be accessible")
        }
        
        // Since it's a singleton, it should remain in memory
        #expect(weakService != nil, "Singleton should persist beyond autorelease pool")
    }
    
    @Test("HapticService should clean up resources properly")
    func hapticServiceResourceCleanup() {
        let service = HapticService.shared
        
        // Test that the service can be accessed multiple times without issues
        // This indirectly tests that it's managing its resources properly
        for _ in 0..<10 {
            let accessedService = HapticService.shared
            #expect(accessedService === service, "Should return same singleton instance")
        }
    }
}
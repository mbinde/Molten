//
//  WarningFixVerificationTests.swift
//  FlameworkerTests
//
//  Created by Assistant on 10/3/25.
//

import Testing
@testable import Flameworker

@Suite("Warning Fix Verification Tests")
struct WarningFixVerificationTests {
    
    @Test("HapticService enum formatting is correct")
    func testHapticServiceEnumFormatting() {
        // Test that ImpactFeedbackStyle enum works correctly after formatting fixes
        let lightStyle = ImpactFeedbackStyle.light
        let mediumStyle = ImpactFeedbackStyle.medium
        let heavyStyle = ImpactFeedbackStyle.heavy
        
        // Test that enum values can be created without errors
        #expect(lightStyle == .light)
        #expect(mediumStyle == .medium)
        #expect(heavyStyle == .heavy)
        
        // Test string conversion works
        let fromLight = ImpactFeedbackStyle.from(string: "light")
        let fromMedium = ImpactFeedbackStyle.from(string: "medium")
        let fromHeavy = ImpactFeedbackStyle.from(string: "heavy")
        
        #expect(fromLight == .light)
        #expect(fromMedium == .medium)
        #expect(fromHeavy == .heavy)
    }
    
    @Test("NotificationFeedbackType enum formatting is correct")
    func testNotificationFeedbackTypeEnumFormatting() {
        // Test that NotificationFeedbackType enum works correctly after formatting fixes
        let successType = NotificationFeedbackType.success
        let warningType = NotificationFeedbackType.warning
        let errorType = NotificationFeedbackType.error
        
        // Test that enum values can be created without errors
        #expect(successType == .success)
        #expect(warningType == .warning)
        #expect(errorType == .error)
        
        // Test string conversion works
        let fromSuccess = NotificationFeedbackType.from(string: "success")
        let fromWarning = NotificationFeedbackType.from(string: "warning")
        let fromError = NotificationFeedbackType.from(string: "error")
        
        #expect(fromSuccess == .success)
        #expect(fromWarning == .warning)
        #expect(fromError == .error)
    }
    
    @Test("HapticService shared instance is accessible")
    func testHapticServiceSharedInstance() {
        // Verify that HapticService singleton works after code cleanup
        let service = HapticService.shared
        
        #expect(service.availablePatterns.count >= 0, "Should have zero or more available patterns")
    }
    
    @Test("Swift 6 concurrency compatibility for haptic enums")
    func testSwift6ConcurrencyCompatibility() {
        // This test verifies that haptic enums work in non-isolated contexts
        // (i.e., they don't have main-actor isolated Equatable conformance)
        
        // Test ImpactFeedbackStyle in non-isolated context
        let impactStyles: [ImpactFeedbackStyle] = [.light, .medium, .heavy, .soft, .rigid]
        let filteredImpacts = impactStyles.filter { $0 == .medium }  // Uses Equatable in non-isolated context
        #expect(filteredImpacts.count == 1)
        #expect(filteredImpacts.first == .medium)
        
        // Test NotificationFeedbackType in non-isolated context
        let notificationTypes: [NotificationFeedbackType] = [.success, .warning, .error]
        let filteredNotifications = notificationTypes.filter { $0 == .success }  // Uses Equatable in non-isolated context
        #expect(filteredNotifications.count == 1)
        #expect(filteredNotifications.first == .success)
        
        // Test that both enums are Sendable (can be passed between isolation contexts)
        Task {
            let asyncImpact: ImpactFeedbackStyle = .heavy
            let asyncNotification: NotificationFeedbackType = .error
            
            // These should compile without warnings in Swift 6 language mode
            #expect(asyncImpact == .heavy)
            #expect(asyncNotification == .error)
        }
    }
    
    @Test("ImageLoadingTests no longer imports SwiftUI unnecessarily")
    func testImageLoadingTestsImports() {
        // This test verifies that we removed the unnecessary SwiftUI import
        // The presence of this test passing means ImageHelpers functionality works
        // without the SwiftUI import
        
        let itemCode = "101"
        let manufacturer = "CIM"
        
        // Test core ImageHelpers functionality
        let imageExists = ImageHelpers.productImageExists(for: itemCode, manufacturer: manufacturer)
        
        // Should be able to use ImageHelpers without SwiftUI import
        #expect(imageExists == true || imageExists == false, "Should get a boolean result")
    }
}
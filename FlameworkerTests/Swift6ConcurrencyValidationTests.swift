//
//  Swift6ConcurrencyValidationTests.swift
//  FlameworkerTests
//
//  Created by Assistant on 10/3/25.
//

import Testing
@testable import Flameworker

@Suite("Swift 6 Concurrency Validation Tests")
struct Swift6ConcurrencyValidationTests {
    
    // MARK: - Swift 6 Concurrency Guidelines
    // 
    // To ensure proper Swift 6 concurrency compliance:
    // 1. Haptic enums (ImpactFeedbackStyle, NotificationFeedbackType) must be:
    //    - Equatable, Hashable, Sendable for cross-isolation usage
    //    - Have nonisolated static methods (like from(string:))
    //    - Have nonisolated instance methods (like toUIKit())
    // 2. HapticService public methods should be nonisolated and use Task { @MainActor } internally
    // 3. Supporting types like HapticPattern should be Sendable
    // 4. Avoid implicit @MainActor isolation on types that should work across boundaries
    
    @Test("ImpactFeedbackStyle has non-isolated Equatable conformance")
    func testImpactFeedbackStyleEquatableNonIsolated() {
        // This test validates that ImpactFeedbackStyle can be used in non-isolated contexts
        let styles: [ImpactFeedbackStyle] = [.light, .medium, .heavy, .soft, .rigid]
        
        // Filter operation uses Equatable in non-isolated context
        let mediumStyles = styles.filter { $0 == .medium }
        #expect(mediumStyles.count == 1)
        #expect(mediumStyles.first == .medium)
        
        // Array contains uses Equatable in non-isolated context
        #expect(styles.contains(.light))
        #expect(styles.contains(.heavy))
        #expect(!styles.contains(.medium) == false)  // Double negation to test boolean logic
        
        // FirstIndex uses Equatable in non-isolated context
        let lightIndex = styles.firstIndex(of: .light)
        #expect(lightIndex == 0)
        
        // Test comparison operators work in non-isolated context
        let style1: ImpactFeedbackStyle = .medium
        let style2: ImpactFeedbackStyle = .medium
        let style3: ImpactFeedbackStyle = .heavy
        
        #expect(style1 == style2)
        #expect(style1 != style3)
    }
    
    @Test("NotificationFeedbackType has non-isolated Equatable conformance")
    func testNotificationFeedbackTypeEquatableNonIsolated() {
        // This test validates that NotificationFeedbackType can be used in non-isolated contexts
        let types: [NotificationFeedbackType] = [.success, .warning, .error]
        
        // Filter operation uses Equatable in non-isolated context
        let successTypes = types.filter { $0 == .success }
        #expect(successTypes.count == 1)
        #expect(successTypes.first == .success)
        
        // Array contains uses Equatable in non-isolated context
        #expect(types.contains(.success))
        #expect(types.contains(.warning))
        #expect(types.contains(.error))
        
        // FirstIndex uses Equatable in non-isolated context
        let warningIndex = types.firstIndex(of: .warning)
        #expect(warningIndex == 1)
        
        // Test comparison operators work in non-isolated context
        let type1: NotificationFeedbackType = .error
        let type2: NotificationFeedbackType = .error
        let type3: NotificationFeedbackType = .success
        
        #expect(type1 == type2)
        #expect(type1 != type3)
    }
    
    @Test("Haptic enums work in async non-isolated contexts")
    func testHapticEnumsInAsyncContexts() async {
        // Test that enums can be created and compared in async contexts
        let impactStyle: ImpactFeedbackStyle = .heavy
        let notificationType: NotificationFeedbackType = .warning
        
        // These should work without any actor isolation issues
        #expect(impactStyle == .heavy)
        #expect(notificationType == .warning)
        
        // Test enum methods work in async contexts
        let convertedImpact = ImpactFeedbackStyle.from(string: "soft")
        let convertedNotification = NotificationFeedbackType.from(string: "success")
        
        #expect(convertedImpact == .soft)
        #expect(convertedNotification == .success)
    }
    
    @Test("Haptic enums are Sendable across isolation boundaries")
    func testHapticEnumsSendable() async {
        // Test passing enums between different isolation contexts
        let impactStyle: ImpactFeedbackStyle = .rigid
        let notificationType: NotificationFeedbackType = .error
        
        // This creates a new task (potential isolation boundary)
        await withCheckedContinuation { continuation in
            Task {
                // Should be able to use enums from parent context
                let receivedImpact = impactStyle
                let receivedNotification = notificationType
                
                #expect(receivedImpact == .rigid)
                #expect(receivedNotification == .error)
                
                continuation.resume()
            }
        }
    }
    
    @Test("HapticService methods are callable from non-isolated contexts")
    func testHapticServiceNonIsolatedCalls() async {
        let service = HapticService.shared
        
        // These method calls should work without requiring @MainActor context
        service.impact(.light)
        service.notification(.success)
        service.selection()
        service.playPattern(named: "testPattern")
        
        // Brief delay to allow async operations to complete
        try? await Task.sleep(for: .milliseconds(100))
        
        // Test passes if no compilation errors or runtime issues occur
        #expect(true)
    }
    
    @Test("Enum values can be stored in non-isolated data structures")
    func testEnumStorageInNonIsolatedStructures() {
        // Test that enums can be stored in dictionaries, sets, etc. without actor issues
        let impactMap: [String: ImpactFeedbackStyle] = [
            "light": .light,
            "medium": .medium,
            "heavy": .heavy
        ]
        
        let notificationSet: Set<NotificationFeedbackType> = [.success, .warning, .error]
        
        // Dictionary lookup uses Equatable
        #expect(impactMap["medium"] == .medium)
        #expect(impactMap["light"] == .light)
        
        // Set operations use Equatable
        #expect(notificationSet.contains(.success))
        #expect(notificationSet.contains(.warning))
        #expect(notificationSet.count == 3)
    }
    
    @Test("Complex enum operations work in non-isolated contexts")
    func testComplexEnumOperations() {
        // Test more complex operations that rely on Equatable conformance
        let impacts: [ImpactFeedbackStyle] = [.light, .medium, .heavy, .soft, .rigid, .medium, .light]
        let notifications: [NotificationFeedbackType] = [.success, .error, .warning, .success]
        
        // Unique operation relies on Equatable
        let uniqueImpacts = Array(Set(impacts))
        let uniqueNotifications = Array(Set(notifications))
        
        #expect(uniqueImpacts.count == 5)  // All unique styles
        #expect(uniqueNotifications.count == 3)  // All unique notification types
        
        // Partition relies on Equatable
        let (lightStyles, otherStyles) = impacts.partition { $0 == .light }
        #expect(lightStyles.count == 2)  // Two .light entries
        #expect(otherStyles.count == 5)  // Five non-.light entries
        
        // Group by functionality (simulated)
        let groupedImpacts = Dictionary(grouping: impacts) { $0 }
        #expect(groupedImpacts[.light]?.count == 2)
        #expect(groupedImpacts[.medium]?.count == 2)
        #expect(groupedImpacts[.heavy]?.count == 1)
    }
}

// Extension to add partition functionality for testing
extension Array {
    func partition(by predicate: (Element) -> Bool) -> ([Element], [Element]) {
        var matching: [Element] = []
        var nonMatching: [Element] = []
        
        for element in self {
            if predicate(element) {
                matching.append(element)
            } else {
                nonMatching.append(element)
            }
        }
        
        return (matching, nonMatching)
    }
}
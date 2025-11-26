//
//  ImageHelpers_PerformanceTests.swift
//  PerformanceTests
//
//  Moved from ImageHelpersTests.swift
//

// Standard test framework imports pattern - use in all test files
#if canImport(Testing)
import Testing
#else
#if canImport(XCTest)
import XCTest
#endif
#endif

import SwiftUI
import UIKit
import Foundation
@testable import Molten

@Suite("ImageHelpers Performance Tests", .serialized)
@MainActor
struct ImageHelpers_PerformanceTests {

    // MARK: - Performance Tests

    @Test("Should handle multiple image requests efficiently")
    func testMultipleImageRequestPerformance() {
        let testCodes = (1...20).map { "PERF-TEST-\(String(format: "%03d", $0))" }

        let startTime = Date()

        // Load multiple images
        var results: [UIImage?] = []
        for code in testCodes {
            let image = ImageHelpers.loadProductImage(for: code)
            results.append(image)
        }

        let endTime = Date()
        let processingTime = endTime.timeIntervalSince(startTime)

        #expect(results.count == testCodes.count, "Should process all image requests")
        #expect(processingTime < 2.0, "Should handle 20 image requests efficiently (actual: \(processingTime)s)")
    }

    @Test("Should demonstrate cache efficiency with repeated requests")
    func testCacheEfficiencyWithRepeatedRequests() {
        let testCodes = ["CACHE-PERF-001", "CACHE-PERF-002", "CACHE-PERF-003"]

        // First pass - populate cache
        let firstPassStart = Date()
        for code in testCodes {
            _ = ImageHelpers.loadProductImage(for: code)
        }
        let firstPassEnd = Date()
        let firstPassTime = firstPassEnd.timeIntervalSince(firstPassStart)

        // Second pass - should use cache
        let secondPassStart = Date()
        for code in testCodes {
            _ = ImageHelpers.loadProductImage(for: code)
        }
        let secondPassEnd = Date()
        let secondPassTime = secondPassEnd.timeIntervalSince(secondPassStart)

        // Second pass should be much faster due to caching
        #expect(secondPassTime <= firstPassTime, "Cached requests should be faster or equal")
        #expect(secondPassTime < 0.1, "Cached requests should be very fast (actual: \(secondPassTime)s)")
    }
}

//
//  FlameworkerUITests.swift
//  FlameworkerUITests
//
//  Created by Melissa Binde on 10/13/25.
//  Copyright © 2025 Motley Woods. All rights reserved.
//

import XCTest

final class FlameworkerUITests: BaseUITest {

    @MainActor
    func testExample() throws {
        // App is already launched by BaseUITest
        // Use XCTAssert and related functions to verify your tests produce the correct results.
        XCTAssertTrue(app.exists, "App should be running")
    }

    @MainActor
    func testLaunchPerformance() throws {
        // Note: This test creates its own app instance for measurement
        // so it doesn't use BaseUITest's app
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            let testApp = XCUIApplication()
            testApp.launchArguments = [
                "UI-Testing",
                "RESET-DATABASE",
                "USE-TEST-DATA",
                "DISABLE-ANIMATIONS"
            ]
            testApp.launch()
        }
    }
}

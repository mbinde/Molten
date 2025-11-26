//
//  XCUIElement+Helpers.swift
//  MoltenUITests
//
//  Created by Assistant on 10/28/25.
//  Helper extensions for more reliable UI testing
//

import XCTest

extension XCUIElement {
    /// Wait for element to exist and be hittable (visible and interactive)
    /// - Parameter timeout: Maximum time to wait (default: 5 seconds)
    /// - Returns: true if element became hittable, false otherwise
    @discardableResult
    func waitToBeHittable(timeout: TimeInterval = 5) -> Bool {
        let predicate = NSPredicate(format: "exists == true AND hittable == true")
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: self)
        return XCTWaiter().wait(for: [expectation], timeout: timeout) == .completed
    }

    /// Tap element only after it's hittable (combines waiting and tapping)
    /// - Parameter timeout: Maximum time to wait (default: 5 seconds)
    func tapWhenHittable(timeout: TimeInterval = 5) {
        guard waitToBeHittable(timeout: timeout) else {
            XCTFail("Element '\(self.debugDescription)' never became hittable within \(timeout) seconds")
            return
        }
        tap()
    }

    /// Wait for element to exist (but not necessarily be visible/hittable)
    /// - Parameter timeout: Maximum time to wait (default: 5 seconds)
    /// - Returns: true if element exists, false otherwise
    @discardableResult
    func waitToExist(timeout: TimeInterval = 5) -> Bool {
        return waitForExistence(timeout: timeout)
    }

    /// Wait for element to disappear (useful for checking that views dismiss)
    /// - Parameter timeout: Maximum time to wait (default: 5 seconds)
    /// - Returns: true if element disappeared, false otherwise
    @discardableResult
    func waitToDisappear(timeout: TimeInterval = 5) -> Bool {
        let predicate = NSPredicate(format: "exists == false")
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: self)
        return XCTWaiter().wait(for: [expectation], timeout: timeout) == .completed
    }

    /// Type text into element after it becomes hittable
    /// - Parameters:
    ///   - text: Text to type
    ///   - timeout: Maximum time to wait for element (default: 5 seconds)
    func typeTextWhenHittable(_ text: String, timeout: TimeInterval = 5) {
        guard waitToBeHittable(timeout: timeout) else {
            XCTFail("Element '\(self.debugDescription)' never became hittable for text entry")
            return
        }
        tap()  // Focus the field
        typeText(text)
    }

    /// Clear text from element and type new text
    /// - Parameters:
    ///   - text: New text to type
    ///   - timeout: Maximum time to wait for element (default: 5 seconds)
    func clearAndTypeText(_ text: String, timeout: TimeInterval = 5) {
        guard waitToBeHittable(timeout: timeout) else {
            XCTFail("Element '\(self.debugDescription)' never became hittable for text entry")
            return
        }

        tap()

        // Clear existing text by selecting all and deleting
        if let stringValue = value as? String, !stringValue.isEmpty {
            // Move cursor to end
            let deleteString = String(repeating: XCUIKeyboardKey.delete.rawValue, count: stringValue.count)
            typeText(deleteString)
        }

        typeText(text)
    }
}

// MARK: - XCUIApplication Keyboard Helpers

extension XCUIApplication {
    /// Dismiss the keyboard if it's visible
    /// This is more reliable than swipeDown because it targets the navigation bar
    /// - Parameter timeout: How long to wait for keyboard to dismiss (default: 3 seconds)
    /// - Returns: true if keyboard was dismissed or wasn't visible
    @discardableResult
    func dismissKeyboardIfVisible(timeout: TimeInterval = 3) -> Bool {
        let keyboard = keyboards.firstMatch

        // If no keyboard, we're done
        guard keyboard.exists else { return true }

        // Try tapping on navigation bar first (most reliable)
        let navBar = navigationBars.firstMatch
        if navBar.exists {
            navBar.tap()
        } else {
            // Fallback: tap at the top of the screen
            let topCoordinate = coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.1))
            topCoordinate.tap()
        }

        // Wait for keyboard to disappear
        return keyboard.waitToDisappear(timeout: timeout)
    }
}

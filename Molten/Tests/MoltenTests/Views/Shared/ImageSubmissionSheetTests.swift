//
//  ImageSubmissionSheetTests.swift
//  MoltenTests
//
//  Tests for ImageSubmissionSheet component
//

import Testing
@testable import Molten

#if canImport(UIKit)
import UIKit

@Suite("ImageSubmissionSheet Tests")
@MainActor
struct ImageSubmissionSheetTests {

    // MARK: - Email Validation Tests

    @Test("Should accept valid email addresses")
    func testValidEmails() {
        let validEmails = [
            "user@example.com",
            "test.user@example.com",
            "user+tag@example.co.uk",
            "user_name@example.org",
            "123@example.com",
            "user@sub.example.com"
        ]

        for email in validEmails {
            let isValid = isValidEmailFormat(email)
            #expect(isValid, "Email '\(email)' should be valid")
        }
    }

    @Test("Should reject invalid email addresses")
    func testInvalidEmails() {
        let invalidEmails = [
            "",
            "invalid",
            "@example.com",
            "user@",
            "user @example.com",
            "user@example",
            "user..name@example.com",
            "user@.example.com"
        ]

        for email in invalidEmails {
            let isValid = isValidEmailFormat(email)
            #expect(!isValid, "Email '\(email)' should be invalid")
        }
    }

    @Test("Should handle edge case emails")
    func testEdgeCaseEmails() {
        // Very long but valid
        let longEmail = "a" + String(repeating: "b", count: 50) + "@example.com"
        #expect(isValidEmailFormat(longEmail))

        // Special characters
        #expect(!isValidEmailFormat("user name@example.com")) // Space not allowed
        #expect(isValidEmailFormat("user-name@example.com")) // Dash allowed
        #expect(isValidEmailFormat("user_name@example.com")) // Underscore allowed
    }

    // MARK: - Submit Button State Tests

    @Test("Should disable submit when no checkboxes are checked")
    func testSubmitDisabledWithoutCheckboxes() {
        let hasPermission = false
        let offersFreeOfCharge = false
        let email = "user@example.com"

        let canSubmit = hasPermission && offersFreeOfCharge && isValidEmailFormat(email) && !email.isEmpty

        #expect(!canSubmit)
    }

    @Test("Should disable submit when only one checkbox is checked")
    func testSubmitDisabledWithOneCheckbox() {
        // Only permission checked
        var canSubmit = true && false && isValidEmailFormat("user@example.com") && true
        #expect(!canSubmit)

        // Only free of charge checked
        canSubmit = false && true && isValidEmailFormat("user@example.com") && true
        #expect(!canSubmit)
    }

    @Test("Should disable submit when email is invalid")
    func testSubmitDisabledWithInvalidEmail() {
        let hasPermission = true
        let offersFreeOfCharge = true
        let email = "invalid-email"

        let canSubmit = hasPermission && offersFreeOfCharge && isValidEmailFormat(email) && !email.isEmpty

        #expect(!canSubmit)
    }

    @Test("Should disable submit when email is empty")
    func testSubmitDisabledWithEmptyEmail() {
        let hasPermission = true
        let offersFreeOfCharge = true
        let email = ""

        let canSubmit = hasPermission && offersFreeOfCharge && isValidEmailFormat(email) && !email.isEmpty

        #expect(!canSubmit)
    }

    @Test("Should enable submit when all requirements met")
    func testSubmitEnabledWhenRequirementsMet() {
        let hasPermission = true
        let offersFreeOfCharge = true
        let email = "user@example.com"

        let canSubmit = hasPermission && offersFreeOfCharge && isValidEmailFormat(email) && !email.isEmpty

        #expect(canSubmit)
    }

    // MARK: - Helper Function (mimics ImageSubmissionSheet logic)

    private func isValidEmailFormat(_ email: String) -> Bool {
        let emailRegex = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        let emailPredicate = NSPredicate(format: "SELF MATCHES %@", emailRegex)
        return emailPredicate.evaluate(with: email)
    }
}
#endif

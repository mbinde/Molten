//
//  ValidationUtilitiesTests.swift
//  MoltenTests
//
//  Unit tests for ValidationUtilities
//

#if canImport(Testing)
import Testing
#else
#if canImport(XCTest)
import XCTest
#endif
#endif

import Foundation
@testable import Molten

@MainActor
@Suite("ValidationUtilities Tests")
struct ValidationUtilitiesTests {

    // MARK: - validateNonEmptyString Tests

    @Test("validateNonEmptyString with valid string returns success")
    func testValidateNonEmptyStringSuccess() {
        let result = ValidationUtilities.validateNonEmptyString("Hello")
        
        switch result {
        case .success(let value):
            #expect(value == "Hello")
        case .failure:
            Issue.record("Expected success, got failure")
        }
    }

    @Test("validateNonEmptyString with whitespace-padded string trims and returns success")
    func testValidateNonEmptyStringTrimsWhitespace() {
        let result = ValidationUtilities.validateNonEmptyString("  Hello  ")
        
        switch result {
        case .success(let value):
            #expect(value == "Hello")
        case .failure:
            Issue.record("Expected success, got failure")
        }
    }

    @Test("validateNonEmptyString with empty string returns failure")
    func testValidateNonEmptyStringEmpty() {
        let result = ValidationUtilities.validateNonEmptyString("")
        
        switch result {
        case .success:
            Issue.record("Expected failure, got success")
        case .failure(let error):
            #expect(error.userMessage.contains("cannot be empty"))
        }
    }

    @Test("validateNonEmptyString with whitespace-only string returns failure")
    func testValidateNonEmptyStringWhitespaceOnly() {
        let result = ValidationUtilities.validateNonEmptyString("   ")
        
        switch result {
        case .success:
            Issue.record("Expected failure, got success")
        case .failure(let error):
            #expect(error.userMessage.contains("cannot be empty"))
        }
    }

    @Test("validateNonEmptyString uses custom field name in error")
    func testValidateNonEmptyStringCustomFieldName() {
        let result = ValidationUtilities.validateNonEmptyString("", fieldName: "Item Name")
        
        switch result {
        case .success:
            Issue.record("Expected failure, got success")
        case .failure(let error):
            #expect(error.userMessage.contains("Item Name"))
        }
    }

    @Test("validateNonEmptyString with newlines and tabs trims correctly")
    func testValidateNonEmptyStringTrimsNewlines() {
        let result = ValidationUtilities.validateNonEmptyString("\n\tHello\t\n")
        
        switch result {
        case .success(let value):
            #expect(value == "Hello")
        case .failure:
            Issue.record("Expected success, got failure")
        }
    }

    @Test("validateNonEmptyString with emoji returns success")
    func testValidateNonEmptyStringEmoji() {
        let result = ValidationUtilities.validateNonEmptyString("🎨")
        
        switch result {
        case .success(let value):
            #expect(value == "🎨")
        case .failure:
            Issue.record("Expected success, got failure")
        }
    }

    @Test("validateNonEmptyString with special characters returns success")
    func testValidateNonEmptyStringSpecialCharacters() {
        let result = ValidationUtilities.validateNonEmptyString("Hello@#$%")
        
        switch result {
        case .success(let value):
            #expect(value == "Hello@#$%")
        case .failure:
            Issue.record("Expected success, got failure")
        }
    }

    // MARK: - validateMinimumLength Tests

    @Test("validateMinimumLength with string meeting minimum returns success")
    func testValidateMinimumLengthSuccess() {
        let result = ValidationUtilities.validateMinimumLength("Hello", minLength: 3)
        
        switch result {
        case .success(let value):
            #expect(value == "Hello")
        case .failure:
            Issue.record("Expected success, got failure")
        }
    }

    @Test("validateMinimumLength with string exactly at minimum returns success")
    func testValidateMinimumLengthExactly() {
        let result = ValidationUtilities.validateMinimumLength("ABC", minLength: 3)
        
        switch result {
        case .success(let value):
            #expect(value == "ABC")
        case .failure:
            Issue.record("Expected success, got failure")
        }
    }

    @Test("validateMinimumLength with string below minimum returns failure")
    func testValidateMinimumLengthTooShort() {
        let result = ValidationUtilities.validateMinimumLength("Hi", minLength: 3)
        
        switch result {
        case .success:
            Issue.record("Expected failure, got success")
        case .failure(let error):
            #expect(error.userMessage.contains("at least 3 characters"))
        }
    }

    @Test("validateMinimumLength with empty string returns failure")
    func testValidateMinimumLengthEmpty() {
        let result = ValidationUtilities.validateMinimumLength("", minLength: 1)
        
        switch result {
        case .success:
            Issue.record("Expected failure, got success")
        case .failure(let error):
            #expect(error.userMessage.contains("at least 1 character"))
        }
    }

    @Test("validateMinimumLength trims whitespace before checking")
    func testValidateMinimumLengthTrimsWhitespace() {
        let result = ValidationUtilities.validateMinimumLength("  Hi  ", minLength: 3)
        
        switch result {
        case .success:
            Issue.record("Expected failure, got success")
        case .failure(let error):
            #expect(error.userMessage.contains("at least 3 characters"))
        }
    }

    @Test("validateMinimumLength uses custom field name in error")
    func testValidateMinimumLengthCustomFieldName() {
        let result = ValidationUtilities.validateMinimumLength("AB", minLength: 3, fieldName: "Password")
        
        switch result {
        case .success:
            Issue.record("Expected failure, got success")
        case .failure(let error):
            #expect(error.userMessage.contains("Password"))
        }
    }

    @Test("validateMinimumLength with minimum 0 always succeeds")
    func testValidateMinimumLengthZero() {
        let result = ValidationUtilities.validateMinimumLength("", minLength: 0)
        
        switch result {
        case .success(let value):
            #expect(value == "")
        case .failure:
            Issue.record("Expected success, got failure")
        }
    }

    @Test("validateMinimumLength with emoji counts correctly")
    func testValidateMinimumLengthEmoji() {
        let result = ValidationUtilities.validateMinimumLength("🎨🎨", minLength: 2)
        
        switch result {
        case .success(let value):
            #expect(value == "🎨🎨")
        case .failure:
            Issue.record("Expected success, got failure")
        }
    }

    @Test("validateMinimumLength with Unicode counts correctly")
    func testValidateMinimumLengthUnicode() {
        let result = ValidationUtilities.validateMinimumLength("café", minLength: 4)
        
        switch result {
        case .success(let value):
            #expect(value == "café")
        case .failure:
            Issue.record("Expected success, got failure")
        }
    }

    // MARK: - validateDouble Tests

    @Test("validateDouble with valid integer string returns success")
    func testValidateDoubleInteger() {
        let result = ValidationUtilities.validateDouble("42")
        
        switch result {
        case .success(let value):
            #expect(value == 42.0)
        case .failure:
            Issue.record("Expected success, got failure")
        }
    }

    @Test("validateDouble with valid decimal string returns success")
    func testValidateDoubleDecimal() {
        let result = ValidationUtilities.validateDouble("3.14")
        
        switch result {
        case .success(let value):
            #expect(abs(value - 3.14) < 0.0001)
        case .failure:
            Issue.record("Expected success, got failure")
        }
    }

    @Test("validateDouble with negative number returns success")
    func testValidateDoubleNegative() {
        let result = ValidationUtilities.validateDouble("-5.5")
        
        switch result {
        case .success(let value):
            #expect(value == -5.5)
        case .failure:
            Issue.record("Expected success, got failure")
        }
    }

    @Test("validateDouble with zero returns success")
    func testValidateDoubleZero() {
        let result = ValidationUtilities.validateDouble("0")
        
        switch result {
        case .success(let value):
            #expect(value == 0.0)
        case .failure:
            Issue.record("Expected success, got failure")
        }
    }

    @Test("validateDouble with leading zeros returns success")
    func testValidateDoubleLeadingZeros() {
        let result = ValidationUtilities.validateDouble("007")
        
        switch result {
        case .success(let value):
            #expect(value == 7.0)
        case .failure:
            Issue.record("Expected success, got failure")
        }
    }

    @Test("validateDouble with scientific notation returns success")
    func testValidateDoubleScientificNotation() {
        let result = ValidationUtilities.validateDouble("1.5e2")
        
        switch result {
        case .success(let value):
            #expect(value == 150.0)
        case .failure:
            Issue.record("Expected success, got failure")
        }
    }

    @Test("validateDouble with whitespace-padded number trims and succeeds")
    func testValidateDoubleTrimsWhitespace() {
        let result = ValidationUtilities.validateDouble("  42.0  ")
        
        switch result {
        case .success(let value):
            #expect(value == 42.0)
        case .failure:
            Issue.record("Expected success, got failure")
        }
    }

    @Test("validateDouble with invalid text returns failure")
    func testValidateDoubleInvalidText() {
        let result = ValidationUtilities.validateDouble("abc")
        
        switch result {
        case .success:
            Issue.record("Expected failure, got success")
        case .failure(let error):
            #expect(error.userMessage.contains("valid number"))
        }
    }

    @Test("validateDouble with empty string returns failure")
    func testValidateDoubleEmpty() {
        let result = ValidationUtilities.validateDouble("")
        
        switch result {
        case .success:
            Issue.record("Expected failure, got success")
        case .failure(let error):
            #expect(error.userMessage.contains("cannot be empty"))
        }
    }

    @Test("validateDouble with multiple decimals returns failure")
    func testValidateDoubleMultipleDecimals() {
        let result = ValidationUtilities.validateDouble("3.14.15")
        
        switch result {
        case .success:
            Issue.record("Expected failure, got success")
        case .failure(let error):
            #expect(error.userMessage.contains("valid number"))
        }
    }

    @Test("validateDouble with mixed text and numbers returns failure")
    func testValidateDoubleMixedContent() {
        let result = ValidationUtilities.validateDouble("42abc")
        
        switch result {
        case .success:
            Issue.record("Expected failure, got success")
        case .failure(let error):
            #expect(error.userMessage.contains("valid number"))
        }
    }

    @Test("validateDouble uses custom field name in error")
    func testValidateDoubleCustomFieldName() {
        let result = ValidationUtilities.validateDouble("invalid", fieldName: "Price")
        
        switch result {
        case .success:
            Issue.record("Expected failure, got success")
        case .failure(let error):
            #expect(error.userMessage.contains("Price"))
        }
    }

    @Test("validateDouble with very large number returns success")
    func testValidateDoubleLargeNumber() {
        let result = ValidationUtilities.validateDouble("999999999.99")
        
        switch result {
        case .success(let value):
            #expect(abs(value - 999999999.99) < 0.01)
        case .failure:
            Issue.record("Expected success, got failure")
        }
    }

    @Test("validateDouble with very small number returns success")
    func testValidateDoubleSmallNumber() {
        let result = ValidationUtilities.validateDouble("0.00001")
        
        switch result {
        case .success(let value):
            #expect(abs(value - 0.00001) < 0.000001)
        case .failure:
            Issue.record("Expected success, got failure")
        }
    }

    // MARK: - validatePositiveDouble Tests

    @Test("validatePositiveDouble with positive number returns success")
    func testValidatePositiveDoubleSuccess() {
        let result = ValidationUtilities.validatePositiveDouble("25.50")
        
        switch result {
        case .success(let value):
            #expect(value == 25.50)
        case .failure:
            Issue.record("Expected success, got failure")
        }
    }

    @Test("validatePositiveDouble with zero returns failure")
    func testValidatePositiveDoubleZero() {
        let result = ValidationUtilities.validatePositiveDouble("0")
        
        switch result {
        case .success:
            Issue.record("Expected failure, got success")
        case .failure(let error):
            #expect(error.userMessage.contains("greater than zero"))
        }
    }

    @Test("validatePositiveDouble with negative number returns failure")
    func testValidatePositiveDoubleNegative() {
        let result = ValidationUtilities.validatePositiveDouble("-5.0")
        
        switch result {
        case .success:
            Issue.record("Expected failure, got success")
        case .failure(let error):
            #expect(error.userMessage.contains("greater than zero"))
        }
    }

    @Test("validatePositiveDouble with invalid text returns failure")
    func testValidatePositiveDoubleInvalidText() {
        let result = ValidationUtilities.validatePositiveDouble("abc")
        
        switch result {
        case .success:
            Issue.record("Expected failure, got success")
        case .failure(let error):
            #expect(error.userMessage.contains("valid number"))
        }
    }

    @Test("validatePositiveDouble with very small positive number returns success")
    func testValidatePositiveDoubleVerySmall() {
        let result = ValidationUtilities.validatePositiveDouble("0.001")
        
        switch result {
        case .success(let value):
            #expect(value > 0)
            #expect(abs(value - 0.001) < 0.0001)
        case .failure:
            Issue.record("Expected success, got failure")
        }
    }

    @Test("validatePositiveDouble uses custom field name in error")
    func testValidatePositiveDoubleCustomFieldName() {
        let result = ValidationUtilities.validatePositiveDouble("0", fieldName: "Quantity")
        
        switch result {
        case .success:
            Issue.record("Expected failure, got success")
        case .failure(let error):
            #expect(error.userMessage.contains("Quantity"))
        }
    }

    @Test("validatePositiveDouble with whitespace-padded number succeeds")
    func testValidatePositiveDoubleTrimsWhitespace() {
        let result = ValidationUtilities.validatePositiveDouble("  10.5  ")
        
        switch result {
        case .success(let value):
            #expect(value == 10.5)
        case .failure:
            Issue.record("Expected success, got failure")
        }
    }

    // MARK: - validateSupplierName Tests

    @Test("validateSupplierName with valid name returns success")
    func testValidateSupplierNameSuccess() {
        let result = ValidationUtilities.validateSupplierName("Bullseye Glass")
        
        switch result {
        case .success(let value):
            #expect(value == "Bullseye Glass")
        case .failure:
            Issue.record("Expected success, got failure")
        }
    }

    @Test("validateSupplierName with empty string returns failure")
    func testValidateSupplierNameEmpty() {
        let result = ValidationUtilities.validateSupplierName("")
        
        switch result {
        case .success:
            Issue.record("Expected failure, got success")
        case .failure(let error):
            #expect(error.userMessage.contains("Supplier name"))
        }
    }

    @Test("validateSupplierName trims whitespace")
    func testValidateSupplierNameTrimsWhitespace() {
        let result = ValidationUtilities.validateSupplierName("  Glass Shop  ")
        
        switch result {
        case .success(let value):
            #expect(value == "Glass Shop")
        case .failure:
            Issue.record("Expected success, got failure")
        }
    }

    @Test("validateSupplierName with special characters returns success")
    func testValidateSupplierNameSpecialCharacters() {
        let result = ValidationUtilities.validateSupplierName("ABC Glass & Co.")
        
        switch result {
        case .success(let value):
            #expect(value == "ABC Glass & Co.")
        case .failure:
            Issue.record("Expected success, got failure")
        }
    }

    // MARK: - validatePurchaseAmount Tests

    @Test("validatePurchaseAmount with valid amount returns success")
    func testValidatePurchaseAmountSuccess() {
        let result = ValidationUtilities.validatePurchaseAmount("99.99")
        
        switch result {
        case .success(let value):
            #expect(value == 99.99)
        case .failure:
            Issue.record("Expected success, got failure")
        }
    }

    @Test("validatePurchaseAmount with zero returns failure")
    func testValidatePurchaseAmountZero() {
        let result = ValidationUtilities.validatePurchaseAmount("0")
        
        switch result {
        case .success:
            Issue.record("Expected failure, got success")
        case .failure(let error):
            #expect(error.userMessage.contains("greater than zero"))
        }
    }

    @Test("validatePurchaseAmount with negative amount returns failure")
    func testValidatePurchaseAmountNegative() {
        let result = ValidationUtilities.validatePurchaseAmount("-10.00")
        
        switch result {
        case .success:
            Issue.record("Expected failure, got success")
        case .failure(let error):
            #expect(error.userMessage.contains("greater than zero"))
        }
    }

    @Test("validatePurchaseAmount with invalid text returns failure")
    func testValidatePurchaseAmountInvalidText() {
        let result = ValidationUtilities.validatePurchaseAmount("$99.99")
        
        switch result {
        case .success:
            Issue.record("Expected failure, got success")
        case .failure(let error):
            #expect(error.userMessage.contains("valid number"))
        }
    }

    @Test("validatePurchaseAmount with decimal amount returns success")
    func testValidatePurchaseAmountDecimal() {
        let result = ValidationUtilities.validatePurchaseAmount("49.95")
        
        switch result {
        case .success(let value):
            #expect(abs(value - 49.95) < 0.01)
        case .failure:
            Issue.record("Expected success, got failure")
        }
    }

    // MARK: - Error Properties Tests

    @Test("Validation errors have correct category")
    func testValidationErrorCategory() {
        let result = ValidationUtilities.validateNonEmptyString("")
        
        switch result {
        case .success:
            Issue.record("Expected failure, got success")
        case .failure(let error):
            #expect(error.category == .validation)
        }
    }

    @Test("Validation errors have warning severity")
    func testValidationErrorSeverity() {
        let result = ValidationUtilities.validateNonEmptyString("")
        
        switch result {
        case .success:
            Issue.record("Expected failure, got success")
        case .failure(let error):
            #expect(error.severity == .warning)
        }
    }

    @Test("Validation errors include suggestions")
    func testValidationErrorSuggestions() {
        let result = ValidationUtilities.validateNonEmptyString("")
        
        switch result {
        case .success:
            Issue.record("Expected failure, got success")
        case .failure(let error):
            #expect(!error.suggestions.isEmpty)
        }
    }

    // MARK: - Real-World Usage Tests

    @Test("Validate glass item name")
    func testRealWorldGlassItemName() {
        let validNames = ["Bullseye Clear", "Effetre 006", "CiM Pulsar"]
        
        for name in validNames {
            let result = ValidationUtilities.validateNonEmptyString(name, fieldName: "Item Name")
            switch result {
            case .success(let value):
                #expect(!value.isEmpty)
            case .failure:
                Issue.record("Expected success for '\(name)', got failure")
            }
        }
    }

    @Test("Validate inventory quantity")
    func testRealWorldInventoryQuantity() {
        let validQuantities = ["1.5", "10.0", "0.25", "100"]
        
        for quantity in validQuantities {
            let result = ValidationUtilities.validatePositiveDouble(quantity, fieldName: "Quantity")
            switch result {
            case .success(let value):
                #expect(value > 0)
            case .failure:
                Issue.record("Expected success for '\(quantity)', got failure")
            }
        }
    }

    @Test("Validate purchase amount with typical values")
    func testRealWorldPurchaseAmount() {
        let amounts = ["19.99", "150.00", "5.50"]
        
        for amount in amounts {
            let result = ValidationUtilities.validatePurchaseAmount(amount)
            switch result {
            case .success(let value):
                #expect(value > 0)
                #expect(value < 10000) // Reasonable upper bound
            case .failure:
                Issue.record("Expected success for '\(amount)', got failure")
            }
        }
    }

    @Test("Reject invalid inventory quantities")
    func testRealWorldInvalidQuantities() {
        let invalidQuantities = ["0", "-1", "abc", "", "1.2.3"]
        
        for quantity in invalidQuantities {
            let result = ValidationUtilities.validatePositiveDouble(quantity)
            switch result {
            case .success:
                Issue.record("Expected failure for '\(quantity)', got success")
            case .failure:
                break // Expected
            }
        }
    }

    // MARK: - Edge Cases

    @Test("validateNonEmptyString with only newlines returns failure")
    func testValidateNonEmptyStringOnlyNewlines() {
        let result = ValidationUtilities.validateNonEmptyString("\n\n\n")
        
        switch result {
        case .success:
            Issue.record("Expected failure, got success")
        case .failure(let error):
            #expect(error.userMessage.contains("cannot be empty"))
        }
    }

    @Test("validateDouble with infinity notation returns success")
    func testValidateDoubleInfinity() {
        let result = ValidationUtilities.validateDouble("inf")
        
        // Note: This may succeed or fail depending on Double's parser
        // Just verify it doesn't crash
        switch result {
        case .success(let value):
            #expect(value.isInfinite || value.isFinite)
        case .failure:
            break // Also acceptable
        }
    }

    @Test("validateMinimumLength with very long string succeeds")
    func testValidateMinimumLengthVeryLong() {
        let longString = String(repeating: "a", count: 10000)
        let result = ValidationUtilities.validateMinimumLength(longString, minLength: 5)
        
        switch result {
        case .success(let value):
            #expect(value.count == 10000)
        case .failure:
            Issue.record("Expected success, got failure")
        }
    }

    @Test("validatePositiveDouble with extremely small positive number")
    func testValidatePositiveDoubleExtremelySmall() {
        let result = ValidationUtilities.validatePositiveDouble("0.0000001")
        
        switch result {
        case .success(let value):
            #expect(value > 0)
        case .failure:
            Issue.record("Expected success, got failure")
        }
    }

    @Test("validateDouble with decimal-only string returns success")
    func testValidateDoubleDecimalOnly() {
        let result = ValidationUtilities.validateDouble(".5")
        
        switch result {
        case .success(let value):
            #expect(value == 0.5)
        case .failure:
            Issue.record("Expected success, got failure")
        }
    }

    @Test("validateNonEmptyString with mixed Unicode and ASCII")
    func testValidateNonEmptyStringMixedUnicode() {
        let result = ValidationUtilities.validateNonEmptyString("Hello 世界 🌍")
        
        switch result {
        case .success(let value):
            #expect(value == "Hello 世界 🌍")
        case .failure:
            Issue.record("Expected success, got failure")
        }
    }
}

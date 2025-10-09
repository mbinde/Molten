//
//  EmailUrlValidationTestsSafe.swift
//  FlameworkerTests
//
//  Created by TDD Recovery Process on December 2024.
//  Safe advanced validation utilities - completes validation domain with production patterns
//

import Testing
import Foundation

// Advanced validation type definitions building on our validation framework
struct EmailValidationResult {
    let isValid: Bool
    let format: EmailFormat
    let suggestions: [String]
    let errors: [UtilityValidationError]
    
    enum EmailFormat {
        case valid
        case missingAt
        case missingDomain
        case invalidFormat
        case empty
    }
    
    init(isValid: Bool, format: EmailFormat, suggestions: [String] = [], errors: [UtilityValidationError] = []) {
        self.isValid = isValid
        self.format = format
        self.suggestions = suggestions
        self.errors = errors
    }
}

struct URLValidationResult {
    let isValid: Bool
    let type: URLType
    let errors: [UtilityValidationError]
    
    enum URLType {
        case http
        case https
        case file
        case invalid
        case empty
    }
    
    init(isValid: Bool, type: URLType, errors: [UtilityValidationError] = []) {
        self.isValid = isValid
        self.type = type
        self.errors = errors
    }
}

struct DateValidationResult {
    let isValid: Bool
    let type: DateType
    let errors: [UtilityValidationError]
    
    enum DateType {
        case future
        case past
        case present
        case businessDay
        case weekend
        case invalid
    }
    
    init(isValid: Bool, type: DateType, errors: [UtilityValidationError] = []) {
        self.isValid = isValid
        self.type = type
        self.errors = errors
    }
}

// Cross-field validation structures
struct CrossFieldValidationRule {
    let name: String
    let fields: [String]
    let errorMessage: String
    let validator: ([String: Any?]) -> Bool
    
    init(name: String, fields: [String], errorMessage: String, validator: @escaping ([String: Any?]) -> Bool) {
        self.name = name
        self.fields = fields
        self.errorMessage = errorMessage
        self.validator = validator
    }
}

struct UtilityValidationError: Error {
    let field: String
    let rule: String
    let message: String
    let severity: Severity
    
    enum Severity: String, CaseIterable {
        case warning = "warning"
        case error = "error"
        case critical = "critical"
    }
    
    init(field: String, rule: String, message: String, severity: Severity = .error) {
        self.field = field
        self.rule = rule
        self.message = message
        self.severity = severity
    }
}

@Suite("Email URL Cross-Field Validation Tests - Safe", .serialized)
struct EmailUrlValidationTestsSafe {
    
    @Test("Should validate email addresses with comprehensive format checking")
    func testEmailValidation() {
        // Test valid email addresses
        let validEmail = validateEmail("user@example.com")
        #expect(validEmail.isValid == true)
        #expect(validEmail.format == .valid)
        #expect(validEmail.errors.isEmpty)
        
        // Test various invalid formats
        let missingAt = validateEmail("userexample.com")
        #expect(missingAt.isValid == false)
        #expect(missingAt.format == .missingAt)
        #expect(missingAt.errors.count == 1)
        
        let missingDomain = validateEmail("user@")
        #expect(missingDomain.isValid == false)
        #expect(missingDomain.format == .missingDomain)
        
        let emptyEmail = validateEmail("")
        #expect(emptyEmail.isValid == false)
        #expect(emptyEmail.format == .empty)
        
        // Test email with suggestions for common typos
        let typoEmail = validateEmail("user@gmial.com") // Common typo
        #expect(typoEmail.isValid == false)
        #expect(typoEmail.suggestions.contains("user@gmail.com"))
        
        // Test complex but valid emails
        let complexValid = validateEmail("test.user+tag@sub.example.co.uk")
        #expect(complexValid.isValid == true)
        #expect(complexValid.format == .valid)
    }
    
    @Test("Should validate URLs with proper protocol and format checking")
    func testURLValidation() {
        // Test valid URLs
        let httpsURL = validateURL("https://www.example.com")
        #expect(httpsURL.isValid == true)
        #expect(httpsURL.type == .https)
        #expect(httpsURL.errors.isEmpty)
        
        let httpURL = validateURL("http://example.com/path?query=value")
        #expect(httpURL.isValid == true)
        #expect(httpURL.type == .http)
        
        // Test invalid URLs
        let invalidURL = validateURL("not-a-url")
        #expect(invalidURL.isValid == false)
        #expect(invalidURL.type == .invalid)
        #expect(invalidURL.errors.count == 1)
        
        let emptyURL = validateURL("")
        #expect(emptyURL.isValid == false)
        #expect(emptyURL.type == .empty)
        
        // Test file URLs
        let fileURL = validateURL("file:///Users/test/document.pdf")
        #expect(fileURL.isValid == true)
        #expect(fileURL.type == .file)
        
        // Test URL without protocol
        let noProtocol = validateURL("www.example.com")
        #expect(noProtocol.isValid == false)
        #expect(noProtocol.errors[0].message.contains("protocol"))
    }
    
    @Test("Should perform cross-field validation with relationship rules")
    func testCrossFieldValidation() {
        // Test date range validation
        let tomorrow = Date().addingTimeInterval(86400)
        let yesterday = Date().addingTimeInterval(-86400)
        
        let validDateRange = validateCrossField(data: [
            "startDate": yesterday,
            "endDate": tomorrow
        ], rules: [
            CrossFieldValidationRule(
                name: "dateRange",
                fields: ["startDate", "endDate"],
                errorMessage: "End date must be after start date"
            ) { data in
                guard let start = data["startDate"] as? Date,
                      let end = data["endDate"] as? Date else { return false }
                return end > start
            }
        ])
        
        #expect(validDateRange.isValid == true)
        #expect(validDateRange.errors.isEmpty)
        
        // Test invalid date range
        let invalidDateRange = validateCrossField(data: [
            "startDate": tomorrow,
            "endDate": yesterday
        ], rules: [
            CrossFieldValidationRule(
                name: "dateRange",
                fields: ["startDate", "endDate"],
                errorMessage: "End date must be after start date"
            ) { data in
                guard let start = data["startDate"] as? Date,
                      let end = data["endDate"] as? Date else { return false }
                return end > start
            }
        ])
        
        #expect(invalidDateRange.isValid == false)
        #expect(invalidDateRange.errors.count == 1)
        #expect(invalidDateRange.errors[0].message == "End date must be after start date")
        
        // Test conditional field requirement
        let conditionalValid = validateCrossField(data: [
            "itemType": "inventory",
            "manufacturer": "Effetre"
        ], rules: [
            CrossFieldValidationRule(
                name: "conditionalManufacturer",
                fields: ["itemType", "manufacturer"],
                errorMessage: "Manufacturer is required for inventory items"
            ) { data in
                guard let itemType = data["itemType"] as? String else { return false }
                if itemType == "inventory" {
                    return data["manufacturer"] as? String != nil
                }
                return true // Not inventory, so manufacturer is optional
            }
        ])
        
        #expect(conditionalValid.isValid == true)
        
        // Test conditional field requirement failure
        let conditionalInvalid = validateCrossField(data: [
            "itemType": "inventory",
            "manufacturer": nil
        ], rules: [
            CrossFieldValidationRule(
                name: "conditionalManufacturer",
                fields: ["itemType", "manufacturer"],
                errorMessage: "Manufacturer is required for inventory items"
            ) { data in
                guard let itemType = data["itemType"] as? String else { return false }
                if itemType == "inventory" {
                    return data["manufacturer"] as? String != nil
                }
                return true
            }
        ])
        
        #expect(conditionalInvalid.isValid == false)
        #expect(conditionalInvalid.errors[0].message == "Manufacturer is required for inventory items")
    }
    
    // Private helper function to implement the expected logic for testing
    private func validateEmail(_ email: String) -> EmailValidationResult {
        // Handle empty email
        if email.isEmpty {
            return EmailValidationResult(
                isValid: false,
                format: .empty,
                errors: [UtilityValidationError(field: "email", rule: "required", message: "Email is required")]
            )
        }
        
        // Check for @ symbol
        if !email.contains("@") {
            return EmailValidationResult(
                isValid: false,
                format: .missingAt,
                errors: [UtilityValidationError(field: "email", rule: "format", message: "Email must contain @ symbol")]
            )
        }
        
        // Split by @ and check parts - using components(separatedBy:) to include empty parts
        let parts = email.components(separatedBy: "@")
        if parts.count != 2 {
            return EmailValidationResult(
                isValid: false,
                format: .invalidFormat,
                errors: [UtilityValidationError(field: "email", rule: "format", message: "Email format is invalid")]
            )
        }
        
        let localPart = parts[0]
        let domainPart = parts[1]
        
        // Check if domain is missing or empty
        if domainPart.isEmpty {
            return EmailValidationResult(
                isValid: false,
                format: .missingDomain,
                errors: [UtilityValidationError(field: "email", rule: "format", message: "Email domain is missing")]
            )
        }
        
        // Check if domain contains a dot
        if !domainPart.contains(".") {
            return EmailValidationResult(
                isValid: false,
                format: .invalidFormat,
                errors: [UtilityValidationError(field: "email", rule: "format", message: "Email domain must contain a dot")]
            )
        }
        
        // Check for common typos and provide suggestions
        var suggestions: [String] = []
        if domainPart.lowercased().contains("gmial") {
            suggestions.append(email.replacingOccurrences(of: "gmial", with: "gmail", options: .caseInsensitive))
        }
        if domainPart.lowercased().contains("yahooo") {
            suggestions.append(email.replacingOccurrences(of: "yahooo", with: "yahoo", options: .caseInsensitive))
        }
        
        // If we have suggestions, it's invalid but with helpful suggestions
        if !suggestions.isEmpty {
            return EmailValidationResult(
                isValid: false,
                format: .invalidFormat,
                suggestions: suggestions,
                errors: [UtilityValidationError(field: "email", rule: "typo", message: "Email appears to have a typo")]
            )
        }
        
        // Basic validation passed
        return EmailValidationResult(isValid: true, format: .valid)
    }
    
    // Private helper function for URL validation
    private func validateURL(_ urlString: String) -> URLValidationResult {
        // Handle empty URL
        if urlString.isEmpty {
            return URLValidationResult(
                isValid: false,
                type: .empty,
                errors: [UtilityValidationError(field: "url", rule: "required", message: "URL is required")]
            )
        }
        
        // Check for protocol
        if urlString.hasPrefix("https://") {
            // Validate HTTPS URL structure
            let withoutProtocol = String(urlString.dropFirst(8)) // Remove "https://"
            if withoutProtocol.isEmpty || !withoutProtocol.contains(".") {
                return URLValidationResult(
                    isValid: false,
                    type: .invalid,
                    errors: [UtilityValidationError(field: "url", rule: "format", message: "Invalid HTTPS URL format")]
                )
            }
            return URLValidationResult(isValid: true, type: .https)
            
        } else if urlString.hasPrefix("http://") {
            // Validate HTTP URL structure
            let withoutProtocol = String(urlString.dropFirst(7)) // Remove "http://"
            if withoutProtocol.isEmpty || !withoutProtocol.contains(".") {
                return URLValidationResult(
                    isValid: false,
                    type: .invalid,
                    errors: [UtilityValidationError(field: "url", rule: "format", message: "Invalid HTTP URL format")]
                )
            }
            return URLValidationResult(isValid: true, type: .http)
            
        } else if urlString.hasPrefix("file://") {
            // Validate file URL structure
            let withoutProtocol = String(urlString.dropFirst(7)) // Remove "file://"
            if withoutProtocol.isEmpty {
                return URLValidationResult(
                    isValid: false,
                    type: .invalid,
                    errors: [UtilityValidationError(field: "url", rule: "format", message: "Invalid file URL format")]
                )
            }
            return URLValidationResult(isValid: true, type: .file)
            
        } else {
            // No valid protocol found
            return URLValidationResult(
                isValid: false,
                type: .invalid,
                errors: [UtilityValidationError(field: "url", rule: "protocol", message: "URL must include a valid protocol (http://, https://, or file://)")]
            )
        }
    }
    
    // Private helper function for cross-field validation
    private func validateCrossField(data: [String: Any?], rules: [CrossFieldValidationRule]) -> UtilityValidationResult {
        var errors: [UtilityValidationError] = []
        
        for rule in rules {
            if !rule.validator(data) {
                errors.append(UtilityValidationError(
                    field: rule.fields.joined(separator: ","),
                    rule: rule.name,
                    message: rule.errorMessage
                ))
            }
        }
        
        return UtilityValidationResult(isValid: errors.isEmpty, errors: errors)
    }
}

// ValidationResult structure for cross-field validation
struct UtilityValidationResult {
    let isValid: Bool
    let errors: [UtilityValidationError]
    
    init(isValid: Bool, errors: [UtilityValidationError] = []) {
        self.isValid = isValid
        self.errors = errors
    }
}
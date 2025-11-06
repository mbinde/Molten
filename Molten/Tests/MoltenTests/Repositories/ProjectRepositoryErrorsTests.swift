//
//  ProjectRepositoryErrorsTests.swift
//  MoltenTests
//
//  Unit tests for ProjectRepositoryError enum
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

@Suite("ProjectRepositoryError Tests")
struct ProjectRepositoryErrorsTests {

    // MARK: - Error Description Tests

    @Test("planNotFound error has correct description")
    func testPlanNotFoundDescription() {
        let error = ProjectRepositoryError.planNotFound

        #expect(error.errorDescription == "Project plan not found")
    }

    @Test("logNotFound error has correct description")
    func testLogNotFoundDescription() {
        let error = ProjectRepositoryError.logNotFound

        #expect(error.errorDescription == "Project log not found")
    }

    @Test("imageNotFound error has correct description")
    func testImageNotFoundDescription() {
        let error = ProjectRepositoryError.imageNotFound

        #expect(error.errorDescription == "Project image not found")
    }

    @Test("stepNotFound error has correct description")
    func testStepNotFoundDescription() {
        let error = ProjectRepositoryError.stepNotFound

        #expect(error.errorDescription == "Project step not found")
    }

    @Test("urlNotFound error has correct description")
    func testUrlNotFoundDescription() {
        let error = ProjectRepositoryError.urlNotFound

        #expect(error.errorDescription == "Reference URL not found")
    }

    @Test("invalidData error includes reason in description")
    func testInvalidDataDescription() {
        let error = ProjectRepositoryError.invalidData("Missing required field")

        #expect(error.errorDescription == "Invalid data: Missing required field")
    }

    @Test("saveFailed error includes reason in description")
    func testSaveFailedDescription() {
        let error = ProjectRepositoryError.saveFailed("Core Data context save failed")

        #expect(error.errorDescription == "Save failed: Core Data context save failed")
    }

    @Test("deleteFailed error includes reason in description")
    func testDeleteFailedDescription() {
        let error = ProjectRepositoryError.deleteFailed("Project has dependencies")

        #expect(error.errorDescription == "Delete failed: Project has dependencies")
    }

    // MARK: - Equatable Tests

    @Test("planNotFound errors are equal")
    func testPlanNotFoundEquality() {
        let error1 = ProjectRepositoryError.planNotFound
        let error2 = ProjectRepositoryError.planNotFound

        #expect(error1 == error2)
    }

    @Test("logNotFound errors are equal")
    func testLogNotFoundEquality() {
        let error1 = ProjectRepositoryError.logNotFound
        let error2 = ProjectRepositoryError.logNotFound

        #expect(error1 == error2)
    }

    @Test("imageNotFound errors are equal")
    func testImageNotFoundEquality() {
        let error1 = ProjectRepositoryError.imageNotFound
        let error2 = ProjectRepositoryError.imageNotFound

        #expect(error1 == error2)
    }

    @Test("stepNotFound errors are equal")
    func testStepNotFoundEquality() {
        let error1 = ProjectRepositoryError.stepNotFound
        let error2 = ProjectRepositoryError.stepNotFound

        #expect(error1 == error2)
    }

    @Test("urlNotFound errors are equal")
    func testUrlNotFoundEquality() {
        let error1 = ProjectRepositoryError.urlNotFound
        let error2 = ProjectRepositoryError.urlNotFound

        #expect(error1 == error2)
    }

    @Test("invalidData errors with same reason are equal")
    func testInvalidDataEqualitySameReason() {
        let error1 = ProjectRepositoryError.invalidData("Same reason")
        let error2 = ProjectRepositoryError.invalidData("Same reason")

        #expect(error1 == error2)
    }

    @Test("invalidData errors with different reasons are not equal")
    func testInvalidDataEqualityDifferentReason() {
        let error1 = ProjectRepositoryError.invalidData("Reason A")
        let error2 = ProjectRepositoryError.invalidData("Reason B")

        #expect(error1 != error2)
    }

    @Test("saveFailed errors with same reason are equal")
    func testSaveFailedEqualitySameReason() {
        let error1 = ProjectRepositoryError.saveFailed("Database error")
        let error2 = ProjectRepositoryError.saveFailed("Database error")

        #expect(error1 == error2)
    }

    @Test("saveFailed errors with different reasons are not equal")
    func testSaveFailedEqualityDifferentReason() {
        let error1 = ProjectRepositoryError.saveFailed("Reason A")
        let error2 = ProjectRepositoryError.saveFailed("Reason B")

        #expect(error1 != error2)
    }

    @Test("deleteFailed errors with same reason are equal")
    func testDeleteFailedEqualitySameReason() {
        let error1 = ProjectRepositoryError.deleteFailed("Has dependencies")
        let error2 = ProjectRepositoryError.deleteFailed("Has dependencies")

        #expect(error1 == error2)
    }

    @Test("deleteFailed errors with different reasons are not equal")
    func testDeleteFailedEqualityDifferentReason() {
        let error1 = ProjectRepositoryError.deleteFailed("Reason A")
        let error2 = ProjectRepositoryError.deleteFailed("Reason B")

        #expect(error1 != error2)
    }

    @Test("Different error cases are not equal")
    func testDifferentErrorCasesNotEqual() {
        let error1 = ProjectRepositoryError.planNotFound
        let error2 = ProjectRepositoryError.logNotFound
        let error3 = ProjectRepositoryError.imageNotFound
        let error4 = ProjectRepositoryError.stepNotFound
        let error5 = ProjectRepositoryError.urlNotFound
        let error6 = ProjectRepositoryError.invalidData("test")
        let error7 = ProjectRepositoryError.saveFailed("test")
        let error8 = ProjectRepositoryError.deleteFailed("test")

        // Test a few combinations
        #expect(error1 != error2)
        #expect(error1 != error3)
        #expect(error2 != error3)
        #expect(error4 != error5)
        #expect(error6 != error7)
        #expect(error7 != error8)
    }

    // MARK: - Error Protocol Conformance Tests

    @Test("Error can be thrown and caught")
    func testErrorCanBeThrown() {
        func throwingFunction() throws {
            throw ProjectRepositoryError.planNotFound
        }

        do {
            try throwingFunction()
            Issue.record("Expected error to be thrown")
        } catch let error as ProjectRepositoryError {
            #expect(error == .planNotFound)
        } catch {
            Issue.record("Caught unexpected error type")
        }
    }

    @Test("LocalizedError protocol provides description")
    func testLocalizedErrorProtocol() {
        let error: LocalizedError = ProjectRepositoryError.invalidData("Test error")

        #expect(error.errorDescription != nil)
        #expect(error.errorDescription == "Invalid data: Test error")
    }

    // MARK: - Edge Cases

    @Test("invalidData with empty reason")
    func testInvalidDataEmptyReason() {
        let error = ProjectRepositoryError.invalidData("")

        #expect(error.errorDescription == "Invalid data: ")
    }

    @Test("saveFailed with complex reason")
    func testSaveFailedComplexReason() {
        let complexReason = "Failed to save: NSManagedObjectContext failed with error code 1234"
        let error = ProjectRepositoryError.saveFailed(complexReason)

        #expect(error.errorDescription == "Save failed: \(complexReason)")
    }

    @Test("deleteFailed with multiline reason")
    func testDeleteFailedMultilineReason() {
        let multilineReason = """
        Multiple issues:
        - Project in use
        - Cascading delete failed
        """
        let error = ProjectRepositoryError.deleteFailed(multilineReason)

        #expect(error.errorDescription?.contains("Delete failed:") == true)
        #expect(error.errorDescription?.contains(multilineReason) == true)
    }

    // MARK: - All Error Cases Coverage

    @Test("All error cases can be instantiated")
    func testAllErrorCasesInstantiable() {
        let errors: [ProjectRepositoryError] = [
            .planNotFound,
            .logNotFound,
            .imageNotFound,
            .stepNotFound,
            .urlNotFound,
            .invalidData("test"),
            .saveFailed("test"),
            .deleteFailed("test")
        ]

        #expect(errors.count == 8)

        // All should have descriptions
        for error in errors {
            #expect(error.errorDescription != nil)
            #expect(!error.errorDescription!.isEmpty)
        }
    }
}

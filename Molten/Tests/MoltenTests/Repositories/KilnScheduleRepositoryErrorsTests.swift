//
//  KilnScheduleRepositoryErrorsTests.swift
//  MoltenTests
//
//  Unit tests for KilnScheduleRepositoryError enum
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

@Suite("KilnScheduleRepositoryError Tests")
struct KilnScheduleRepositoryErrorsTests {

    // MARK: - Error Description Tests

    @Test("scheduleNotFound error has correct description")
    func testScheduleNotFoundDescription() {
        let error = KilnScheduleRepositoryError.scheduleNotFound

        #expect(error.errorDescription == "Kiln schedule not found")
    }

    @Test("invalidData error includes reason in description")
    func testInvalidDataDescription() {
        let error = KilnScheduleRepositoryError.invalidData("Temperature out of range")

        #expect(error.errorDescription == "Invalid data: Temperature out of range")
    }

    @Test("saveFailed error includes reason in description")
    func testSaveFailedDescription() {
        let error = KilnScheduleRepositoryError.saveFailed("Core Data context save failed")

        #expect(error.errorDescription == "Save failed: Core Data context save failed")
    }

    @Test("deleteFailed error includes reason in description")
    func testDeleteFailedDescription() {
        let error = KilnScheduleRepositoryError.deleteFailed("Schedule is in use")

        #expect(error.errorDescription == "Delete failed: Schedule is in use")
    }

    // MARK: - Equatable Tests

    @Test("scheduleNotFound errors are equal")
    func testScheduleNotFoundEquality() {
        let error1 = KilnScheduleRepositoryError.scheduleNotFound
        let error2 = KilnScheduleRepositoryError.scheduleNotFound

        #expect(error1 == error2)
    }

    @Test("invalidData errors with same reason are equal")
    func testInvalidDataEqualitySameReason() {
        let error1 = KilnScheduleRepositoryError.invalidData("Same reason")
        let error2 = KilnScheduleRepositoryError.invalidData("Same reason")

        #expect(error1 == error2)
    }

    @Test("invalidData errors with different reasons are not equal")
    func testInvalidDataEqualityDifferentReason() {
        let error1 = KilnScheduleRepositoryError.invalidData("Reason A")
        let error2 = KilnScheduleRepositoryError.invalidData("Reason B")

        #expect(error1 != error2)
    }

    @Test("saveFailed errors with same reason are equal")
    func testSaveFailedEqualitySameReason() {
        let error1 = KilnScheduleRepositoryError.saveFailed("Database error")
        let error2 = KilnScheduleRepositoryError.saveFailed("Database error")

        #expect(error1 == error2)
    }

    @Test("saveFailed errors with different reasons are not equal")
    func testSaveFailedEqualityDifferentReason() {
        let error1 = KilnScheduleRepositoryError.saveFailed("Reason A")
        let error2 = KilnScheduleRepositoryError.saveFailed("Reason B")

        #expect(error1 != error2)
    }

    @Test("deleteFailed errors with same reason are equal")
    func testDeleteFailedEqualitySameReason() {
        let error1 = KilnScheduleRepositoryError.deleteFailed("Constraint violation")
        let error2 = KilnScheduleRepositoryError.deleteFailed("Constraint violation")

        #expect(error1 == error2)
    }

    @Test("deleteFailed errors with different reasons are not equal")
    func testDeleteFailedEqualityDifferentReason() {
        let error1 = KilnScheduleRepositoryError.deleteFailed("Reason A")
        let error2 = KilnScheduleRepositoryError.deleteFailed("Reason B")

        #expect(error1 != error2)
    }

    @Test("Different error cases are not equal")
    func testDifferentErrorCasesNotEqual() {
        let error1 = KilnScheduleRepositoryError.scheduleNotFound
        let error2 = KilnScheduleRepositoryError.invalidData("Some reason")
        let error3 = KilnScheduleRepositoryError.saveFailed("Some reason")
        let error4 = KilnScheduleRepositoryError.deleteFailed("Some reason")

        #expect(error1 != error2)
        #expect(error1 != error3)
        #expect(error1 != error4)
        #expect(error2 != error3)
        #expect(error2 != error4)
        #expect(error3 != error4)
    }

    // MARK: - Error Protocol Conformance Tests

    @Test("Error can be thrown and caught")
    func testErrorCanBeThrown() {
        func throwingFunction() throws {
            throw KilnScheduleRepositoryError.scheduleNotFound
        }

        do {
            try throwingFunction()
            Issue.record("Expected error to be thrown")
        } catch let error as KilnScheduleRepositoryError {
            #expect(error == .scheduleNotFound)
        } catch {
            Issue.record("Caught unexpected error type")
        }
    }

    @Test("LocalizedError protocol provides description")
    func testLocalizedErrorProtocol() {
        let error: LocalizedError = KilnScheduleRepositoryError.invalidData("Test")

        #expect(error.errorDescription != nil)
        #expect(error.errorDescription == "Invalid data: Test")
    }

    // MARK: - Edge Cases

    @Test("invalidData with empty reason")
    func testInvalidDataEmptyReason() {
        let error = KilnScheduleRepositoryError.invalidData("")

        #expect(error.errorDescription == "Invalid data: ")
    }

    @Test("saveFailed with complex reason")
    func testSaveFailedComplexReason() {
        let complexReason = "Failed to save: NSManagedObjectContext failed with error code 1234"
        let error = KilnScheduleRepositoryError.saveFailed(complexReason)

        #expect(error.errorDescription == "Save failed: \(complexReason)")
    }

    @Test("deleteFailed with multiline reason")
    func testDeleteFailedMultilineReason() {
        let multilineReason = """
        Multiple issues:
        - Schedule in use
        - Cascading delete failed
        """
        let error = KilnScheduleRepositoryError.deleteFailed(multilineReason)

        #expect(error.errorDescription?.contains("Delete failed:") == true)
        #expect(error.errorDescription?.contains(multilineReason) == true)
    }
}

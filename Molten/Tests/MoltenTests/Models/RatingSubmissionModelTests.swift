//
//  RatingSubmissionModelTests.swift
//  MoltenTests
//
//  Converted to Swift Testing on 11/18/25.
//

import Testing
@testable import Molten

@Suite("RatingSubmissionModel Tests")
struct RatingSubmissionModelTests {

    // MARK: - Initialization Tests

    @Test("Initialization WithValidData CreatesModel")
    func testInitialization_WithValidData_CreatesModel() {
        // Given
        let itemStableId = "bullseye-001-0"
        let starRating = 5
        let words = ["beautiful", "vibrant", "smooth", "reliable", "stunning"]

        // When
        let model = RatingSubmissionModel(
            itemStableId: itemStableId,
            starRating: starRating,
            words: words
        )

        // Then
        #expect(model.itemStableId == itemStableId)
        #expect(model.starRating == starRating)
        #expect(model.words == words)
        #expect(model.createdAt != nil)
    }

    @Test("Initialization TrimsWhitespaceFromItemStableId")
    func testInitialization_TrimsWhitespaceFromItemStableId() {
        // Given
        let itemStableId = "  bullseye-001-0  "

        // When
        let model = RatingSubmissionModel(
            itemStableId: itemStableId,
            starRating: 5,
            words: ["test", "words", "here", "now", "go"]
        )

        // Then
        #expect(model.itemStableId == "bullseye-001-0")
    }

    @Test("Initialization TrimsWhitespaceFromWords")
    func testInitialization_TrimsWhitespaceFromWords() {
        // Given
        let words = ["  beautiful  ", "vibrant", "  smooth", "reliable  ", "stunning"]

        // When
        let model = RatingSubmissionModel(
            itemStableId: "bullseye-001-0",
            starRating: 5,
            words: words
        )

        // Then
        #expect(model.words == ["beautiful", "vibrant", "smooth", "reliable", "stunning"])
    }

    @Test("Initialization LowercasesWords")
    func testInitialization_LowercasesWords() {
        // Given
        let words = ["Beautiful", "VIBRANT", "SmOoTh", "reliable", "STUNNING"]

        // When
        let model = RatingSubmissionModel(
            itemStableId: "bullseye-001-0",
            starRating: 5,
            words: words
        )

        // Then
        #expect(model.words == ["beautiful", "vibrant", "smooth", "reliable", "stunning"])
    }

    // MARK: - Validation Tests

    @Test("IsValid WithValidData ReturnsTrue")
    func testIsValid_WithValidData_ReturnsTrue() {
        // Given
        let model = RatingSubmissionModel(
            itemStableId: "bullseye-001-0",
            starRating: 5,
            words: ["beautiful", "vibrant", "smooth", "reliable", "stunning"]
        )

        // When/Then
        #expect(model.isValid)
        #expect(model.validationErrors.isEmpty)
    }

    @Test("IsValid WithEmptyItemStableId ReturnsFalse")
    func testIsValid_WithEmptyItemStableId_ReturnsFalse() {
        // Given
        let model = RatingSubmissionModel(
            itemStableId: "",
            starRating: 5,
            words: ["beautiful", "vibrant", "smooth", "reliable", "stunning"]
        )

        // When/Then
        #expect(!model.isValid)
        #expect(model.validationErrors.contains("Item stable ID is required"))
    }

    @Test("IsValid WithStarRatingTooLow ReturnsFalse")
    func testIsValid_WithStarRatingTooLow_ReturnsFalse() {
        // Given
        let model = RatingSubmissionModel(
            itemStableId: "bullseye-001-0",
            starRating: 0,
            words: ["beautiful", "vibrant", "smooth", "reliable", "stunning"]
        )

        // When/Then
        #expect(!model.isValid)
        #expect(model.validationErrors.contains("Star rating must be between 1 and 5"))
    }

    @Test("IsValid WithStarRatingTooHigh ReturnsFalse")
    func testIsValid_WithStarRatingTooHigh_ReturnsFalse() {
        // Given
        let model = RatingSubmissionModel(
            itemStableId: "bullseye-001-0",
            starRating: 6,
            words: ["beautiful", "vibrant", "smooth", "reliable", "stunning"]
        )

        // When/Then
        #expect(!model.isValid)
        #expect(model.validationErrors.contains("Star rating must be between 1 and 5"))
    }

    @Test("IsValid WithFewerThanFiveWords ReturnsFalse")
    func testIsValid_WithFewerThanFiveWords_ReturnsFalse() {
        // Given
        let model = RatingSubmissionModel(
            itemStableId: "bullseye-001-0",
            starRating: 5,
            words: ["beautiful", "vibrant"]
        )

        // When/Then
        #expect(!model.isValid)
        #expect(model.validationErrors.contains("Exactly 5 words are required"))
    }

    @Test("IsValid WithMoreThanFiveWords ReturnsFalse")
    func testIsValid_WithMoreThanFiveWords_ReturnsFalse() {
        // Given
        let model = RatingSubmissionModel(
            itemStableId: "bullseye-001-0",
            starRating: 5,
            words: ["beautiful", "vibrant", "smooth", "reliable", "stunning", "extra"]
        )

        // When/Then
        #expect(!model.isValid)
        #expect(model.validationErrors.contains("Exactly 5 words are required"))
    }

    @Test("IsValid WithEmptyWord ReturnsFalse")
    func testIsValid_WithEmptyWord_ReturnsFalse() {
        // Given
        let model = RatingSubmissionModel(
            itemStableId: "bullseye-001-0",
            starRating: 5,
            words: ["beautiful", "", "smooth", "reliable", "stunning"]
        )

        // When/Then
        #expect(!model.isValid)
        #expect(model.validationErrors.contains("All words must be non-empty"))
    }

    @Test("IsValid WithWordTooLong ReturnsFalse")
    func testIsValid_WithWordTooLong_ReturnsFalse() {
        // Given
        let longWord = String(repeating: "a", count: 31)
        let model = RatingSubmissionModel(
            itemStableId: "bullseye-001-0",
            starRating: 5,
            words: ["beautiful", longWord, "smooth", "reliable", "stunning"]
        )

        // When/Then
        #expect(!model.isValid)
        #expect(model.validationErrors.contains("Words must be 30 characters or less"))
    }

    @Test("IsValid WithDuplicateWords ReturnsFalse")
    func testIsValid_WithDuplicateWords_ReturnsFalse() {
        // Given
        let model = RatingSubmissionModel(
            itemStableId: "bullseye-001-0",
            starRating: 5,
            words: ["beautiful", "vibrant", "beautiful", "reliable", "stunning"]
        )

        // When/Then
        #expect(!model.isValid)
        #expect(model.validationErrors.contains("Words must be unique"))
    }

    // MARK: - Profanity Filter Tests

    @Test("ContainsProfanity WithCleanWords ReturnsFalse")
    func testContainsProfanity_WithCleanWords_ReturnsFalse() {
        // Given
        let model = RatingSubmissionModel(
            itemStableId: "bullseye-001-0",
            starRating: 5,
            words: ["beautiful", "vibrant", "smooth", "reliable", "stunning"]
        )

        // When/Then
        #expect(!model.containsProfanity)
    }

    @Test("ContainsProfanity WithProfaneWord ReturnsTrue")
    func testContainsProfanity_WithProfaneWord_ReturnsTrue() {
        // Given - using a mild example for testing
        let model = RatingSubmissionModel(
            itemStableId: "bullseye-001-0",
            starRating: 5,
            words: ["beautiful", "damn", "smooth", "reliable", "stunning"]
        )

        // When/Then
        #expect(model.containsProfanity)
    }

    // MARK: - Equatable Tests

    @Test("Equatable SameData ReturnsTrue")
    func testEquatable_SameData_ReturnsTrue() {
        // Given
        let date = Date()
        let model1 = RatingSubmissionModel(
            itemStableId: "bullseye-001-0",
            starRating: 5,
            words: ["beautiful", "vibrant", "smooth", "reliable", "stunning"],
            createdAt: date
        )
        let model2 = RatingSubmissionModel(
            itemStableId: "bullseye-001-0",
            starRating: 5,
            words: ["beautiful", "vibrant", "smooth", "reliable", "stunning"],
            createdAt: date
        )

        // When/Then
        #expect(model1 == model2)
    }

    @Test("Equatable DifferentStarRating ReturnsFalse")
    func testEquatable_DifferentStarRating_ReturnsFalse() {
        // Given
        let model1 = RatingSubmissionModel(
            itemStableId: "bullseye-001-0",
            starRating: 5,
            words: ["beautiful", "vibrant", "smooth", "reliable", "stunning"]
        )
        let model2 = RatingSubmissionModel(
            itemStableId: "bullseye-001-0",
            starRating: 4,
            words: ["beautiful", "vibrant", "smooth", "reliable", "stunning"]
        )

        // When/Then
        #expect(model1 != model2)
    }

    // MARK: - Codable Tests

    @Test("Codable EncodeDecode PreservesData")
    func testCodable_EncodeDecode_PreservesData() throws {
        // Given
        let original = RatingSubmissionModel(
            itemStableId: "bullseye-001-0",
            starRating: 5,
            words: ["beautiful", "vibrant", "smooth", "reliable", "stunning"]
        )

        // When
        let encoded = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(RatingSubmissionModel.self, from: encoded)

        // Then
        #expect(decoded.itemStableId == original.itemStableId)
        #expect(decoded.starRating == original.starRating)
        #expect(decoded.words == original.words)
    }
}

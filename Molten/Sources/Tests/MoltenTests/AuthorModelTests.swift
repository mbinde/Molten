//
//  AuthorModelTests.swift
//  MoltenTests
//
//  Tests for AuthorModel and AuthorSettings
//

import Testing
import Foundation
@testable import Molten

@Suite("AuthorModel Tests")
struct AuthorModelTests {

    // MARK: - Initialization Tests

    @Test("Initialize with all parameters")
    func initializeWithAllParameters() {
        let date = Date()
        let author = AuthorModel(
            name: "Jane Smith",
            email: "jane@example.com",
            website: "https://example.com",
            instagram: "janesmith",
            facebook: "janesmithglass",
            youtube: "@janesmith",
            dateAdded: date
        )

        #expect(author.name == "Jane Smith")
        #expect(author.email == "jane@example.com")
        #expect(author.website == "https://example.com")
        #expect(author.instagram == "janesmith")
        #expect(author.facebook == "janesmithglass")
        #expect(author.youtube == "@janesmith")
        #expect(author.dateAdded == date)
    }

    @Test("Initialize with defaults")
    func initializeWithDefaults() {
        let author = AuthorModel()

        #expect(author.name == nil)
        #expect(author.email == nil)
        #expect(author.website == nil)
        #expect(author.instagram == nil)
        #expect(author.facebook == nil)
        #expect(author.youtube == nil)
        // dateAdded should be set to current date (approximately)
        #expect(abs(author.dateAdded.timeIntervalSinceNow) < 1.0)
    }

    @Test("Initialize with partial information")
    func initializeWithPartialInfo() {
        let author = AuthorModel(
            name: "John Doe",
            website: "https://johndoe.com"
        )

        #expect(author.name == "John Doe")
        #expect(author.email == nil)
        #expect(author.website == "https://johndoe.com")
        #expect(author.instagram == nil)
        #expect(author.facebook == nil)
        #expect(author.youtube == nil)
    }

    // MARK: - hasAnyInfo Tests

    @Test("hasAnyInfo returns true when name is set")
    func hasAnyInfoWithName() {
        let author = AuthorModel(name: "Test Name")
        #expect(author.hasAnyInfo == true)
    }

    @Test("hasAnyInfo returns true when email is set")
    func hasAnyInfoWithEmail() {
        let author = AuthorModel(email: "test@example.com")
        #expect(author.hasAnyInfo == true)
    }

    @Test("hasAnyInfo returns true when website is set")
    func hasAnyInfoWithWebsite() {
        let author = AuthorModel(website: "https://example.com")
        #expect(author.hasAnyInfo == true)
    }

    @Test("hasAnyInfo returns true when instagram is set")
    func hasAnyInfoWithInstagram() {
        let author = AuthorModel(instagram: "testuser")
        #expect(author.hasAnyInfo == true)
    }

    @Test("hasAnyInfo returns true when facebook is set")
    func hasAnyInfoWithFacebook() {
        let author = AuthorModel(facebook: "testpage")
        #expect(author.hasAnyInfo == true)
    }

    @Test("hasAnyInfo returns true when youtube is set")
    func hasAnyInfoWithYouTube() {
        let author = AuthorModel(youtube: "@testchannel")
        #expect(author.hasAnyInfo == true)
    }

    @Test("hasAnyInfo returns false when all fields are nil")
    func hasAnyInfoWithNoInfo() {
        let author = AuthorModel()
        #expect(author.hasAnyInfo == false)
    }

    // MARK: - displayName Tests

    @Test("displayName returns name when set")
    func displayNameWithName() {
        let author = AuthorModel(name: "Jane Smith")
        #expect(author.displayName == "Jane Smith")
    }

    @Test("displayName returns Anonymous when name is nil")
    func displayNameWithoutName() {
        let author = AuthorModel()
        #expect(author.displayName == "Anonymous")
    }

    @Test("displayName returns Anonymous even with other fields set")
    func displayNameWithoutNameButOtherFields() {
        let author = AuthorModel(
            email: "test@example.com",
            website: "https://example.com"
        )
        #expect(author.displayName == "Anonymous")
    }

    // MARK: - Codable Tests

    @Test("Encode and decode full author")
    func encodeDecodeFullAuthor() throws {
        let original = AuthorModel(
            name: "Jane Smith",
            email: "jane@example.com",
            website: "https://example.com",
            instagram: "janesmith",
            facebook: "janesmithglass",
            youtube: "@janesmith"
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(original)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(AuthorModel.self, from: data)

        #expect(decoded.name == original.name)
        #expect(decoded.email == original.email)
        #expect(decoded.website == original.website)
        #expect(decoded.instagram == original.instagram)
        #expect(decoded.facebook == original.facebook)
        #expect(decoded.youtube == original.youtube)
        #expect(decoded.dateAdded.timeIntervalSince1970 == original.dateAdded.timeIntervalSince1970)
    }

    @Test("Encode and decode author with nil fields")
    func encodeDecodePartialAuthor() throws {
        let original = AuthorModel(
            name: "John Doe",
            website: "https://johndoe.com"
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(original)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(AuthorModel.self, from: data)

        #expect(decoded.name == "John Doe")
        #expect(decoded.email == nil)
        #expect(decoded.website == "https://johndoe.com")
        #expect(decoded.instagram == nil)
        #expect(decoded.facebook == nil)
        #expect(decoded.youtube == nil)
    }

    // MARK: - Hashable Tests

    @Test("Authors with same data are equal")
    func equalityWithSameData() {
        let date = Date()
        let author1 = AuthorModel(
            name: "Jane Smith",
            email: "jane@example.com",
            dateAdded: date
        )
        let author2 = AuthorModel(
            name: "Jane Smith",
            email: "jane@example.com",
            dateAdded: date
        )

        #expect(author1 == author2)
    }

    @Test("Authors with different data are not equal")
    func inequalityWithDifferentData() {
        let author1 = AuthorModel(name: "Jane Smith")
        let author2 = AuthorModel(name: "John Doe")

        #expect(author1 != author2)
    }

    @Test("Authors are hashable")
    func hashability() {
        let author = AuthorModel(name: "Jane Smith")
        var set = Set<AuthorModel>()
        set.insert(author)

        #expect(set.contains(author))
    }
}

@Suite("AuthorSettings Tests")
@MainActor
struct AuthorSettingsTests {

    // MARK: - Test Helpers

    /// Create a fresh AuthorSettings instance for testing
    /// Note: Cannot easily reset the singleton, so we test state changes
    func clearSettings(_ settings: AuthorSettings) {
        settings.clear()
    }

    // MARK: - Singleton Tests

    @Test("Shared instance exists")
    func sharedInstanceExists() {
        let settings = AuthorSettings.shared
        #expect(settings != nil)
    }

    // MARK: - hasAuthorInfo Tests

    @Test("hasAuthorInfo returns false when empty")
    func hasAuthorInfoWhenEmpty() {
        let settings = AuthorSettings.shared
        clearSettings(settings)

        #expect(settings.hasAuthorInfo == false)
    }

    @Test("hasAuthorInfo returns true when name is set")
    func hasAuthorInfoWithName() {
        let settings = AuthorSettings.shared
        clearSettings(settings)

        settings.name = "Test Name"
        #expect(settings.hasAuthorInfo == true)

        clearSettings(settings)
    }

    @Test("hasAuthorInfo returns true when email is set")
    func hasAuthorInfoWithEmail() {
        let settings = AuthorSettings.shared
        clearSettings(settings)

        settings.email = "test@example.com"
        #expect(settings.hasAuthorInfo == true)

        clearSettings(settings)
    }

    @Test("hasAuthorInfo returns true when website is set")
    func hasAuthorInfoWithWebsite() {
        let settings = AuthorSettings.shared
        clearSettings(settings)

        settings.website = "https://example.com"
        #expect(settings.hasAuthorInfo == true)

        clearSettings(settings)
    }

    @Test("hasAuthorInfo returns true when instagram is set")
    func hasAuthorInfoWithInstagram() {
        let settings = AuthorSettings.shared
        clearSettings(settings)

        settings.instagram = "testuser"
        #expect(settings.hasAuthorInfo == true)

        clearSettings(settings)
    }

    @Test("hasAuthorInfo returns true when facebook is set")
    func hasAuthorInfoWithFacebook() {
        let settings = AuthorSettings.shared
        clearSettings(settings)

        settings.facebook = "testpage"
        #expect(settings.hasAuthorInfo == true)

        clearSettings(settings)
    }

    @Test("hasAuthorInfo returns true when youtube is set")
    func hasAuthorInfoWithYouTube() {
        let settings = AuthorSettings.shared
        clearSettings(settings)

        settings.youtube = "@testchannel"
        #expect(settings.hasAuthorInfo == true)

        clearSettings(settings)
    }

    // MARK: - createAuthorModel Tests

    @Test("createAuthorModel returns nil when no info")
    func createAuthorModelWithNoInfo() {
        let settings = AuthorSettings.shared
        clearSettings(settings)

        let author = settings.createAuthorModel()
        #expect(author == nil)
    }

    @Test("createAuthorModel creates model with all fields")
    func createAuthorModelWithAllFields() {
        let settings = AuthorSettings.shared
        clearSettings(settings)

        settings.name = "Jane Smith"
        settings.email = "jane@example.com"
        settings.website = "https://example.com"
        settings.instagram = "janesmith"
        settings.facebook = "janesmithglass"
        settings.youtube = "@janesmith"

        let author = settings.createAuthorModel()

        #expect(author != nil)
        #expect(author?.name == "Jane Smith")
        #expect(author?.email == "jane@example.com")
        #expect(author?.website == "https://example.com")
        #expect(author?.instagram == "janesmith")
        #expect(author?.facebook == "janesmithglass")
        #expect(author?.youtube == "@janesmith")

        clearSettings(settings)
    }

    @Test("createAuthorModel creates model with only non-empty fields")
    func createAuthorModelWithPartialFields() {
        let settings = AuthorSettings.shared
        clearSettings(settings)

        settings.name = "John Doe"
        settings.website = "https://johndoe.com"
        // Leave other fields empty

        let author = settings.createAuthorModel()

        #expect(author != nil)
        #expect(author?.name == "John Doe")
        #expect(author?.email == nil)
        #expect(author?.website == "https://johndoe.com")
        #expect(author?.instagram == nil)
        #expect(author?.facebook == nil)
        #expect(author?.youtube == nil)

        clearSettings(settings)
    }

    @Test("createAuthorModel does not include empty strings")
    func createAuthorModelExcludesEmptyStrings() {
        let settings = AuthorSettings.shared
        clearSettings(settings)

        settings.name = "Test Name"
        settings.email = ""  // Explicitly empty
        settings.website = ""  // Explicitly empty

        let author = settings.createAuthorModel()

        #expect(author != nil)
        #expect(author?.name == "Test Name")
        #expect(author?.email == nil)  // Should be nil, not empty string
        #expect(author?.website == nil)  // Should be nil, not empty string

        clearSettings(settings)
    }

    // MARK: - Persistence Tests

    @Test("Settings persist to UserDefaults")
    func settingsPersist() {
        let settings = AuthorSettings.shared
        clearSettings(settings)

        // Set some values
        settings.name = "Persist Test"
        settings.email = "persist@test.com"

        // Manually verify UserDefaults (simulating app restart)
        let defaults = UserDefaults.standard
        let key = "molten.authorSettings"

        guard let data = defaults.data(forKey: key),
              let decoded = try? JSONDecoder().decode([String: String].self, from: data) else {
            Issue.record("Failed to load persisted data")
            return
        }

        #expect(decoded["name"] == "Persist Test")
        #expect(decoded["email"] == "persist@test.com")

        clearSettings(settings)
    }

    // MARK: - Clear Tests

    @Test("Clear removes all information")
    func clearRemovesAllInfo() {
        let settings = AuthorSettings.shared

        // Set all fields
        settings.name = "Jane Smith"
        settings.email = "jane@example.com"
        settings.website = "https://example.com"
        settings.instagram = "janesmith"
        settings.facebook = "janesmithglass"
        settings.youtube = "@janesmith"

        // Clear
        settings.clear()

        // Verify all fields are empty
        #expect(settings.name == "")
        #expect(settings.email == "")
        #expect(settings.website == "")
        #expect(settings.instagram == "")
        #expect(settings.facebook == "")
        #expect(settings.youtube == "")
        #expect(settings.hasAuthorInfo == false)
    }

    @Test("Clear updates UserDefaults")
    func clearUpdatesUserDefaults() {
        let settings = AuthorSettings.shared

        // Set values
        settings.name = "Jane Smith"
        settings.email = "jane@example.com"

        // Clear
        settings.clear()

        // Verify UserDefaults reflects the clear
        let defaults = UserDefaults.standard
        let key = "molten.authorSettings"

        guard let data = defaults.data(forKey: key),
              let decoded = try? JSONDecoder().decode([String: String].self, from: data) else {
            Issue.record("Failed to load persisted data after clear")
            return
        }

        #expect(decoded["name"] == "")
        #expect(decoded["email"] == "")
    }
}

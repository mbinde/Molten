//
//  AuthorModel.swift
//  Molten
//
//  Model for project plan author attribution
//

import Foundation
import Combine

/// Author information for project plans
/// Once set in a plan, this is read-only and preserved when re-sharing
nonisolated struct AuthorModel: Codable, Hashable, Sendable {
    let name: String?
    let email: String?
    let website: String?
    let instagram: String?
    let facebook: String?
    let youtube: String?
    let dateAdded: Date

    init(
        name: String? = nil,
        email: String? = nil,
        website: String? = nil,
        instagram: String? = nil,
        facebook: String? = nil,
        youtube: String? = nil,
        dateAdded: Date = Date()
    ) {
        self.name = name
        self.email = email
        self.website = website
        self.instagram = instagram
        self.facebook = facebook
        self.youtube = youtube
        self.dateAdded = dateAdded
    }

    /// Check if author has any information set
    var hasAnyInfo: Bool {
        return name != nil || email != nil || website != nil ||
               instagram != nil || facebook != nil || youtube != nil
    }

    /// Display name for the author (falls back to "Anonymous" if no name)
    var displayName: String {
        return name ?? "Anonymous"
    }
}

/// Settings for the user's author profile
/// This is stored in UserDefaults and used when exporting plans
@MainActor
class AuthorSettings: ObservableObject {
    static let shared = AuthorSettings()

    private let defaults = UserDefaults.standard
    private let key = "molten.authorSettings"

    @Published var name: String = "" {
        didSet { save() }
    }

    @Published var email: String = "" {
        didSet { save() }
    }

    @Published var website: String = "" {
        didSet { save() }
    }

    @Published var instagram: String = "" {
        didSet { save() }
    }

    @Published var facebook: String = "" {
        didSet { save() }
    }

    @Published var youtube: String = "" {
        didSet { save() }
    }

    private init() {
        load()
    }

    /// Check if user has set up their author profile
    var hasAuthorInfo: Bool {
        return !name.isEmpty || !email.isEmpty || !website.isEmpty ||
               !instagram.isEmpty || !facebook.isEmpty || !youtube.isEmpty
    }

    /// Create an AuthorModel from current settings
    func createAuthorModel() -> AuthorModel? {
        guard hasAuthorInfo else { return nil }

        return AuthorModel(
            name: name.isEmpty ? nil : name,
            email: email.isEmpty ? nil : email,
            website: website.isEmpty ? nil : website,
            instagram: instagram.isEmpty ? nil : instagram,
            facebook: facebook.isEmpty ? nil : facebook,
            youtube: youtube.isEmpty ? nil : youtube
        )
    }

    private func save() {
        let data: [String: String] = [
            "name": name,
            "email": email,
            "website": website,
            "instagram": instagram,
            "facebook": facebook,
            "youtube": youtube
        ]

        if let encoded = try? JSONEncoder().encode(data) {
            defaults.set(encoded, forKey: key)
        }
    }

    private func load() {
        guard let data = defaults.data(forKey: key),
              let decoded = try? JSONDecoder().decode([String: String].self, from: data) else {
            return
        }

        name = decoded["name"] ?? ""
        email = decoded["email"] ?? ""
        website = decoded["website"] ?? ""
        instagram = decoded["instagram"] ?? ""
        facebook = decoded["facebook"] ?? ""
        youtube = decoded["youtube"] ?? ""
    }

    /// Clear all author information
    func clear() {
        name = ""
        email = ""
        website = ""
        instagram = ""
        facebook = ""
        youtube = ""
    }
}

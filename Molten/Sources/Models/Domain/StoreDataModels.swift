//
//  StoreDataModels.swift
//  Flameworker
//
//  Created for Store Feature on 10/26/25.
//

import Foundation

// MARK: - Metadata Models

/// Metadata about the stores JSON file for debugging and version tracking
nonisolated struct StoreMetadata: Codable, Sendable {
    let version: String
    let generated: String  // ISO 8601 timestamp
    let storeCount: Int?   // Optional for backward compatibility

    enum CodingKeys: String, CodingKey {
        case version
        case generated
        case storeCount = "store_count"
    }
}

// MARK: - JSON Wrapper Structures

/// Expected JSON format: { "version": "1.0", "generated": "...", "store_count": 10, "stores": [...] }
nonisolated struct WrappedStoresData: Codable, Sendable {
    let metadata: StoreMetadata
    let stores: [StoreData]

    nonisolated init(metadata: StoreMetadata, stores: [StoreData]) {
        self.metadata = metadata
        self.stores = stores
    }

    nonisolated init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        // Extract metadata
        let version = try container.decode(String.self, forKey: .version)
        let generated = try container.decode(String.self, forKey: .generated)
        let storeCount = try? container.decode(Int.self, forKey: .storeCount)

        self.metadata = StoreMetadata(version: version, generated: generated, storeCount: storeCount)
        self.stores = try container.decode([StoreData].self, forKey: .stores)
    }

    nonisolated func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encode(metadata.version, forKey: .version)
        try container.encode(metadata.generated, forKey: .generated)
        try container.encodeIfPresent(metadata.storeCount, forKey: .storeCount)
        try container.encode(stores, forKey: .stores)
    }

    enum CodingKeys: String, CodingKey {
        case version
        case generated
        case storeCount = "store_count"
        case stores
    }
}

// MARK: - Store Data Model

/// Data transfer object for decoding stores from JSON
nonisolated struct StoreData: Codable, Sendable {
    let stable_id: String
    let name: String
    let address_line1: String?
    let address_line2: String?
    let city: String?
    let state: String?
    let zip: String?
    let latitude: Double?
    let longitude: Double?
    let website_url: String?
    let phone: String?
    let hours_json: String?
    let hero_image_path: String?
    let notes: String?
    let is_verified: Bool?

    // Technique support fields
    let supports_casting: Bool?
    let supports_flameworking_hard: Bool?
    let supports_flameworking_soft: Bool?
    let supports_fusing: Bool?
    let supports_glass_blowing: Bool?
    let supports_stained_glass: Bool?
    let supports_other: Bool?

    // Custom initializer to handle different JSON structures
    nonisolated init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        // Required fields
        self.stable_id = try container.decode(String.self, forKey: .stable_id)
        self.name = try container.decode(String.self, forKey: .name)

        // Optional address fields
        self.address_line1 = try? container.decode(String.self, forKey: .address_line1)
        self.address_line2 = try? container.decode(String.self, forKey: .address_line2)
        self.city = try? container.decode(String.self, forKey: .city)
        self.state = try? container.decode(String.self, forKey: .state)
        self.zip = try? container.decode(String.self, forKey: .zip)

        // Optional location fields - handle both Double and String
        if let lat = try? container.decode(Double.self, forKey: .latitude) {
            self.latitude = lat
        } else if let latString = try? container.decode(String.self, forKey: .latitude),
                  let lat = Double(latString) {
            self.latitude = lat
        } else {
            self.latitude = nil
        }

        if let lon = try? container.decode(Double.self, forKey: .longitude) {
            self.longitude = lon
        } else if let lonString = try? container.decode(String.self, forKey: .longitude),
                  let lon = Double(lonString) {
            self.longitude = lon
        } else {
            self.longitude = nil
        }

        // Optional contact fields
        self.website_url = try? container.decode(String.self, forKey: .website_url)
        self.phone = try? container.decode(String.self, forKey: .phone)
        self.hours_json = try? container.decode(String.self, forKey: .hours_json)

        // Optional metadata fields
        self.hero_image_path = try? container.decode(String.self, forKey: .hero_image_path)
        self.notes = try? container.decode(String.self, forKey: .notes)
        self.is_verified = try? container.decode(Bool.self, forKey: .is_verified)

        // Optional technique fields
        self.supports_casting = try? container.decode(Bool.self, forKey: .supports_casting)
        self.supports_flameworking_hard = try? container.decode(Bool.self, forKey: .supports_flameworking_hard)
        self.supports_flameworking_soft = try? container.decode(Bool.self, forKey: .supports_flameworking_soft)
        self.supports_fusing = try? container.decode(Bool.self, forKey: .supports_fusing)
        self.supports_glass_blowing = try? container.decode(Bool.self, forKey: .supports_glass_blowing)
        self.supports_stained_glass = try? container.decode(Bool.self, forKey: .supports_stained_glass)
        self.supports_other = try? container.decode(Bool.self, forKey: .supports_other)
    }

    // Regular initializer for programmatic creation
    nonisolated init(
        stable_id: String,
        name: String,
        address_line1: String? = nil,
        address_line2: String? = nil,
        city: String? = nil,
        state: String? = nil,
        zip: String? = nil,
        latitude: Double? = nil,
        longitude: Double? = nil,
        website_url: String? = nil,
        phone: String? = nil,
        hours_json: String? = nil,
        hero_image_path: String? = nil,
        notes: String? = nil,
        is_verified: Bool? = nil,
        supports_casting: Bool? = nil,
        supports_flameworking_hard: Bool? = nil,
        supports_flameworking_soft: Bool? = nil,
        supports_fusing: Bool? = nil,
        supports_glass_blowing: Bool? = nil,
        supports_stained_glass: Bool? = nil,
        supports_other: Bool? = nil
    ) {
        self.stable_id = stable_id
        self.name = name
        self.address_line1 = address_line1
        self.address_line2 = address_line2
        self.city = city
        self.state = state
        self.zip = zip
        self.latitude = latitude
        self.longitude = longitude
        self.website_url = website_url
        self.phone = phone
        self.hours_json = hours_json
        self.hero_image_path = hero_image_path
        self.notes = notes
        self.is_verified = is_verified
        self.supports_casting = supports_casting
        self.supports_flameworking_hard = supports_flameworking_hard
        self.supports_flameworking_soft = supports_flameworking_soft
        self.supports_fusing = supports_fusing
        self.supports_glass_blowing = supports_glass_blowing
        self.supports_stained_glass = supports_stained_glass
        self.supports_other = supports_other
    }

    nonisolated func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encode(stable_id, forKey: .stable_id)
        try container.encode(name, forKey: .name)
        try container.encodeIfPresent(address_line1, forKey: .address_line1)
        try container.encodeIfPresent(address_line2, forKey: .address_line2)
        try container.encodeIfPresent(city, forKey: .city)
        try container.encodeIfPresent(state, forKey: .state)
        try container.encodeIfPresent(zip, forKey: .zip)
        try container.encodeIfPresent(latitude, forKey: .latitude)
        try container.encodeIfPresent(longitude, forKey: .longitude)
        try container.encodeIfPresent(website_url, forKey: .website_url)
        try container.encodeIfPresent(phone, forKey: .phone)
        try container.encodeIfPresent(hours_json, forKey: .hours_json)
        try container.encodeIfPresent(hero_image_path, forKey: .hero_image_path)
        try container.encodeIfPresent(notes, forKey: .notes)
        try container.encodeIfPresent(is_verified, forKey: .is_verified)
        try container.encodeIfPresent(supports_casting, forKey: .supports_casting)
        try container.encodeIfPresent(supports_flameworking_hard, forKey: .supports_flameworking_hard)
        try container.encodeIfPresent(supports_flameworking_soft, forKey: .supports_flameworking_soft)
        try container.encodeIfPresent(supports_fusing, forKey: .supports_fusing)
        try container.encodeIfPresent(supports_glass_blowing, forKey: .supports_glass_blowing)
        try container.encodeIfPresent(supports_stained_glass, forKey: .supports_stained_glass)
        try container.encodeIfPresent(supports_other, forKey: .supports_other)
    }

    // Custom keys mapping for different JSON field names
    enum CodingKeys: String, CodingKey {
        case stable_id = "stable_id"
        case name = "name"
        case address_line1 = "address_line1"
        case address_line2 = "address_line2"
        case city = "city"
        case state = "state"
        case zip = "zip"
        case latitude = "latitude"
        case longitude = "longitude"
        case website_url = "website_url"
        case phone = "phone"
        case hours_json = "hours_json"
        case hero_image_path = "hero_image_path"
        case notes = "notes"
        case is_verified = "is_verified"
        case supports_casting = "supports_casting"
        case supports_flameworking_hard = "supports_flameworking_hard"
        case supports_flameworking_soft = "supports_flameworking_soft"
        case supports_fusing = "supports_fusing"
        case supports_glass_blowing = "supports_glass_blowing"
        case supports_stained_glass = "supports_stained_glass"
        case supports_other = "supports_other"

        // Alternative key names (camelCase variants)
        case stableId = "stableId"
        case addressLine1 = "addressLine1"
        case addressLine2 = "addressLine2"
        case websiteUrl = "websiteUrl"
        case hoursJson = "hoursJson"
        case heroImagePath = "heroImagePath"
        case isVerified = "isVerified"
    }
}

// MARK: - Conversion Extensions

extension StoreData {
    /// Convert StoreData to StoreModel
    nonisolated func toModel() -> StoreModel {
        return StoreModel(
            stable_id: stable_id,
            name: name,
            addressLine1: address_line1,
            addressLine2: address_line2,
            city: city,
            state: state,
            zip: zip,
            latitude: latitude ?? 0.0,
            longitude: longitude ?? 0.0,
            websiteUrl: website_url,
            phone: phone,
            hoursJson: hours_json,
            heroImagePath: hero_image_path,
            notes: notes,
            isVerified: is_verified ?? false,
            supportsCasting: supports_casting ?? false,
            supportsFlameworkingHard: supports_flameworking_hard ?? false,
            supportsFlameworkingSoft: supports_flameworking_soft ?? false,
            supportsFusing: supports_fusing ?? false,
            supportsGlassBlowing: supports_glass_blowing ?? false,
            supportsStainedGlass: supports_stained_glass ?? false,
            supportsOther: supports_other ?? false
        )
    }
}

extension StoreModel {
    /// Convert StoreModel to StoreData
    nonisolated func toData() -> StoreData {
        return StoreData(
            stable_id: stable_id,
            name: name,
            address_line1: addressLine1,
            address_line2: addressLine2,
            city: city,
            state: state,
            zip: zip,
            latitude: hasValidLocation ? latitude : nil,
            longitude: hasValidLocation ? longitude : nil,
            website_url: websiteUrl,
            phone: phone,
            hours_json: hoursJson,
            hero_image_path: heroImagePath,
            notes: notes,
            is_verified: isVerified,
            supports_casting: supportsCasting,
            supports_flameworking_hard: supportsFlameworkingHard,
            supports_flameworking_soft: supportsFlameworkingSoft,
            supports_fusing: supportsFusing,
            supports_glass_blowing: supportsGlassBlowing,
            supports_stained_glass: supportsStainedGlass,
            supports_other: supportsOther
        )
    }
}

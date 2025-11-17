//
//  ExpiringShare.swift
//  Molten
//
//  Model for expiring inventory share aliases
//  These are time-limited aliases to the main share that cannot be extended
//

import Foundation

/// An expiring share code that aliases the user's main inventory share
/// - Each expiring share has its own code, display name, and notes
/// - All expiring shares reference the same inventory snapshot as the main share
/// - Expiring shares are automatically deleted when they expire or when the main share is deleted
public struct ExpiringShare: Identifiable, Codable, Sendable {
    public let id: UUID
    public let shareCode: String  // 6-character code (e.g., "ABC123")
    public let mainShareCode: String  // Reference to the main share
    public let displayName: String  // Display name for this specific share
    public let shareNotes: String?  // Notes for this specific share
    public let expiresAt: Date  // When this share expires (cannot be extended)
    public let createdAt: Date  // When this share was created

    public init(
        id: UUID = UUID(),
        shareCode: String,
        mainShareCode: String,
        displayName: String,
        shareNotes: String? = nil,
        expiresAt: Date,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.shareCode = shareCode
        self.mainShareCode = mainShareCode
        self.displayName = displayName
        self.shareNotes = shareNotes
        self.expiresAt = expiresAt
        self.createdAt = createdAt
    }

    /// Check if this share has expired
    public var isExpired: Bool {
        return Date() > expiresAt
    }

    /// Time remaining until expiration
    public var timeRemaining: TimeInterval {
        return expiresAt.timeIntervalSinceNow
    }

    /// Formatted expiration display (e.g., "Expires in 2 days")
    public var expirationDisplayString: String {
        if isExpired {
            return "Expired"
        }

        let remaining = timeRemaining
        let days = Int(remaining / 86400)
        let hours = Int((remaining.truncatingRemainder(dividingBy: 86400)) / 3600)

        if days > 0 {
            return "Expires in \(days) day\(days == 1 ? "" : "s")"
        } else if hours > 0 {
            return "Expires in \(hours) hour\(hours == 1 ? "" : "s")"
        } else {
            let minutes = Int((remaining.truncatingRemainder(dividingBy: 3600)) / 60)
            return "Expires in \(minutes) minute\(minutes == 1 ? "" : "s")"
        }
    }
}

/// Expiration duration configuration for creating expiring shares
public struct ExpiringShareDuration {
    public let days: Int
    public let hours: Int

    public init(days: Int, hours: Int) {
        self.days = days
        self.hours = hours
    }

    /// Time interval in seconds
    public var timeInterval: TimeInterval {
        return TimeInterval((days * 24 * 3600) + (hours * 3600))
    }

    /// Calculate expiration date from now
    public func expirationDate(from date: Date = Date()) -> Date {
        return date.addingTimeInterval(timeInterval)
    }

    /// Validate duration (minimum 1 hour, maximum 30 days + 23 hours)
    public var isValid: Bool {
        let totalHours = (days * 24) + hours
        return totalHours >= 1 && totalHours <= (30 * 24 + 23)
    }
}

/// Server response for expiring share records
public struct ExpiringShareServerResponse: Codable, Sendable {
    public let shareCode: String
    public let displayName: String
    public let shareNotes: String?
    public let expiresAt: Date
    public let createdAt: Date

    public init(
        shareCode: String,
        displayName: String,
        shareNotes: String?,
        expiresAt: Date,
        createdAt: Date
    ) {
        self.shareCode = shareCode
        self.displayName = displayName
        self.shareNotes = shareNotes
        self.expiresAt = expiresAt
        self.createdAt = createdAt
    }
}

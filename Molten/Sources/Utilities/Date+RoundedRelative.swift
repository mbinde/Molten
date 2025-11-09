//
//  Date+RoundedRelative.swift
//  Molten
//
//  Provides rounded relative time formatting for dates
//

import Foundation

extension Date {
    /// Returns a rounded relative time string
    /// - Returns: Rounded time like "< 1 minute", "3 hours", "2 days", "1 week"
    func roundedRelativeString() -> String {
        let now = Date()
        let seconds = now.timeIntervalSince(self)

        // Less than a minute
        if seconds < 60 {
            return "< 1 minute"
        }

        // Less than an hour
        if seconds < 3600 {
            return "< 1 hour"
        }

        // Hours (1-23)
        if seconds < 86400 {
            let hours = Int(seconds / 3600)
            return hours == 1 ? "1 hour" : "\(hours) hours"
        }

        // Days (1-6)
        if seconds < 604800 {
            let days = Int(seconds / 86400)
            return days == 1 ? "1 day" : "\(days) days"
        }

        // Weeks
        let weeks = Int(seconds / 604800)
        return weeks == 1 ? "1 week" : "\(weeks) weeks"
    }
}

//
//  Logger+Categories.swift
//  Flameworker
//
//  Created by Assistant on 9/29/25.
//

import Foundation
import OSLog

/// Centralized Logger categories for structured logging.
///
/// Usage:
///   let log = Logger.dataLoading
///   log.info("Starting load…")
extension Logger {
    private static var subsystem: String {
        // Fall back to a stable identifier if bundle identifier is unavailable in tests
        Bundle.main.bundleIdentifier ?? "com.example.Flameworker"
    }

    static let app = Logger(subsystem: subsystem, category: "App")
    static let dataLoading = Logger(subsystem: subsystem, category: "DataLoading")
    static let haptics = Logger(subsystem: subsystem, category: "Haptics")
    static let persistence = Logger(subsystem: subsystem, category: "Persistence")
}

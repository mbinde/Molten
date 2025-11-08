//
//  MyShareMetadata.swift
//  Molten
//
//  Metadata for user's own share
//

import Foundation

/// Metadata that the user shares publicly with their inventory
public struct MyShareMetadata: Codable {
    public let displayName: String  // Name shown to people viewing your share
    public let shareNotes: String?  // Public notes visible to recipients

    public init(displayName: String, shareNotes: String? = nil) {
        self.displayName = displayName
        self.shareNotes = shareNotes
    }
}

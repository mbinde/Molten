//
//  DownloadedSnapshot.swift
//  Molten
//
//  Result of downloading an inventory snapshot from the server
//

import Foundation

/// Result of downloading an inventory snapshot
public struct DownloadedSnapshot {
    public let snapshotData: Data
    public let publicKey: Data

    public init(snapshotData: Data, publicKey: Data) {
        self.snapshotData = snapshotData
        self.publicKey = publicKey
    }
}

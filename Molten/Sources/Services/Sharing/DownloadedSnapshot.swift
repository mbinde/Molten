//
//  DownloadedSnapshot.swift
//  Molten
//
//  Result of downloading an inventory snapshot from the server
//

import Foundation

/// Result of downloading an inventory snapshot
struct DownloadedSnapshot {
    let snapshotData: Data
    let publicKey: Data

    init(snapshotData: Data, publicKey: Data) {
        self.snapshotData = snapshotData
        self.publicKey = publicKey
    }
}

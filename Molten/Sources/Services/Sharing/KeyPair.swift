//
//  KeyPair.swift
//  Molten
//
//  Data model for cryptographic key pairs
//

import Foundation

/// Represents a cryptographic key pair (public + private)
struct KeyPair: Equatable {
    let publicKey: Data
    let privateKey: Data
}

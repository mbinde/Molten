//
//  KeyPairError.swift
//  Molten
//
//  Errors for key pair management
//

import Foundation

/// Errors that can occur during key pair operations
enum KeyPairError: Error, LocalizedError {
    case generationFailed
    case keychainError(String)
    case invalidBase64
    case invalidKeyLength
    case keyNotFound

    var errorDescription: String? {
        switch self {
        case .generationFailed:
            return "Failed to generate key pair"
        case .keychainError(let message):
            return "Keychain error: \(message)"
        case .invalidBase64:
            return "Invalid base64 encoding"
        case .invalidKeyLength:
            return "Invalid key length (expected 32 bytes)"
        case .keyNotFound:
            return "Key not found in Keychain"
        }
    }
}

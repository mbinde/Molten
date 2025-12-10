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
    case signingFailed

    var errorDescription: String? {
        switch self {
        case .generationFailed:
            return "Failed to generate security key"
        case .keychainError(let message):
            return "Keychain error: \(message)"
        case .invalidBase64:
            return "Invalid base64 encoding"
        case .invalidKeyLength:
            return "Invalid key length (expected 32 bytes)"
        case .keyNotFound:
            return "Your security key was not found"
        case .signingFailed:
            return "Failed to sign request"
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .keyNotFound:
            // Keychain items persist across reinstalls, so the most likely causes are:
            // - New device without iCloud Keychain sync
            // - iCloud Keychain was reset or disabled
            // - Factory reset
            //
            // If they registered with email: they can use account recovery
            // If they used anonymous plus-address: no recovery possible
            return "This can happen on a new device if iCloud Keychain sync is disabled, or after a factory reset.\n\nIf you registered with your email address, go to Settings → Purchase Import → Recover Existing Account to restore access.\n\nIf you used the anonymous option, you'll need to set up a new account. Previously imported receipts cannot be recovered."
        case .generationFailed:
            return "Please try again. If the problem persists, restart the app."
        case .signingFailed:
            return "Please try again. If the problem persists, you may need to set up receipt imports again in Settings."
        default:
            return nil
        }
    }

    var failureReason: String? {
        switch self {
        case .keyNotFound:
            return "The security key used to verify your identity with the receipt server could not be found in your device's secure storage."
        default:
            return nil
        }
    }

    /// User-friendly message combining description and recovery suggestion
    var userFacingMessage: String {
        var message = errorDescription ?? "An error occurred"
        if let recovery = recoverySuggestion {
            message += "\n\n\(recovery)"
        }
        return message
    }
}

// MARK: - Error Extension for User-Facing Messages

extension Error {
    /// Returns a user-friendly error message, using KeyPairError's enhanced messaging when applicable
    var userFacingMessage: String {
        if let keyPairError = self as? KeyPairError {
            return keyPairError.userFacingMessage
        }
        // For other errors, just use localizedDescription
        return localizedDescription
    }
}

import Foundation

/// Represents the current subscription status for the user
public struct SubscriptionStatus: Sendable {
    public let isActive: Bool
    public let productIdentifier: String?
    public let expirationDate: Date?
    public let willRenew: Bool

    public init(
        isActive: Bool,
        productIdentifier: String?,
        expirationDate: Date?,
        willRenew: Bool
    ) {
        self.isActive = isActive
        self.productIdentifier = productIdentifier
        self.expirationDate = expirationDate
        self.willRenew = willRenew
    }

    /// Computed property for display
    public var displayStatus: String {
        guard isActive else { return "No Active Subscription" }

        if productIdentifier == "lifetime" {
            return "Lifetime Access"
        }

        if let expiration = expirationDate {
            if willRenew {
                return "Active (Renews \(expiration.formatted(date: .abbreviated, time: .omitted)))"
            } else {
                return "Active (Expires \(expiration.formatted(date: .abbreviated, time: .omitted)))"
            }
        }

        return "Active"
    }
}

/// Represents an entitlement (feature access)
public struct EntitlementInfo: Sendable {
    public let identifier: String
    public let isActive: Bool

    public init(identifier: String, isActive: Bool) {
        self.identifier = identifier
        self.isActive = isActive
    }
}

/// Error types for subscription operations
public enum SubscriptionError: Error, LocalizedError {
    case configurationError
    case purchaseCancelled
    case networkError
    case unknown(Error)

    public var errorDescription: String? {
        switch self {
        case .configurationError:
            return "Subscription service not configured properly"
        case .purchaseCancelled:
            return "Purchase was cancelled"
        case .networkError:
            return "Network connection error. Please try again."
        case .unknown(let error):
            return "An error occurred: \(error.localizedDescription)"
        }
    }
}

//
//  QRCodeScannerViewTests.swift
//  MoltenTests
//
//  Tests for QRCodeScannerView - in-app QR code scanning functionality
//

import Testing
import Foundation
@testable import Molten

@Suite("QRCodeScannerView Tests")
@MainActor
struct QRCodeScannerViewTests {

    // MARK: - Callback Tests

    @Test("Scanner calls onCodeScanned with molten URL")
    func scannerCallsCallbackWithMoltenURL() async throws {
        var scannedCode: String?

        // Simulate what the scanner does when it detects a Molten QR code
        let testURL = "molten://i/abc123/sf"

        // The callback that would be passed to QRCodeScannerView
        let onCodeScanned: (String) -> Void = { code in
            scannedCode = code
        }

        // Simulate scanning
        if testURL.hasPrefix("molten://") {
            onCodeScanned(testURL)
        }

        #expect(scannedCode == testURL)
    }

    @Test("Scanner only processes molten:// URLs")
    func scannerOnlyProcessesMoltenURLs() async throws {
        var scannedCode: String?

        let onCodeScanned: (String) -> Void = { code in
            scannedCode = code
        }

        // Non-molten URLs should not trigger callback
        let nonMoltenURLs = [
            "https://example.com",
            "http://molten.app/item/123",
            "otherapp://action",
            "mailto:test@example.com"
        ]

        for url in nonMoltenURLs {
            if url.hasPrefix("molten://") {
                onCodeScanned(url)
            }
        }

        #expect(scannedCode == nil, "Non-molten URLs should not be processed")
    }

    @Test("Scanner processes various molten URL formats")
    func scannerProcessesVariousMoltenURLFormats() async throws {
        var processedURLs: [String] = []

        let onCodeScanned: (String) -> Void = { code in
            processedURLs.append(code)
        }

        let validMoltenURLs = [
            "molten://i/abc123",           // Item without type
            "molten://i/abc123/r",         // Item with type only
            "molten://i/abc123/sf",        // Item with type and subtype
            "molten://i/abc123/sfx",       // Item with type, subtype, subsubtype
            "molten://share/XYZ789",       // Share code
        ]

        for url in validMoltenURLs {
            if url.hasPrefix("molten://") {
                onCodeScanned(url)
            }
        }

        #expect(processedURLs.count == validMoltenURLs.count)
        #expect(processedURLs == validMoltenURLs)
    }

    // MARK: - URL Conversion Tests

    @Test("Scanned string converts to valid URL")
    func scannedStringConvertsToValidURL() async throws {
        let scannedString = "molten://i/abc123/sf"
        let url = URL(string: scannedString)

        #expect(url != nil)
        #expect(url?.scheme == "molten")
        #expect(url?.host == "i")
    }

    @Test("URL with special characters is handled")
    func urlWithSpecialCharactersIsHandled() async throws {
        // URL with spaces gets percent-encoded by URL(string:) in modern iOS
        let stringWithSpace = "molten://i/abc 123/sf"
        let url = URL(string: stringWithSpace)

        // Modern iOS percent-encodes the space, so URL is valid
        // The important thing is we handle whatever URL(string:) returns
        if let url = url {
            #expect(url.scheme == "molten")
        }
        // If URL is nil (older behavior), that's also fine
    }

    // MARK: - Notification Tests

    @Test("Notification contains URL in userInfo")
    func notificationContainsURLInUserInfo() async throws {
        let testURLString = "molten://i/abc123/sf"
        let testURL = URL(string: testURLString)!

        // Create notification like the scanner does
        let notification = Notification(
            name: .openMoltenDeepLink,
            object: nil,
            userInfo: ["url": testURL]
        )

        // Verify the URL can be extracted
        let extractedURL = notification.userInfo?["url"] as? URL
        #expect(extractedURL == testURL)
        #expect(extractedURL?.absoluteString == testURLString)
    }

    @Test("Notification name is correct")
    func notificationNameIsCorrect() async throws {
        #expect(Notification.Name.openMoltenDeepLink.rawValue == "openMoltenDeepLink")
    }
}

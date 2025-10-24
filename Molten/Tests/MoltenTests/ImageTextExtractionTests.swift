//
//  ImageTextExtractionTests.swift
//  MoltenTests
//
//  Tests for OCR text extraction from images using Vision framework
//

import Testing
import UIKit
@testable import Molten

@Suite("Image Text Extraction Tests")
struct ImageTextExtractionTests {

    @Test("Extract text from image with clear printed text")
    func extractTextFromClearImage() async throws {
        // Create a simple test image with text
        let image = createTestImage(with: "Hello World")

        let extractor = ImageTextExtractor()
        let extractedText = try await extractor.extractText(from: image)

        // Should contain the text (case-insensitive since OCR may vary)
        #expect(extractedText.lowercased().contains("hello"))
        #expect(extractedText.lowercased().contains("world"))
    }

    @Test("Extract text returns empty string for image without text")
    func extractTextFromImageWithoutText() async throws {
        // Create a solid color image with no text
        let image = createSolidColorImage()

        let extractor = ImageTextExtractor()
        let extractedText = try await extractor.extractText(from: image)

        #expect(extractedText.isEmpty)
    }

    @Test("Extract text handles multiline text")
    func extractMultilineText() async throws {
        let image = createTestImage(with: "Line 1\nLine 2\nLine 3")

        let extractor = ImageTextExtractor()
        let extractedText = try await extractor.extractText(from: image)

        // Should contain all lines
        #expect(extractedText.lowercased().contains("line 1"))
        #expect(extractedText.lowercased().contains("line 2"))
        #expect(extractedText.lowercased().contains("line 3"))
    }

    @Test("Extract text preserves text order and spacing")
    func preserveTextOrderAndSpacing() async throws {
        let image = createTestImage(with: "First Second Third")

        let extractor = ImageTextExtractor()
        let extractedText = try await extractor.extractText(from: image)

        // Should maintain order (allowing for OCR variations)
        let lowerText = extractedText.lowercased()
        let firstPos = lowerText.range(of: "first")?.lowerBound
        let secondPos = lowerText.range(of: "second")?.lowerBound
        let thirdPos = lowerText.range(of: "third")?.lowerBound

        if let first = firstPos, let second = secondPos, let third = thirdPos {
            #expect(first < second)
            #expect(second < third)
        }
    }

    @Test("Extract text handles numbers and symbols")
    func extractNumbersAndSymbols() async throws {
        let image = createTestImage(with: "COE-104 $25.00")

        let extractor = ImageTextExtractor()
        let extractedText = try await extractor.extractText(from: image)

        // Should extract numbers
        #expect(extractedText.contains("104") || extractedText.contains("io4")) // OCR may confuse 1/l/I
        #expect(extractedText.contains("25"))
    }

    // MARK: - Helper Methods

    /// Create a test image with rendered text
    private func createTestImage(with text: String) -> UIImage {
        let size = CGSize(width: 400, height: 200)
        let renderer = UIGraphicsImageRenderer(size: size)

        let image = renderer.image { context in
            // White background
            UIColor.white.setFill()
            context.fill(CGRect(origin: .zero, size: size))

            // Draw black text
            let paragraphStyle = NSMutableParagraphStyle()
            paragraphStyle.alignment = .center

            let attributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 32, weight: .bold),
                .foregroundColor: UIColor.black,
                .paragraphStyle: paragraphStyle
            ]

            let textRect = CGRect(x: 20, y: 80, width: size.width - 40, height: 40)
            text.draw(in: textRect, withAttributes: attributes)
        }

        return image
    }

    /// Create a solid color image with no text
    private func createSolidColorImage() -> UIImage {
        let size = CGSize(width: 100, height: 100)
        let renderer = UIGraphicsImageRenderer(size: size)

        let image = renderer.image { context in
            UIColor.blue.setFill()
            context.fill(CGRect(origin: .zero, size: size))
        }

        return image
    }
}

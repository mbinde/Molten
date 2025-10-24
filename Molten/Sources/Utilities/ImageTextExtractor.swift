//
//  ImageTextExtractor.swift
//  Molten
//
//  Utility for extracting text from images using Vision framework OCR
//

import Foundation
import UIKit
import Vision

/// Extracts text from images using Vision framework's OCR capabilities
struct ImageTextExtractor: Sendable {

    /// Extract all text found in an image
    /// - Parameter image: The UIImage to analyze
    /// - Returns: Extracted text as a single string (observations joined by spaces)
    /// - Throws: Vision framework errors or if image conversion fails
    nonisolated func extractText(from image: UIImage) async throws -> String {
        guard let cgImage = image.cgImage else {
            return ""
        }

        return try await withCheckedThrowingContinuation { continuation in
            // Create text recognition request
            let request = VNRecognizeTextRequest { request, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }

                guard let observations = request.results as? [VNRecognizedTextObservation] else {
                    continuation.resume(returning: "")
                    return
                }

                // Extract text from all observations
                let recognizedStrings = observations.compactMap { observation in
                    observation.topCandidates(1).first?.string
                }

                // Join with spaces (observations are typically in reading order)
                let fullText = recognizedStrings.joined(separator: " ")
                continuation.resume(returning: fullText)
            }

            // Configure for optimal accuracy
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true

            // Perform the request
            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }

    /// Extract text with detailed information about text regions
    /// - Parameter image: The UIImage to analyze
    /// - Returns: Array of recognized text observations with confidence and bounding boxes
    /// - Throws: Vision framework errors or if image conversion fails
    nonisolated func extractTextWithDetails(from image: UIImage) async throws -> [RecognizedText] {
        guard let cgImage = image.cgImage else {
            return []
        }

        return try await withCheckedThrowingContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }

                guard let observations = request.results as? [VNRecognizedTextObservation] else {
                    continuation.resume(returning: [])
                    return
                }

                // Map observations to structured data
                let recognizedTexts = observations.compactMap { observation -> RecognizedText? in
                    guard let candidate = observation.topCandidates(1).first else {
                        return nil
                    }

                    return RecognizedText(
                        text: candidate.string,
                        confidence: candidate.confidence,
                        boundingBox: observation.boundingBox
                    )
                }

                continuation.resume(returning: recognizedTexts)
            }

            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true

            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }
}

/// Represents a piece of recognized text with metadata
struct RecognizedText: Sendable {
    let text: String
    let confidence: Float  // 0.0 to 1.0
    let boundingBox: CGRect  // Normalized coordinates (0.0 to 1.0)
}

/// Errors specific to text extraction
enum ImageTextExtractionError: Error, LocalizedError {
    case invalidImage
    case visionRequestFailed(String)

    var errorDescription: String? {
        switch self {
        case .invalidImage:
            return "Could not process image for text recognition"
        case .visionRequestFailed(let reason):
            return "Text recognition failed: \(reason)"
        }
    }
}

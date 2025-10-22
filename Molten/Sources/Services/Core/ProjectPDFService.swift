//
//  ProjectPDFService.swift
//  Molten
//
//  Service for exporting project plans as PDF documents
//

import UIKit
import SwiftUI

/// Service for generating PDF documents from project plans
actor ProjectPDFService {
    private let userImageRepository: UserImageRepository

    init(userImageRepository: UserImageRepository) {
        self.userImageRepository = userImageRepository
    }

    /// Export a project plan as a PDF file
    /// - Parameter plan: The plan to export
    /// - Returns: URL to the generated PDF file in temporary storage
    func exportPlanAsPDF(_ plan: ProjectModel) async throws -> URL {
        // Create temporary file URL
        let tempDir = FileManager.default.temporaryDirectory
        let fileName = sanitizeFilename(plan.title) + ".pdf"
        let fileURL = tempDir.appendingPathComponent(fileName)

        // Remove existing file if present
        try? FileManager.default.removeItem(at: fileURL)

        // Load images from UserImageRepository
        var loadedImages: [UUID: UIImage] = [:]
        let allPlanImages = try await userImageRepository.getImages(
            ownerType: .projectPlan,
            ownerId: plan.id.uuidString
        )

        for userImageModel in allPlanImages {
            if let image = try? await userImageRepository.loadImage(userImageModel) {
                loadedImages[userImageModel.id] = image
            }
        }

        // Generate PDF
        let pdfRenderer = UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: 612, height: 792)) // US Letter size

        let data = pdfRenderer.pdfData { context in
            var yPosition: CGFloat = 50
            let leftMargin: CGFloat = 50
            let rightMargin: CGFloat = 50
            let pageWidth: CGFloat = 612
            let contentWidth = pageWidth - leftMargin - rightMargin

            // Helper to draw footer on current page
            func drawFooter() {
                let footerText = "Exported by the Molten iOS app • http://moltenglass.app/"
                _ = drawText(
                    footerText,
                    at: CGPoint(x: leftMargin, y: 762),
                    width: contentWidth,
                    font: .systemFont(ofSize: 8),
                    color: .lightGray,
                    alignment: .center,
                    context: context.cgContext
                )
            }

            context.beginPage()

            // Title
            yPosition = drawText(
                plan.title,
                at: CGPoint(x: leftMargin, y: yPosition),
                width: contentWidth,
                font: .boldSystemFont(ofSize: 24),
                context: context.cgContext
            )
            yPosition += 20

            // Plan Type and COE (only show if meaningful)
            var metadataParts: [String] = []

            // Only show plan type if it's not the default "idea" type
            if plan.type != .idea {
                metadataParts.append(plan.type.displayName)
            }

            // Only show COE if it's not "any"
            if plan.coe.lowercased() != "any" {
                metadataParts.append("COE \(plan.coe)")
            }

            if !metadataParts.isEmpty {
                let metadata = metadataParts.joined(separator: " • ")
                yPosition = drawText(
                    metadata,
                    at: CGPoint(x: leftMargin, y: yPosition),
                    width: contentWidth,
                    font: .systemFont(ofSize: 12),
                    color: .gray,
                    context: context.cgContext
                )
                yPosition += 20
            }

            // Author Card (if present)
            if let author = plan.author {
                yPosition = drawAuthorCard(
                    author,
                    at: CGPoint(x: leftMargin, y: yPosition),
                    width: contentWidth,
                    context: context.cgContext
                )
                yPosition += 20
            }

            // Primary Image (at the top, right after metadata)
            if let heroImageId = plan.heroImageId,
               let heroImage = loadedImages[heroImageId] {
                // Check if we need a new page for the image
                if yPosition > 550 {
                    drawFooter()
                    context.beginPage()
                    yPosition = 50
                }

                // Draw image with aspect fit
                let maxImageHeight: CGFloat = 300
                let imageSize = heroImage.size
                let aspectRatio = imageSize.width / imageSize.height

                var drawWidth = contentWidth
                var drawHeight = drawWidth / aspectRatio

                if drawHeight > maxImageHeight {
                    drawHeight = maxImageHeight
                    drawWidth = drawHeight * aspectRatio
                }

                let imageRect = CGRect(
                    x: leftMargin + (contentWidth - drawWidth) / 2,
                    y: yPosition,
                    width: drawWidth,
                    height: drawHeight
                )

                heroImage.draw(in: imageRect)
                yPosition += drawHeight + 20
            }

            // Summary
            if let summary = plan.summary {
                yPosition = drawSectionHeader(
                    "Summary",
                    at: CGPoint(x: leftMargin, y: yPosition),
                    context: context.cgContext
                )
                yPosition += 10

                yPosition = drawText(
                    summary,
                    at: CGPoint(x: leftMargin, y: yPosition),
                    width: contentWidth,
                    font: .systemFont(ofSize: 12),
                    context: context.cgContext
                )
                yPosition += 20
            }

            // Glass Items
            if !plan.glassItems.isEmpty {
                yPosition = drawSectionHeader(
                    "Glass Needed",
                    at: CGPoint(x: leftMargin, y: yPosition),
                    context: context.cgContext
                )
                yPosition += 10

                for item in plan.glassItems {
                    // Check if we need a new page
                    if yPosition > 720 {
                        drawFooter()
                        context.beginPage()
                        yPosition = 50
                    }

                    // Get display name directly from properties to avoid concurrency issues
                    let displayName: String
                    if let naturalKey = item.naturalKey {
                        displayName = naturalKey
                    } else if let freeformDescription = item.freeformDescription {
                        displayName = freeformDescription
                    } else {
                        displayName = "Unknown glass"
                    }

                    let itemText = "• \(displayName) - \(item.quantity) \(item.unit)"
                    yPosition = drawText(
                        itemText,
                        at: CGPoint(x: leftMargin + 10, y: yPosition),
                        width: contentWidth - 10,
                        font: .systemFont(ofSize: 11),
                        context: context.cgContext
                    )

                    if let notes = item.notes {
                        yPosition = drawText(
                            "  \(notes)",
                            at: CGPoint(x: leftMargin + 20, y: yPosition),
                            width: contentWidth - 20,
                            font: .italicSystemFont(ofSize: 10),
                            color: .gray,
                            context: context.cgContext
                        )
                    }

                    yPosition += 5
                }
                yPosition += 15
            }

            // Steps
            if !plan.steps.isEmpty {
                yPosition = drawSectionHeader(
                    "Steps",
                    at: CGPoint(x: leftMargin, y: yPosition),
                    context: context.cgContext
                )
                yPosition += 10

                for (index, step) in plan.steps.sorted(by: { $0.order < $1.order }).enumerated() {
                    // Check if we need a new page
                    if yPosition > 720 {
                        drawFooter()
                        context.beginPage()
                        yPosition = 50
                    }

                    let stepTitle = "\(index + 1). \(step.title)"
                    yPosition = drawText(
                        stepTitle,
                        at: CGPoint(x: leftMargin, y: yPosition),
                        width: contentWidth,
                        font: .boldSystemFont(ofSize: 12),
                        context: context.cgContext
                    )

                    if let description = step.description {
                        yPosition = drawText(
                            description,
                            at: CGPoint(x: leftMargin + 10, y: yPosition),
                            width: contentWidth - 10,
                            font: .systemFont(ofSize: 11),
                            context: context.cgContext
                        )
                    }

                    yPosition += 15
                }
            }

            // Draw footer on the final page
            drawFooter()
        }

        // Write PDF data to file
        try data.write(to: fileURL)

        return fileURL
    }

    // MARK: - Drawing Helpers

    private func drawText(
        _ text: String,
        at point: CGPoint,
        width: CGFloat,
        font: UIFont,
        color: UIColor = .black,
        alignment: NSTextAlignment = .left,
        context: CGContext
    ) -> CGFloat {
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = alignment
        paragraphStyle.lineBreakMode = .byWordWrapping

        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: color,
            .paragraphStyle: paragraphStyle
        ]

        let attributedString = NSAttributedString(string: text, attributes: attributes)
        let textRect = CGRect(x: point.x, y: point.y, width: width, height: CGFloat.greatestFiniteMagnitude)
        let boundingRect = attributedString.boundingRect(with: textRect.size, options: [.usesLineFragmentOrigin], context: nil)

        attributedString.draw(in: CGRect(x: point.x, y: point.y, width: width, height: boundingRect.height))

        return point.y + boundingRect.height
    }

    private func drawSectionHeader(
        _ text: String,
        at point: CGPoint,
        context: CGContext
    ) -> CGFloat {
        let font = UIFont.boldSystemFont(ofSize: 14)
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: UIColor.black
        ]

        let attributedString = NSAttributedString(string: text, attributes: attributes)
        attributedString.draw(at: point)

        return point.y + font.lineHeight + 5
    }

    private func drawAuthorCard(
        _ author: AuthorModel,
        at point: CGPoint,
        width: CGFloat,
        context: CGContext
    ) -> CGFloat {
        var yPos = point.y

        // Draw box background
        context.setFillColor(UIColor.systemGray6.cgColor)
        let boxRect = CGRect(x: point.x, y: point.y, width: width, height: 80)
        context.fill(boxRect)

        yPos += 10

        // Author name (access property directly to avoid concurrency issues)
        let authorName = author.name ?? "Anonymous"
        yPos = drawText(
            "Created by: \(authorName)",
            at: CGPoint(x: point.x + 10, y: yPos),
            width: width - 20,
            font: .boldSystemFont(ofSize: 12),
            context: context
        )

        // Email
        if let email = author.email {
            yPos = drawText(
                email,
                at: CGPoint(x: point.x + 10, y: yPos),
                width: width - 20,
                font: .systemFont(ofSize: 10),
                color: .gray,
                context: context
            )
        }

        // Website
        if let website = author.website {
            yPos = drawText(
                website,
                at: CGPoint(x: point.x + 10, y: yPos),
                width: width - 20,
                font: .systemFont(ofSize: 10),
                color: .blue,
                context: context
            )
        }

        return boxRect.maxY + 10
    }

    private func sanitizeFilename(_ filename: String) -> String {
        let invalidCharacters = CharacterSet(charactersIn: ":/\\?%*|\"<>")
        return filename
            .components(separatedBy: invalidCharacters)
            .joined(separator: "-")
            .trimmingCharacters(in: .whitespaces)
    }
}

//
//  RatingDisplayView.swift
//  Molten
//
//  View for displaying aggregated ratings (average stars + word list)
//

import SwiftUI

struct RatingDisplayView: View {
    // MARK: - Properties

    let itemStableId: String
    private let service: RatingService

    @State private var rating: AggregatedRatingModel?
    @State private var isLoading = false
    @State private var showingError = false
    @State private var errorMessage = ""
    @State private var showingSubmission = false
    @State private var showingSuccessToast = false

    // MARK: - Initialization

    init(
        itemStableId: String,
        service: RatingService = AppDependencies.shared.ratingService
    ) {
        self.itemStableId = itemStableId
        self.service = service
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 16) {
            if isLoading {
                ProgressView()
            } else if let rating = rating {
                ratingContent(rating)
            } else {
                noRatingContent
            }
        }
        .task {
            await loadRating()
        }
        .alert("Error", isPresented: $showingError) {
            Button("OK") { }
        } message: {
            Text(errorMessage)
        }
        .sheet(isPresented: $showingSubmission) {
            // Note: itemName would need to be passed in for this to work
            // For now, using itemStableId
            RatingSubmissionView(
                itemStableId: itemStableId,
                itemName: itemStableId
            )
        }
        .onReceive(NotificationCenter.default.publisher(for: .ratingSubmitted)) { notification in
            // Check if this is for our item
            if let submittedItemId = notification.object as? String, submittedItemId == itemStableId {
                // Reload rating
                Task {
                    await loadRating()
                }
                // Show success toast
                withAnimation(.easeInOut(duration: 0.3)) {
                    showingSuccessToast = true
                }
            }
        }
        .successToast(message: "Your rating has been submitted!", isShowing: $showingSuccessToast)
    }

    // MARK: - Content Views

    @ViewBuilder
    private func ratingContent(_ rating: AggregatedRatingModel) -> some View {
        VStack(spacing: 12) {
            // Star rating
            HStack(spacing: 4) {
                Text(rating.formattedAverageRating)
                    .font(.title2)
                    .fontWeight(.semibold)

                starsView(rating: rating.averageRating)

                Text("(\(rating.totalRatings))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            // Rating category badge
            if rating.hasEnoughRatings {
                Text(rating.ratingCategory.rawValue)
                    .font(.caption)
                    .fontWeight(.medium)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(categoryColor(rating.ratingCategory))
                    .foregroundStyle(.white)
                    .clipShape(Capsule())
            } else {
                Text("Not enough ratings yet")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            // Top words
            if !rating.topWords.isEmpty {
                Divider()

                VStack(alignment: .leading, spacing: 8) {
                    Text("Common Descriptions")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)

                    RatingFlowLayout(spacing: 8) {
                        ForEach(rating.topWordsForDisplay(limit: 10)) { word in
                            wordTag(word: word)
                        }
                    }
                }
            }

            // Add rating button
            Button {
                showingSubmission = true
            } label: {
                Label("Rate This Item", systemImage: "star")
                    .font(.caption)
            }
            .buttonStyle(.bordered)
            .accessibilityIdentifier("rating_display_rate")
        }
        .padding()
        .background(.quaternary.opacity(0.3))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var noRatingContent: some View {
        VStack(spacing: 12) {
            Image(systemName: "star")
                .font(.largeTitle)
                .foregroundStyle(.secondary)

            Text("No ratings yet")
                .font(.headline)
                .foregroundStyle(.secondary)

            Text("Be the first to rate this item!")
                .font(.caption)
                .foregroundStyle(.secondary)

            Button {
                showingSubmission = true
            } label: {
                Label("Rate This Item", systemImage: "star.fill")
            }
            .buttonStyle(.bordered)
            .accessibilityIdentifier("rating_display_rate_first")
        }
        .padding()
        .background(.quaternary.opacity(0.3))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func starsView(rating: Double) -> some View {
        HStack(spacing: 2) {
            ForEach(1...5, id: \.self) { star in
                let filled = Double(star) <= rating
                let halfFilled = Double(star) - 0.5 <= rating && !filled

                Image(systemName: filled ? "star.fill" : (halfFilled ? "star.leadinghalf.filled" : "star"))
                    .font(.caption)
                    .foregroundStyle(.yellow)
            }
        }
    }

    private func wordTag(word: RatingWordModel) -> some View {
        HStack(spacing: 4) {
            Text(word.word)
                .font(.caption)

            Text("×\(word.frequency)")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(.secondary.opacity(0.2))
        .clipShape(Capsule())
    }

    private func categoryColor(_ category: RatingCategory) -> Color {
        switch category {
        case .excellent:
            return .green
        case .good:
            return .blue
        case .average:
            return .orange
        case .belowAverage:
            return .orange
        case .poor:
            return .red
        }
    }

    // MARK: - Actions

    private func loadRating() async {
        isLoading = true
        defer { isLoading = false }

        do {
            let ratings = try await service.fetchRatings(forItems: [itemStableId])
            rating = ratings.first
        } catch {
            errorMessage = "Failed to load rating: \(error.localizedDescription)"
            showingError = true
        }
    }
}

// MARK: - Flow Layout

/// Simple flow layout for wrapping word tags
private struct RatingFlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = FlowResult(in: proposal.width ?? 0, subviews: subviews, spacing: spacing)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = FlowResult(in: bounds.width, subviews: subviews, spacing: spacing)
        for (index, row) in result.rows.enumerated() {
            for (subview, x) in row {
                subview.place(
                    at: CGPoint(x: bounds.minX + x, y: bounds.minY + result.rowYs[index]),
                    proposal: .unspecified
                )
            }
        }
    }

    struct FlowResult {
        var rows: [[(subview: LayoutSubviews.Element, x: CGFloat)]] = []
        var rowYs: [CGFloat] = []
        var size: CGSize = .zero

        init(in maxWidth: CGFloat, subviews: Subviews, spacing: CGFloat) {
            var currentRow: [(subview: LayoutSubviews.Element, x: CGFloat)] = []
            var currentX: CGFloat = 0
            var currentY: CGFloat = 0
            var maxHeight: CGFloat = 0

            for subview in subviews {
                let size = subview.sizeThatFits(.unspecified)

                if currentX + size.width > maxWidth && !currentRow.isEmpty {
                    // Start new row
                    rows.append(currentRow)
                    rowYs.append(currentY)
                    currentY += maxHeight + spacing
                    currentRow = []
                    currentX = 0
                    maxHeight = 0
                }

                currentRow.append((subview, currentX))
                currentX += size.width + spacing
                maxHeight = max(maxHeight, size.height)
            }

            // Add last row
            if !currentRow.isEmpty {
                rows.append(currentRow)
                rowYs.append(currentY)
            }

            self.size = CGSize(
                width: maxWidth,
                height: currentY + maxHeight
            )
        }
    }
}

// MARK: - Preview

#Preview {
    RatingDisplayView(itemStableId: "bullseye-001-0")
        .padding()
}

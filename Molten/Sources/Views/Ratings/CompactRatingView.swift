//
//  CompactRatingView.swift
//  Molten
//
//  Compact inline rating display for use in cards
//

import SwiftUI

/// Compact single-line rating display for cards
struct CompactRatingView: View {
    let itemStableId: String
    let itemName: String?
    private let service: RatingService

    @State private var rating: AggregatedRatingModel?
    @State private var isLoading = false
    @State private var showingSubmission = false
    @State private var refreshTrigger = 0

    init(
        itemStableId: String,
        itemName: String? = nil,
        service: RatingService = AppDependencies.shared.ratingService
    ) {
        self.itemStableId = itemStableId
        self.itemName = itemName
        self.service = service
    }

    var body: some View {
        HStack(spacing: 8) {
            if isLoading {
                ProgressView()
                    .scaleEffect(0.6)
            } else if let rating = rating {
                // Stars
                starsView(rating: rating.averageRating)

                // Average + count
                Text("\(rating.formattedAverageRating) (\(rating.totalRatings))")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer()

                // Rate button
                Button {
                    showingSubmission = true
                } label: {
                    Label("Rate", systemImage: "star")
                        .font(.caption)
                        .labelStyle(.titleOnly)
                }
                .buttonStyle(.bordered)
                .controlSize(.mini)
            } else {
                // No ratings - very compact
                HStack(spacing: 4) {
                    Image(systemName: "star")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Text("No ratings")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button {
                    showingSubmission = true
                } label: {
                    Label("Rate", systemImage: "star.fill")
                        .font(.caption)
                        .labelStyle(.titleOnly)
                }
                .buttonStyle(.bordered)
                .controlSize(.mini)
            }
        }
        .task(id: refreshTrigger) {
            await loadRating()
        }
        .sheet(isPresented: $showingSubmission, onDismiss: {
            // Refresh rating after submission
            refreshTrigger += 1
        }) {
            RatingSubmissionView(
                itemStableId: itemStableId,
                itemName: itemName ?? itemStableId
            )
        }
        .onReceive(NotificationCenter.default.publisher(for: .ratingSubmitted)) { notification in
            // Check if this is for our item
            if let submittedItemId = notification.object as? String, submittedItemId == itemStableId {
                refreshTrigger += 1
            }
        }
    }

    // Expose the rating for external use
    var topWords: [RatingWordModel] {
        rating?.topWords ?? []
    }

    private func starsView(rating: Double) -> some View {
        HStack(spacing: 1) {
            ForEach(1...5, id: \.self) { star in
                let filled = Double(star) <= rating
                let halfFilled = Double(star) - 0.5 <= rating && !filled

                Image(systemName: filled ? "star.fill" : (halfFilled ? "star.leadinghalf.filled" : "star"))
                    .font(.caption2)
                    .foregroundStyle(.yellow)
            }
        }
    }

    private func loadRating() async {
        isLoading = true
        defer { isLoading = false }

        do {
            print("🔍 [CompactRatingView] Fetching rating for stable_id: \(itemStableId)")
            let ratings = try await service.fetchRatings(forItems: [itemStableId])
            rating = ratings.first
            print("🔍 [CompactRatingView] Got \(ratings.count) ratings for \(itemStableId)")
        } catch {
            // Silently fail for compact view
            print("❌ [CompactRatingView] Failed to load rating for \(itemStableId): \(error)")
        }
    }
}

#Preview("With Rating") {
    VStack(spacing: 20) {
        CompactRatingView(itemStableId: "bullseye-001-0")
            .padding()
            .background(.gray.opacity(0.1))

        CompactRatingView(itemStableId: "non-existent")
            .padding()
            .background(.gray.opacity(0.1))
    }
    .padding()
}

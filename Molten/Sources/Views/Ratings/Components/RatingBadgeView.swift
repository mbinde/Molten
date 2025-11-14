//
//  RatingBadgeView.swift
//  Molten
//
//  Compact badge view showing just stars and rating count
//  For embedding in list/detail views
//

import SwiftUI

struct RatingBadgeView: View {
    // MARK: - Properties

    let itemStableId: String
    private let service: RatingService

    @State private var rating: AggregatedRatingModel?
    @State private var isLoading = false

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
        Group {
            if isLoading {
                ProgressView()
                    .controlSize(.small)
            } else if let rating = rating, rating.hasEnoughRatings {
                HStack(spacing: 4) {
                    Image(systemName: "star.fill")
                        .font(.caption)
                        .foregroundStyle(.yellow)

                    Text(rating.formattedAverageRating)
                        .font(.caption)
                        .fontWeight(.medium)

                    Text("(\(rating.totalRatings))")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            } else {
                // No rating or not enough ratings - show nothing
                EmptyView()
            }
        }
        .task {
            await loadRating()
        }
    }

    // MARK: - Actions

    private func loadRating() async {
        isLoading = true
        defer { isLoading = false }

        do {
            let ratings = try await service.fetchRatings(forItems: [itemStableId], forceRefresh: false)
            rating = ratings.first
        } catch {
            // Silently fail for badges - they're not critical
            print("Failed to load rating badge: \(error)")
        }
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 20) {
        RatingBadgeView(itemStableId: "bullseye-001-0")

        RatingBadgeView(itemStableId: "nonexistent-item")
    }
    .padding()
}

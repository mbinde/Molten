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
        .task {
            await loadRating()
        }
        .sheet(isPresented: $showingSubmission) {
            RatingSubmissionView(
                itemStableId: itemStableId,
                itemName: itemName ?? itemStableId
            )
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

        // FIXME: Remove this mock data - just for UI testing
        let mockRating = Double.random(in: 3.0...5.0)
        let mockCount = Int.random(in: 5...50)

        // Generate at least 20 random words with frequencies
        let wordList = [
            "beautiful", "vibrant", "rich", "smooth", "stunning", "brilliant",
            "gorgeous", "intense", "deep", "striking", "elegant", "lovely",
            "vivid", "saturated", "bold", "subtle", "delicate", "lustrous",
            "translucent", "opaque", "clear", "bright", "warm", "cool",
            "versatile", "unique", "consistent", "workable", "reactive", "stable"
        ]

        let mockWords = wordList.enumerated().map { index, word in
            RatingWordModel(
                word: word,
                frequency: Int.random(in: 1...15),
                rank: index + 1
            )
        }.sorted { $0.frequency > $1.frequency }

        rating = AggregatedRatingModel(
            itemStableId: itemStableId,
            averageRating: mockRating,
            totalRatings: mockCount,
            topWords: mockWords,
            lastAggregated: Date()
        )
        return
        // END FIXME

        do {
            let ratings = try await service.fetchRatings(forItems: [itemStableId])
            rating = ratings.first
        } catch {
            // Silently fail for compact view
            print("Failed to load rating: \(error)")
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

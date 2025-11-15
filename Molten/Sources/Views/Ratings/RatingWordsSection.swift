//
//  RatingWordsSection.swift
//  Molten
//
//  Standalone section for displaying rating words outside the card
//

import SwiftUI

/// Standalone section showing rating words with "..." button
struct RatingWordsSection: View {
    let itemStableId: String
    private let service: RatingService

    @State private var words: [RatingWordModel] = []
    @State private var isLoading = false

    init(
        itemStableId: String,
        service: RatingService = AppDependencies.shared.ratingService
    ) {
        self.itemStableId = itemStableId
        self.service = service
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if !words.isEmpty {
                CompactWordChipsView(words: words)
                    .padding(.horizontal)
            }
        }
        .task {
            await loadWords()
        }
    }

    private func loadWords() async {
        isLoading = true
        defer { isLoading = false }

        do {
            let ratings = try await service.fetchRatings(forItems: [itemStableId])
            if let rating = ratings.first {
                words = rating.topWords
            }
        } catch {
            // Silently fail
            print("Failed to load rating words: \(error)")
        }
    }
}

#Preview {
    VStack {
        RatingWordsSection(itemStableId: "bullseye-001-0")
            .task {
                // Preview won't load async, so this is just for structure
            }
            .padding()
    }
}

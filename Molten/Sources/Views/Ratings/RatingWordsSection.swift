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
    @State private var refreshTrigger = 0
    @State private var hasLoaded = false
    @AppStorage("showRatingsInCatalog") private var showRatingsInCatalog = true

    init(
        itemStableId: String,
        service: RatingService = AppDependencies.shared.ratingService
    ) {
        self.itemStableId = itemStableId
        self.service = service
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if showRatingsInCatalog && !words.isEmpty {
                CompactWordChipsView(words: words)
                    .padding(.horizontal)
            }
        }
        .task {
            // Only load once on initial appearance and if ratings are enabled
            guard !hasLoaded && showRatingsInCatalog else { return }
            await loadWords()
            hasLoaded = true
        }
        .onChange(of: refreshTrigger) { _, _ in
            // Reload when explicitly triggered (after rating submission) and if ratings are enabled
            guard showRatingsInCatalog else { return }
            Task {
                await loadWords()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .ratingSubmitted)) { notification in
            // Check if this is for our item and if ratings are enabled
            guard showRatingsInCatalog else { return }
            if let submittedItemId = notification.object as? String, submittedItemId == itemStableId {
                refreshTrigger += 1
            }
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
            print("❌ [RatingWordsSection] Failed to load rating words for \(itemStableId): \(error)")
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

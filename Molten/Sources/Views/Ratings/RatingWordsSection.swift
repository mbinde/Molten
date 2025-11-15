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
    @State private var isCloudView = false

    init(
        itemStableId: String,
        service: RatingService = AppDependencies.shared.ratingService
    ) {
        self.itemStableId = itemStableId
        self.service = service
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if !words.isEmpty {
                HStack {
                    Text(isCloudView ? "Word Cloud" : "Top Words")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Spacer()

                    Button {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            isCloudView.toggle()
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: isCloudView ? "list.bullet" : "cloud")
                                .font(.caption2)
                            Text(isCloudView ? "List" : "Cloud")
                                .font(.caption2)
                        }
                        .foregroundStyle(.blue)
                    }
                }
                .padding(.horizontal)

                if isCloudView {
                    WordCloudView(words: words)
                        .transition(.opacity)
                } else {
                    CompactWordChipsView(words: words)
                        .padding(.horizontal)
                        .transition(.opacity)
                }
            }
        }
        .task {
            await loadWords()
        }
    }

    private func loadWords() async {
        isLoading = true
        defer { isLoading = false }

        // FIXME: Remove this mock data - just for UI testing
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

        words = mockWords
        return
        // END FIXME

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

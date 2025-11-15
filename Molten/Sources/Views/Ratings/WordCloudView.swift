//
//  WordCloudView.swift
//  Molten
//
//  Simple word cloud layout for rating words
//

import SwiftUI

/// Word cloud view that sizes words by frequency
struct WordCloudView: View {
    let words: [RatingWordModel]

    @State private var showingAllWords = false

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                ForEach(Array(words.prefix(20).enumerated()), id: \.offset) { index, word in
                    wordView(word: word, index: index, totalWords: min(words.count, 20))
                        .position(
                            x: calculateX(for: index, in: geometry.size.width),
                            y: calculateY(for: index, in: geometry.size.height)
                        )
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
            .onTapGesture {
                showingAllWords = true
            }
        }
        .frame(height: 180)
        .sheet(isPresented: $showingAllWords) {
            AllWordsSheet(words: words)
        }
    }

    private func wordView(word: RatingWordModel, index: Int, totalWords: Int) -> some View {
        let size = fontSize(for: word, totalWords: totalWords)
        let color = wordColor(for: index)

        return Text(word.word)
            .font(.system(size: size, weight: .semibold))
            .foregroundStyle(color)
            .opacity(0.7 + Double(word.frequency) / Double(words.first?.frequency ?? 1) * 0.3)
    }

    private func fontSize(for word: RatingWordModel, totalWords: Int) -> CGFloat {
        guard let maxFrequency = words.first?.frequency else { return 12 }

        // Scale from 12pt to 28pt based on frequency
        let minSize: CGFloat = 12
        let maxSize: CGFloat = 28

        let ratio = Double(word.frequency) / Double(maxFrequency)
        return minSize + (maxSize - minSize) * ratio
    }

    private func wordColor(for index: Int) -> Color {
        let colors: [Color] = [.blue, .purple, .indigo, .teal, .cyan, .mint]
        return colors[index % colors.count]
    }

    // Simple scatter layout with deterministic positioning
    private func calculateX(for index: Int, in width: CGFloat) -> CGFloat {
        let columns = 4
        let col = index % columns
        let spacing = width / CGFloat(columns)
        let jitter = CGFloat((index * 37) % 20 - 10) // Deterministic jitter

        return spacing * (CGFloat(col) + 0.5) + jitter
    }

    private func calculateY(for index: Int, in height: CGFloat) -> CGFloat {
        let rows = 5
        let row = (index / 4) % rows
        let spacing = height / CGFloat(rows)
        let jitter = CGFloat((index * 23) % 20 - 10) // Deterministic jitter

        return spacing * (CGFloat(row) + 0.5) + jitter
    }
}

/// Sheet showing all rating words (shared with CompactWordChipsView)
struct AllWordsSheet: View {
    let words: [RatingWordModel]
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12) {
                    Text("All rating words sorted by frequency")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal)

                    WordChipsFlowLayout(spacing: 8) {
                        ForEach(words) { word in
                            wordChip(word: word)
                        }
                    }
                    .padding(.horizontal)
                }
                .padding(.vertical)
            }
            .navigationTitle("Rating Words")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }

    private func wordChip(word: RatingWordModel) -> some View {
        HStack(spacing: 4) {
            Text(word.word)
                .font(.caption)
                .fixedSize()

            Text("×\(word.frequency)")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .fixedSize()
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(.blue.opacity(0.1))
        .foregroundStyle(.blue)
        .clipShape(Capsule())
        .fixedSize()
    }
}

#Preview {
    VStack {
        WordCloudView(words: [
            RatingWordModel(word: "beautiful", frequency: 15, rank: 1),
            RatingWordModel(word: "vibrant", frequency: 12, rank: 2),
            RatingWordModel(word: "rich", frequency: 10, rank: 3),
            RatingWordModel(word: "smooth", frequency: 8, rank: 4),
            RatingWordModel(word: "stunning", frequency: 7, rank: 5),
            RatingWordModel(word: "brilliant", frequency: 6, rank: 6),
            RatingWordModel(word: "gorgeous", frequency: 5, rank: 7),
            RatingWordModel(word: "intense", frequency: 4, rank: 8),
            RatingWordModel(word: "deep", frequency: 3, rank: 9),
            RatingWordModel(word: "striking", frequency: 2, rank: 10),
        ])
        .padding()
        .background(.gray.opacity(0.05))
    }
}

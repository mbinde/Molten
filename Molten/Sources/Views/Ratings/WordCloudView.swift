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
        }
        .frame(height: 180)
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

        // Much larger size range: 10pt to 40pt with exponential scaling
        let minSize: CGFloat = 10
        let maxSize: CGFloat = 40

        let ratio = Double(word.frequency) / Double(maxFrequency)
        // Use power curve to exaggerate differences
        let curved = pow(ratio, 0.6)
        return minSize + (maxSize - minSize) * curved
    }

    private func wordColor(for index: Int) -> Color {
        let colors: [Color] = [.blue, .purple, .indigo, .teal, .cyan, .mint]
        return colors[index % colors.count]
    }

    // Spiral positioning from center outward
    private func calculateX(for index: Int, in width: CGFloat) -> CGFloat {
        let centerX = width / 2
        let angle = Double(index) * 2.4 // Golden angle in radians
        let radius = sqrt(Double(index + 1)) * 20.0

        return centerX + CGFloat(cos(angle) * radius)
    }

    private func calculateY(for index: Int, in height: CGFloat) -> CGFloat {
        let centerY = height / 2
        let angle = Double(index) * 2.4 // Golden angle in radians
        let radius = sqrt(Double(index + 1)) * 20.0

        return centerY + CGFloat(sin(angle) * radius)
    }
}

/// Sheet showing all rating words
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
                            gradientWordChip(word: word, maxFrequency: words.first?.frequency ?? 1, minFrequency: words.last?.frequency ?? 1)
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

    private func gradientWordChip(word: RatingWordModel, maxFrequency: Int, minFrequency: Int) -> some View {
        // Calculate proportional position between min and max
        let range = Double(maxFrequency - minFrequency)
        let position = range > 0 ? Double(word.frequency - minFrequency) / range : 1.0

        // Font size: 11pt (smallest) to 17pt (largest)
        let minFontSize: CGFloat = 11
        let maxFontSize: CGFloat = 17
        let fontSize = minFontSize + (maxFontSize - minFontSize) * position

        // Color intensity: lighter to darker blue
        let colorOpacity = 0.3 + (0.7 * position) // 0.3 to 1.0

        return HStack(spacing: 4) {
            Text(word.word)
                .font(.system(size: fontSize, weight: .medium))
                .fixedSize()

            Text("×\(word.frequency)")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .fixedSize()
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(.blue.opacity(0.1))
        .foregroundStyle(.blue.opacity(colorOpacity))
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

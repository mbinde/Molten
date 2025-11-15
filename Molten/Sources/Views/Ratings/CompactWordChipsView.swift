//
//  CompactWordChipsView.swift
//  Molten
//
//  Compact word chips that show as many as fit on one line
//

import SwiftUI

/// Compact word chips view that shows words in a single line with overflow
struct CompactWordChipsView: View {
    let words: [RatingWordModel]

    @State private var showingAllWords = false

    var body: some View {
        if !words.isEmpty {
            HStack(spacing: 4) {
                // Show first few words that fit
                ForEach(words.prefix(5)) { word in
                    wordChip(word: word)
                }

                // Show "..." button if there are more words
                if words.count > 5 {
                    Button {
                        showingAllWords = true
                    } label: {
                        Text("...")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(.secondary.opacity(0.1))
                            .clipShape(Capsule())
                    }
                }
            }
            .sheet(isPresented: $showingAllWords) {
                AllWordsSheet(words: words)
            }
        }
    }

    private func wordChip(word: RatingWordModel) -> some View {
        HStack(spacing: 2) {
            Text(word.word)
                .font(.caption2)

            Text("×\(word.frequency)")
                .font(.system(size: 9))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(.blue.opacity(0.1))
        .foregroundStyle(.blue)
        .clipShape(Capsule())
    }
}

/// Sheet showing all rating words
private struct AllWordsSheet: View {
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

            Text("×\(word.frequency)")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(.blue.opacity(0.1))
        .foregroundStyle(.blue)
        .clipShape(Capsule())
    }
}

/// Simple flow layout for wrapping chips
private struct WordChipsFlowLayout: Layout {
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

#Preview {
    VStack(spacing: 20) {
        CompactWordChipsView(words: [
            RatingWordModel(word: "beautiful", frequency: 12, rank: 1),
            RatingWordModel(word: "vibrant", frequency: 8, rank: 2),
            RatingWordModel(word: "rich", frequency: 6, rank: 3),
            RatingWordModel(word: "smooth", frequency: 5, rank: 4),
            RatingWordModel(word: "stunning", frequency: 4, rank: 5),
            RatingWordModel(word: "brilliant", frequency: 3, rank: 6),
        ])
        .padding()
        .background(.gray.opacity(0.1))
    }
    .padding()
}

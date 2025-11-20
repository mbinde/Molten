//
//  ExpandableText.swift
//  Molten
//
//  Created by Assistant on 11/19/25.
//  Expandable text view that only shows "Show more/less" button when content exceeds line limit
//

import SwiftUI

/// Text view that truncates content and shows expand/collapse button only when needed
struct ExpandableText: View {
    let content: String
    let lineLimit: Int
    @Binding var isExpanded: Bool

    @State private var isTruncated: Bool = false
    @State private var intrinsicSize: CGSize = .zero
    @State private private(set) var truncatedSize: CGSize = .zero

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(content)
                .font(.body)
                .lineLimit(isExpanded ? nil : lineLimit)
                .background(
                    // Measure both intrinsic and truncated sizes
                    GeometryReader { geometry in
                        Color.clear.preference(
                            key: SizePreferenceKey.self,
                            value: geometry.size
                        )
                    }
                )
                .onPreferenceChange(SizePreferenceKey.self) { size in
                    if isExpanded {
                        intrinsicSize = size
                    } else {
                        truncatedSize = size
                    }
                    // Text is truncated if intrinsic height > truncated height
                    isTruncated = intrinsicSize.height > truncatedSize.height
                }

            // Only show button if text is actually truncated
            if isTruncated {
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isExpanded.toggle()
                    }
                }) {
                    Text(isExpanded ? "Show Less" : "Show More")
                        .font(.caption)
                        .foregroundColor(.blue)
                }
            }
        }
        .onAppear {
            // Trigger initial measurement by toggling state
            Task {
                // First measure truncated size
                truncatedSize = .zero
                try? await Task.sleep(nanoseconds: 10_000_000) // 10ms

                // Then measure full size
                isExpanded = true
                try? await Task.sleep(nanoseconds: 10_000_000) // 10ms

                // Return to collapsed state
                isExpanded = false
            }
        }
    }
}

// MARK: - Preference Key

private struct SizePreferenceKey: PreferenceKey {
    static var defaultValue: CGSize = .zero
    static func reduce(value: inout CGSize, nextValue: () -> CGSize) {
        value = nextValue()
    }
}

// MARK: - Preview

#Preview("Short Text (No Button)") {
    @Previewable @State var isExpanded = false

    VStack(alignment: .leading, spacing: 20) {
        Text("Short Text Example")
            .font(.headline)

        ExpandableText(
            content: "This is a short text that fits within 4 lines.",
            lineLimit: 4,
            isExpanded: $isExpanded
        )
        .padding()
        .background(Color.gray.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
    .padding()
}

#Preview("Long Text (Shows Button)") {
    @Previewable @State var isExpanded = false

    VStack(alignment: .leading, spacing: 20) {
        Text("Long Text Example")
            .font(.headline)

        ExpandableText(
            content: """
            This is a much longer text that will definitely exceed 4 lines when displayed. \
            It contains multiple sentences and enough content to demonstrate the expand/collapse \
            functionality. When collapsed, this text should be truncated and show a "Show More" \
            button. When expanded, it should show all the text with a "Show Less" button. \
            The component should automatically detect whether truncation is needed and only \
            show the button when necessary.
            """,
            lineLimit: 4,
            isExpanded: $isExpanded
        )
        .padding()
        .background(Color.gray.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
    .padding()
}

#Preview("Exactly 4 Lines") {
    @Previewable @State var isExpanded = false

    VStack(alignment: .leading, spacing: 20) {
        Text("Exactly 4 Lines (Edge Case)")
            .font(.headline)

        ExpandableText(
            content: """
            Line 1: This text is carefully crafted to be exactly four lines.
            Line 2: It should not show the expand button since it fits.
            Line 3: Testing the edge case where content matches limit.
            Line 4: This is the fourth and final line of text.
            """,
            lineLimit: 4,
            isExpanded: $isExpanded
        )
        .padding()
        .background(Color.gray.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
    .padding()
}

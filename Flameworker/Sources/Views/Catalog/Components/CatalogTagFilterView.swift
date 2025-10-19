//
//  CatalogTagFilterView.swift
//  Flameworker
//
//  Created by Melissa Binde on 9/28/25.
//

import SwiftUI

struct CatalogTagFilterView: View {
    let allAvailableTags: [String]
    @Binding var selectedTags: Set<String>
    @Binding var showingAllTags: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Filter by Tags")
                    .font(.headline)
                    .fontWeight(.medium)
                Spacer()
                if !selectedTags.isEmpty {
                    Button("Clear") {
                        selectedTags.removeAll()
                    }
                    .font(.caption)
                    .foregroundColor(.blue)
                }
                Button("All Tags") {
                    showingAllTags = true
                }
                .font(.caption)
                .foregroundColor(.blue)
            }
            
            // Show selected tags
            if !selectedTags.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(Array(selectedTags).sorted(), id: \.self) { tag in
                            HStack(spacing: 4) {
                                // Color circle for color tags
                                if let color = colorFromTag(tag) {
                                    Circle()
                                        .fill(color)
                                        .frame(width: 8, height: 8)
                                        .overlay(
                                            Circle()
                                                .stroke(Color.black.opacity(0.1), lineWidth: 0.5)
                                        )
                                }

                                Text(tag)
                                    .font(.caption)
                                Button("×") {
                                    selectedTags.remove(tag)
                                }
                                .font(.caption)
                                .foregroundColor(.red)
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.blue.opacity(0.2))
                            .foregroundColor(.blue)
                            .clipShape(Capsule())
                        }
                    }
                    .padding(.horizontal, 1)
                }
            }
            
            // Show first few available tags for quick selection
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(allAvailableTags.prefix(10), id: \.self) { tag in
                        Button {
                            if selectedTags.contains(tag) {
                                selectedTags.remove(tag)
                            } else {
                                selectedTags.insert(tag)
                            }
                        } label: {
                            HStack(spacing: 4) {
                                // Color circle for color tags
                                if let color = colorFromTag(tag) {
                                    Circle()
                                        .fill(color)
                                        .frame(width: 8, height: 8)
                                        .overlay(
                                            Circle()
                                                .stroke(Color.black.opacity(0.1), lineWidth: 0.5)
                                        )
                                }

                                Text(tag)
                            }
                        }
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(selectedTags.contains(tag) ? Color.blue.opacity(0.2) : Color.gray.opacity(0.1))
                        .foregroundColor(selectedTags.contains(tag) ? .blue : .secondary)
                        .clipShape(Capsule())
                    }
                    
                    if allAvailableTags.count > 10 {
                        Button("More...") {
                            showingAllTags = true
                        }
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.gray.opacity(0.1))
                        .foregroundColor(.secondary)
                        .clipShape(Capsule())
                    }
                }
                .padding(.horizontal, 1)
            }
        }
        .padding(.vertical, 4)
    }

    // MARK: - Helper Methods

    /// Extract color from tag name if it represents a color
    private func colorFromTag(_ tag: String) -> Color? {
        let lowercased = tag.lowercased()

        // Basic color mapping
        let colorMap: [String: Color] = [
            "red": .red,
            "orange": .orange,
            "yellow": .yellow,
            "green": .green,
            "blue": .blue,
            "purple": .purple,
            "pink": .pink,
            "brown": Color(red: 0.6, green: 0.4, blue: 0.2),
            "gray": .gray,
            "grey": .gray,
            "black": .black,
            "white": .white,
            "clear": Color(white: 0.95),
            "amber": Color(red: 1.0, green: 0.75, blue: 0.0),
            "teal": Color(red: 0.0, green: 0.5, blue: 0.5),
            "turquoise": Color(red: 0.25, green: 0.88, blue: 0.82),
            "violet": Color(red: 0.58, green: 0.0, blue: 0.83),
            "gold": Color(red: 1.0, green: 0.84, blue: 0.0),
            "silver": Color(red: 0.75, green: 0.75, blue: 0.75),
            "bronze": Color(red: 0.8, green: 0.5, blue: 0.2),
            "copper": Color(red: 0.72, green: 0.45, blue: 0.2),
            "lime": Color(red: 0.75, green: 1.0, blue: 0.0),
            "cyan": .cyan,
            "magenta": Color(red: 1.0, green: 0.0, blue: 1.0),
            "indigo": Color(red: 0.29, green: 0.0, blue: 0.51)
        ]

        // Check for exact color name match
        for (colorName, color) in colorMap {
            if lowercased == colorName || lowercased.contains(colorName) {
                return color
            }
        }

        return nil
    }
}

#Preview {
    @Previewable @State var selectedTags: Set<String> = ["transparent", "opaque"]
    @Previewable @State var showingAllTags = false
    let sampleTags = ["transparent", "opaque", "metallic", "reactive", "borosilicate", "leadcrystal", "striking", "reduction"]
    
    return CatalogTagFilterView(
        allAvailableTags: sampleTags,
        selectedTags: $selectedTags,
        showingAllTags: $showingAllTags
    )
    .padding()
}
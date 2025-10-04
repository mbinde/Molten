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
                        Button(tag) {
                            if selectedTags.contains(tag) {
                                selectedTags.remove(tag)
                            } else {
                                selectedTags.insert(tag)
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
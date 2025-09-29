//
//  CatalogAllTagsView.swift
//  Flameworker
//
//  Created by Melissa Binde on 9/28/25.
//

import SwiftUI
import CoreData

struct CatalogAllTagsView: View {
    let allAvailableTags: [String]
    let catalogItems: FetchedResults<CatalogItem>
    @Binding var selectedTags: Set<String>
    @Binding var isPresented: Bool
    
    var body: some View {
        NavigationStack {
            List {
                Section("All Available Tags (\(allAvailableTags.count))") {
                    if allAvailableTags.isEmpty {
                        Text("No tags found in catalog items")
                            .foregroundColor(.secondary)
                    } else {
                        ForEach(allAvailableTags, id: \.self) { tag in
                            let itemsWithTag = catalogItems.filter { item in
                                CatalogItemHelpers.tagsArrayForItem(item).contains(tag)
                            }
                            
                            HStack {
                                Button(action: {
                                    if selectedTags.contains(tag) {
                                        selectedTags.remove(tag)
                                    } else {
                                        selectedTags.insert(tag)
                                    }
                                }) {
                                    HStack {
                                        Image(systemName: selectedTags.contains(tag) ? "checkmark.circle.fill" : "circle")
                                            .foregroundColor(selectedTags.contains(tag) ? .blue : .secondary)
                                        
                                        Text(tag)
                                            .foregroundColor(.primary)
                                        
                                        Spacer()
                                        
                                        Text("\(itemsWithTag.count)")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                    }
                }
                
                if !selectedTags.isEmpty {
                    Section("Active Filters") {
                        ForEach(Array(selectedTags).sorted(), id: \.self) { tag in
                            HStack {
                                Text(tag)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.blue.opacity(0.1))
                                    .foregroundColor(.blue)
                                    .clipShape(Capsule())
                                
                                Spacer()
                                
                                Button("Remove") {
                                    selectedTags.remove(tag)
                                }
                                .font(.caption)
                                .foregroundColor(.red)
                            }
                        }
                        
                        Button("Clear All Filters") {
                            selectedTags.removeAll()
                        }
                        .foregroundColor(.red)
                    }
                }
            }
            .navigationTitle("Tag Filter")
            .toolbar {
                ToolbarItem {
                    Button("Done") {
                        isPresented = false
                    }
                }
            }
        }
    }
}

/*
#Preview {
    @Previewable @State var selectedTags: Set<String> = ["transparent"]
    @Previewable @State var isPresented = true
    
    let sampleTags = ["transparent", "opaque", "metallic", "reactive", "clear", "matte"]
    let persistenceController = PersistenceController.preview
    
    // Create a wrapper view that provides FetchedResults
    struct PreviewWrapper: View {
        @FetchRequest(
            sortDescriptors: [NSSortDescriptor(keyPath: \CatalogItem.name, ascending: true)],
            animation: .default
        )
        private var catalogItems: FetchedResults<CatalogItem>
        
        @Binding var selectedTags: Set<String>
        @Binding var isPresented: Bool
        let allAvailableTags: [String]
        
        var body: some View {
            CatalogAllTagsView(
                allAvailableTags: allAvailableTags,
                catalogItems: catalogItems,
                selectedTags: $selectedTags,
                isPresented: $isPresented
            )
        }
    }
    
    PreviewWrapper(
        selectedTags: $selectedTags,
        isPresented: $isPresented,
        allAvailableTags: sampleTags
    )
    .environment(\.managedObjectContext, persistenceController.container.viewContext)
}
*/

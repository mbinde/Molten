//
//  CatalogBundleDebugView.swift
//  Flameworker
//
//  Created by Melissa Binde on 9/28/25.
//

import SwiftUI

struct CatalogBundleDebugView: View {
    let bundleContents: [String]
    @Binding var isPresented: Bool
    
    var body: some View {
        NavigationStack {
            List {
                Section("Bundle Information") {
                    if let bundlePath = Bundle.main.resourcePath {
                        Text("Bundle Path:")
                            .fontWeight(.medium)
                        Text(bundlePath)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Section("All Files (\(bundleContents.count))") {
                    ForEach(bundleContents.sorted(), id: \.self) { file in
                        HStack {
                            Image(systemName: file.hasSuffix(".json") ? "doc.text" : "doc")
                                .foregroundColor(file.hasSuffix(".json") ? .blue : .secondary)
                            Text(file)
                            Spacer()
                            if file.hasSuffix(".json") {
                                Text("JSON")
                                    .font(.caption)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 2)
                                    .background(Color.blue.opacity(0.2))
                                    .foregroundColor(.blue)
                                    .clipShape(Capsule())
                            }
                        }
                    }
                }
                
                Section("JSON Files") {
                    let jsonFiles = bundleContents.filter { $0.hasSuffix(".json") }
                    if jsonFiles.isEmpty {
                        Text("No JSON files found")
                            .foregroundColor(.secondary)
                    } else {
                        ForEach(jsonFiles, id: \.self) { file in
                            HStack {
                                Image(systemName: "doc.text")
                                    .foregroundColor(.blue)
                                Text(file)
                                Spacer()
                                if file == "colors.json" {
                                    Text("TARGET FILE")
                                        .font(.caption)
                                        .fontWeight(.bold)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 2)
                                        .background(Color.green.opacity(0.2))
                                        .foregroundColor(.green)
                                        .clipShape(Capsule())
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Bundle Contents")
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

#Preview {
    @State var isPresented = true
    let sampleContents = ["colors.json", "Info.plist", "Assets.car", "Main.storyboard"]
    
    return CatalogBundleDebugView(
        bundleContents: sampleContents,
        isPresented: $isPresented
    )
}
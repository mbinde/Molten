//
//  TagEditorSheet.swift
//  Molten
//
//  Reusable tag editor sheet component
//  Extracted from ProjectsView.swift for better code organization
//

import SwiftUI

/// A reusable modal sheet for editing tags
/// Provides add and remove functionality with input validation
struct TagEditorSheet: View {
    @Binding var tags: [String]
    @State private var newTag: String = ""
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("Add Tag") {
                    HStack {
                        TextField("Enter tag name", text: $newTag)
                            #if os(iOS)
                            .textInputAutocapitalization(.never)
                            #endif
                            .accessibilityIdentifier("tag_editor_input")

                        Button("Add") {
                            let trimmed = newTag.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                            if !trimmed.isEmpty && !tags.contains(trimmed) {
                                tags.append(trimmed)
                                newTag = ""
                            }
                        }
                        .disabled(newTag.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        .accessibilityIdentifier("tag_editor_add_button")
                    }
                }

                if !tags.isEmpty {
                    Section("Current Tags") {
                        ForEach(tags, id: \.self) { tag in
                            HStack {
                                Text(tag)
                                Spacer()
                                Button(action: {
                                    tags.removeAll { $0 == tag }
                                }) {
                                    Image(systemName: "minus.circle.fill")
                                        .foregroundColor(.red)
                                }
                                .accessibilityIdentifier("tag_editor_remove_\(tag)")
                            }
                        }
                    }
                }
            }
            .navigationTitle("Edit Tags")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                    .accessibilityIdentifier("tag_editor_done")
                }
            }
        }
    }
}

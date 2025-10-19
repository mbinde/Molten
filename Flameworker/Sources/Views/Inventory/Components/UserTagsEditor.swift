//
//  UserTagsEditor.swift
//  Flameworker
//
//  Created by Assistant on 10/16/25.
//  User tags editor for adding/editing tags on glass items
//

import SwiftUI

/// Editor view for creating and managing user tags on glass items
struct UserTagsEditor: View {
    let item: CompleteInventoryItemModel
    let userTagsRepository: UserTagsRepository

    @Environment(\.dismiss) private var dismiss

    // State
    @State private var existingTags: [String] = []
    @State private var newTagText: String = ""
    @State private var isSaving = false
    @State private var isLoadingTags = false
    @State private var showingError = false
    @State private var errorMessage: String?

    // Suggested common tags
    private let suggestedTags = UserTagModel.CommonTags.allCommonTags

    var body: some View {
        NavigationView {
            ZStack {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        // Item header
                        itemHeaderSection

                        // Add new tag section
                        addNewTagSection

                        // Suggested tags section
                        if !suggestedTags.isEmpty {
                            suggestedTagsSection
                        }

                        // Current tags section
                        if !existingTags.isEmpty {
                            currentTagsSection
                        } else if !isLoadingTags {
                            emptyStateSection
                        }
                    }
                    .padding()
                }

                // Loading overlay
                if isSaving {
                    Color.black.opacity(0.3)
                        .ignoresSafeArea()
                    ProgressView()
                        .scaleEffect(1.5)
                }
            }
            .navigationTitle("Manage Tags")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                    .disabled(isSaving)
                }
            }
            .onAppear {
                loadExistingTags()
            }
            .alert("Error", isPresented: $showingError) {
                Button("OK") { }
            } message: {
                Text(errorMessage ?? "An unknown error occurred")
            }
        }
    }

    // MARK: - Sections

    private var itemHeaderSection: some View {
        GlassItemCard(item: item.glassItem, variant: .compact)
    }

    private var addNewTagSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Add New Tag")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)

            HStack(spacing: 8) {
                TextField("Enter tag name", text: $newTagText)
                    .textFieldStyle(.roundedBorder)
                    #if os(iOS)
                    .autocapitalization(.none)
                    #endif
                    .disableAutocorrection(true)

                Button(action: addNewTag) {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                        .foregroundColor(.blue)
                }
                .disabled(newTagText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSaving)
            }

            // Tag validation info
            Text("Tags must be 2-30 characters, alphanumeric, hyphens, or spaces")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    private var suggestedTagsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Suggested Tags")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)

            LazyVGrid(columns: [
                GridItem(.adaptive(minimum: 100), spacing: 8)
            ], spacing: 8) {
                ForEach(filteredSuggestedTags, id: \.self) { tag in
                    Button(action: {
                        addTag(tag)
                    }) {
                        HStack(spacing: 4) {
                            TagColorCircle(tag: tag, size: 8)

                            Image(systemName: "plus.circle")
                                .font(.caption)
                            Text(tag)
                                .font(.caption)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.blue.opacity(0.1))
                        .foregroundColor(.blue)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .disabled(existingTags.contains(tag) || isSaving)
                    .opacity(existingTags.contains(tag) ? 0.5 : 1.0)
                }
            }
        }
    }

    private var currentTagsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Your Tags (\(existingTags.count))")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)

            LazyVGrid(columns: [
                GridItem(.adaptive(minimum: 100), spacing: 8)
            ], spacing: 8) {
                ForEach(existingTags.sorted(), id: \.self) { tag in
                    HStack(spacing: 4) {
                        TagColorCircle(tag: tag, size: 8)

                        Text(tag)
                            .font(.caption)
                            .foregroundColor(.primary)

                        Button(action: {
                            removeTag(tag)
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.caption)
                                .foregroundColor(.red)
                        }
                        .disabled(isSaving)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.gray.opacity(0.15))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
        }
    }

    private var emptyStateSection: some View {
        VStack(spacing: 12) {
            Image(systemName: "tag")
                .font(.system(size: 40))
                .foregroundColor(.secondary)
            Text("No tags yet")
                .font(.subheadline)
                .foregroundColor(.secondary)
            Text("Add tags to organize and categorize this item")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color.gray.opacity(0.15))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    // MARK: - Computed Properties

    /// Filter out suggested tags that are already added
    private var filteredSuggestedTags: [String] {
        suggestedTags.filter { !existingTags.contains($0) }
    }

    // MARK: - Actions

    private func loadExistingTags() {
        Task {
            isLoadingTags = true
            defer { isLoadingTags = false }

            do {
                existingTags = try await userTagsRepository.fetchTags(forItem: item.glassItem.natural_key)
            } catch {
                print("Error loading tags: \(error)")
                // Empty tags is fine, just start with empty array
            }
        }
    }

    private func addNewTag() {
        let tag = newTagText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !tag.isEmpty else { return }

        addTag(tag)
        newTagText = ""
    }

    private func addTag(_ tag: String) {
        // Validate tag
        let cleanedTag = UserTagModel.cleanTag(tag)
        guard UserTagModel.isValidTag(cleanedTag) else {
            errorMessage = "Invalid tag: '\(tag)'. Tags must be 2-30 characters and contain only letters, numbers, hyphens, or spaces."
            showingError = true
            return
        }

        // Check if already exists
        if existingTags.contains(cleanedTag) {
            return // Silently ignore duplicates
        }

        Task {
            isSaving = true
            defer { isSaving = false }

            do {
                try await userTagsRepository.addTag(tag, toItem: item.glassItem.natural_key)

                // Update local state
                if !existingTags.contains(cleanedTag) {
                    existingTags.append(cleanedTag)
                    existingTags.sort()
                }
            } catch {
                errorMessage = "Failed to add tag: \(error.localizedDescription)"
                showingError = true
            }
        }
    }

    private func removeTag(_ tag: String) {
        Task {
            isSaving = true
            defer { isSaving = false }

            do {
                try await userTagsRepository.removeTag(tag, fromItem: item.glassItem.natural_key)

                // Update local state
                existingTags.removeAll { $0 == tag }
            } catch {
                errorMessage = "Failed to remove tag: \(error.localizedDescription)"
                showingError = true
            }
        }
    }

}

// MARK: - Preview

#Preview("No Tags") {
    let sampleGlassItem = GlassItemModel(
        natural_key: "bullseye-0001-0",
        name: "Bullseye Red Opal",
        sku: "0001",
        manufacturer: "bullseye",
        mfr_notes: "A beautiful deep red opal glass.",
        coe: 90,
        url: "https://www.bullseyeglass.com",
        mfr_status: "available"
    )

    let sampleCompleteItem = CompleteInventoryItemModel(
        glassItem: sampleGlassItem,
        inventory: [],
        tags: ["red", "opal"],
        userTags: [],
        locations: []
    )

    UserTagsEditor(
        item: sampleCompleteItem,
        userTagsRepository: MockUserTagsRepository()
    )
}

#Preview("With Existing Tags") {
    let sampleGlassItem = GlassItemModel(
        natural_key: "cim-874-0",
        name: "Pale Gray",
        sku: "874",
        manufacturer: "cim",
        coe: 104,
        mfr_status: "available"
    )

    let sampleCompleteItem = CompleteInventoryItemModel(
        glassItem: sampleGlassItem,
        inventory: [],
        tags: ["gray"],
        userTags: [],
        locations: []
    )

    let mockRepo = MockUserTagsRepository()
    Task {
        try? await mockRepo.addTags(["favorite", "wishlist", "current-project"], toItem: "cim-874-0")
    }

    return UserTagsEditor(
        item: sampleCompleteItem,
        userTagsRepository: mockRepo
    )
}

//
//  CatalogTagEditorView.swift
//  Molten
//
//  Debug-only view for editing catalog tags on glass items
//  Appears at the bottom of InventoryDetailView in DEBUG builds
//

import SwiftUI

#if DEBUG

/// Debug-only editor for catalog tags
/// Allows adding/editing tags that sync via CloudKit and can be exported
struct CatalogTagEditorView: View {
    let itemStableId: String
    let catalogTagAdminRepository: CatalogTagAdminRepository
    let itemTagsRepository: ItemTagsRepository

    @State private var bundledTags: [String] = []
    @State private var adminTagAdditions: [CatalogTagAdminModel] = []
    @State private var adminTagRemovals: Set<String> = []  // Tags marked for removal
    @State private var isLoading = false
    @State private var isExpanded = false
    @State private var newTagText = ""
    @State private var allAvailableTags: [String] = []
    @State private var tagCounts: [String: Int] = [:]

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            // Header with expand/collapse
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack {
                    Image(systemName: "tag.fill")
                        .foregroundColor(DesignSystem.Colors.accentPrimary)
                    Text("Catalog Tags (Debug)")
                        .font(DesignSystem.Typography.subsectionTitle)
                        .fontWeight(DesignSystem.FontWeight.semibold)
                        .foregroundColor(DesignSystem.Colors.textPrimary)

                    Spacer()

                    let totalCount = bundledTags.count + adminTagAdditions.count - adminTagRemovals.count
                    if totalCount > 0 {
                        Text("\(totalCount)")
                            .font(DesignSystem.Typography.listItemCaption)
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(DesignSystem.Colors.accentPrimary)
                            .clipShape(Capsule())
                    }

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if isExpanded {
                expandedContent
            }
        }
        .padding(DesignSystem.Padding.standard)
        .background(DesignSystem.Colors.tintPrimary.opacity(0.3))
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.large)
                .stroke(DesignSystem.Colors.accentPrimary.opacity(0.5), lineWidth: 2)
        )
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.large))
        .task {
            await loadTags()
        }
    }

    @ViewBuilder
    private var expandedContent: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity)
            } else {
                // Bundled tags section (can be removed)
                if !bundledTags.isEmpty {
                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                        Text("Bundled Tags")
                            .font(DesignSystem.Typography.formLabel)
                            .foregroundColor(DesignSystem.Colors.textSecondary)

                        FlowLayout(spacing: DesignSystem.Spacing.xs) {
                            ForEach(bundledTags, id: \.self) { tag in
                                bundledTagChip(tag, isMarkedForRemoval: adminTagRemovals.contains(tag))
                            }
                        }
                    }
                }

                // Admin tag additions section
                if !adminTagAdditions.isEmpty {
                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                        Text("Added Tags")
                            .font(DesignSystem.Typography.formLabel)
                            .foregroundColor(DesignSystem.Colors.textSecondary)

                        FlowLayout(spacing: DesignSystem.Spacing.xs) {
                            ForEach(adminTagAdditions) { tag in
                                adminTagChip(tag)
                            }
                        }
                    }
                }

                Divider()

                // Add tag section
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                    Text("Add Tag")
                        .font(DesignSystem.Typography.formLabel)
                        .foregroundColor(DesignSystem.Colors.textSecondary)

                    HStack {
                        TextField("Enter tag name", text: $newTagText)
                            .textFieldStyle(.roundedBorder)
                            .autocapitalization(.none)
                            .disableAutocorrection(true)

                        Button {
                            Task {
                                await addTag(newTagText)
                            }
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .foregroundColor(DesignSystem.Colors.accentPrimary)
                        }
                        .disabled(newTagText.trimmingCharacters(in: .whitespaces).isEmpty)
                    }

                    // Suggestions from existing tags
                    if !newTagText.isEmpty {
                        let effectiveBundled = Set(bundledTags).subtracting(adminTagRemovals)
                        let existingTagNames = effectiveBundled.union(Set(adminTagAdditions.map { $0.tag }))
                        let suggestions = allAvailableTags.filter {
                            $0.localizedCaseInsensitiveContains(newTagText) && !existingTagNames.contains($0)
                        }.prefix(5)

                        if !suggestions.isEmpty {
                            Text("Suggestions:")
                                .font(DesignSystem.Typography.captionSmall)
                                .foregroundColor(DesignSystem.Colors.textSecondary)

                            FlowLayout(spacing: DesignSystem.Spacing.xs) {
                                ForEach(Array(suggestions), id: \.self) { suggestion in
                                    Button {
                                        Task {
                                            await addTag(suggestion)
                                        }
                                    } label: {
                                        HStack(spacing: 4) {
                                            Text(suggestion)
                                            if let count = tagCounts[suggestion] {
                                                Text("(\(count))")
                                                    .foregroundColor(DesignSystem.Colors.textSecondary)
                                            }
                                        }
                                        .font(DesignSystem.Typography.captionSmall)
                                        .padding(.horizontal, DesignSystem.Spacing.sm)
                                        .padding(.vertical, DesignSystem.Spacing.xxs)
                                        .background(DesignSystem.Colors.backgroundInputLight)
                                        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.small))
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func bundledTagChip(_ tag: String, isMarkedForRemoval: Bool) -> some View {
        HStack(spacing: 4) {
            Text(tag)
                .font(DesignSystem.Typography.listItemCaption)
                .strikethrough(isMarkedForRemoval)

            Button {
                Task {
                    if isMarkedForRemoval {
                        await unmarkTagForRemoval(tag)
                    } else {
                        await markBundledTagForRemoval(tag)
                    }
                }
            } label: {
                Image(systemName: isMarkedForRemoval ? "arrow.uturn.backward.circle.fill" : "xmark.circle.fill")
                    .font(.caption)
                    .foregroundColor(isMarkedForRemoval ? DesignSystem.Colors.accentPrimary : DesignSystem.Colors.textSecondary)
            }
        }
        .padding(.horizontal, DesignSystem.Spacing.sm)
        .padding(.vertical, DesignSystem.Spacing.xxs)
        .background(isMarkedForRemoval ? DesignSystem.Colors.accentDanger.opacity(0.2) : DesignSystem.Colors.tintTeal.opacity(0.5))
        .foregroundColor(isMarkedForRemoval ? DesignSystem.Colors.accentDanger : DesignSystem.Colors.textSecondary)
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium))
    }

    @ViewBuilder
    private func adminTagChip(_ tag: CatalogTagAdminModel) -> some View {
        HStack(spacing: 4) {
            Text(tag.tag)
                .font(DesignSystem.Typography.listItemCaption)

            Button {
                Task {
                    await removeAdminTag(tag)
                }
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.caption)
                    .foregroundColor(DesignSystem.Colors.textSecondary)
            }
        }
        .padding(.horizontal, DesignSystem.Spacing.sm)
        .padding(.vertical, DesignSystem.Spacing.xxs)
        .background(DesignSystem.Colors.tintPrimary)
        .foregroundColor(DesignSystem.Colors.accentPrimary)
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium))
    }

    // MARK: - Data Operations

    private func loadTags() async {
        isLoading = true
        defer { isLoading = false }

        do {
            // Load bundled tags from SQLite
            bundledTags = try await itemTagsRepository.fetchTags(forItem: itemStableId)

            // Load admin tag additions from CoreData
            adminTagAdditions = try await catalogTagAdminRepository.fetchTagAdditions(for: itemStableId)

            // Load admin tag removals
            let removals = try await catalogTagAdminRepository.fetchTagRemovals(for: itemStableId)
            adminTagRemovals = Set(removals.map { $0.tag })

            // Load all available tags for suggestions
            let bundledAllTags = try await itemTagsRepository.getAllTags()
            let adminAllTags = try await catalogTagAdminRepository.getAllTags()
            allAvailableTags = Array(Set(bundledAllTags + adminAllTags)).sorted()

            // Get tag counts for suggestions
            let bundledCounts = try await itemTagsRepository.getTagUsageCounts()
            let adminCounts = try await catalogTagAdminRepository.getTagUsageCounts()

            // Merge counts
            var merged = bundledCounts
            for (tag, count) in adminCounts {
                merged[tag, default: 0] += count
            }
            tagCounts = merged
        } catch {
            print("Error loading tags: \(error)")
        }
    }

    private func addTag(_ tag: String) async {
        let cleanedTag = tag.trimmingCharacters(in: .whitespaces).lowercased()
        guard !cleanedTag.isEmpty else { return }

        // Check if already exists (in bundled or admin additions, and not marked for removal)
        let effectiveBundled = Set(bundledTags).subtracting(adminTagRemovals)
        let existingTags = effectiveBundled.union(Set(adminTagAdditions.map { $0.tag }))
        guard !existingTags.contains(cleanedTag) else { return }

        do {
            try await catalogTagAdminRepository.addTag(cleanedTag, to: itemStableId)
            newTagText = ""
            await loadTags()
        } catch {
            print("Error adding tag: \(error)")
        }
    }

    private func removeAdminTag(_ tag: CatalogTagAdminModel) async {
        do {
            try await catalogTagAdminRepository.removeAdminTag(tag.id)
            await loadTags()
        } catch {
            print("Error removing tag: \(error)")
        }
    }

    private func markBundledTagForRemoval(_ tag: String) async {
        do {
            try await catalogTagAdminRepository.markTagForRemoval(tag, from: itemStableId)
            await loadTags()
        } catch {
            print("Error marking tag for removal: \(error)")
        }
    }

    private func unmarkTagForRemoval(_ tag: String) async {
        do {
            try await catalogTagAdminRepository.removeAdminTag(item_stable_id: itemStableId, tag: tag)
            await loadTags()
        } catch {
            print("Error unmarking tag for removal: \(error)")
        }
    }
}

// MARK: - Convenience Initializer

extension CatalogTagEditorView {
    /// Initialize using AppDependencies
    init(itemStableId: String, deps: AppDependencies = .shared) {
        self.itemStableId = itemStableId
        self.catalogTagAdminRepository = deps.catalogTagAdminRepository
        self.itemTagsRepository = deps.itemTagsRepository
    }
}

#endif

//
//  CatalogFlagEditorView.swift
//  Molten
//
//  Created on 2025-12-21.
//
//  Debug-only view for editing catalog flags on glass items
//  Appears at the bottom of InventoryDetailView in DEBUG builds
//

import SwiftUI

#if DEBUG

/// Debug-only editor for catalog flags
/// Allows adding/editing flags that will be exported for catalog updates
/// Also displays bundled flags (read-only) from the catalog SQLite database
struct CatalogFlagEditorView: View {
    let itemStableId: String
    let catalogFlagAdminRepository: CatalogFlagAdminRepository
    let catalogFlagBundledRepository: CatalogFlagBundledRepository
    let catalogTagAdminRepository: CatalogTagAdminRepository

    @State private var adminFlags: [CatalogFlagAdminModel] = []
    @State private var bundledFlags: [CatalogFlagBundledModel] = []
    @State private var adminFlagRemovals: Set<String> = []  // flag_keys marked for removal
    @State private var isLoading = false
    @State private var showingAddFlag = false
    @State private var exportedJSON: ExportedJSONWrapper? = nil
    @State private var isExpanded = false
    @State private var totalItemsWithData: Int = 0

    /// Total flags count (admin + bundled)
    private var totalFlagsCount: Int {
        adminFlags.count + bundledFlags.count
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            // Header with expand/collapse
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack {
                    Image(systemName: "wrench.and.screwdriver.fill")
                        .foregroundColor(DesignSystem.Colors.moltenOrange)
                    Text("Catalog Flags (Debug)")
                        .font(DesignSystem.Typography.subsectionTitle)
                        .fontWeight(DesignSystem.FontWeight.semibold)
                        .foregroundColor(DesignSystem.Colors.textPrimary)

                    Spacer()

                    if totalFlagsCount > 0 {
                        Text("\(totalFlagsCount)")
                            .font(DesignSystem.Typography.listItemCaption)
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(DesignSystem.Colors.moltenOrange)
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
        .background(DesignSystem.Colors.tintWarning.opacity(0.3))
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.large)
                .stroke(DesignSystem.Colors.moltenOrange.opacity(0.5), lineWidth: 2)
        )
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.large))
        .task {
            await loadFlags()
        }
    }

    @ViewBuilder
    private var expandedContent: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            // Loading state
            if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity)
            } else {
                // Bundled flags (from catalog.sqlite, can be marked for removal)
                if !bundledFlags.isEmpty {
                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                        HStack {
                            Image(systemName: "shippingbox.fill")
                                .foregroundColor(DesignSystem.Colors.textSecondary)
                                .font(.caption)
                            Text("Bundled (\(bundledFlags.count))")
                                .font(DesignSystem.Typography.listItemCaption)
                                .foregroundColor(DesignSystem.Colors.textSecondary)
                        }

                        ForEach(bundledFlags) { flag in
                            BundledFlagRow(
                                flag: flag,
                                isMarkedForRemoval: adminFlagRemovals.contains(flag.flag_key),
                                onMarkForRemoval: { markFlagForRemoval(flag) },
                                onUndoRemoval: { undoFlagRemoval(flag) }
                            )
                        }
                    }
                }

                // Admin flags (editable)
                if !adminFlags.isEmpty {
                    if !bundledFlags.isEmpty {
                        Divider()
                    }

                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                        HStack {
                            Image(systemName: "pencil.circle.fill")
                                .foregroundColor(DesignSystem.Colors.moltenOrange)
                                .font(.caption)
                            Text("Your Edits (\(adminFlags.count))")
                                .font(DesignSystem.Typography.listItemCaption)
                                .foregroundColor(DesignSystem.Colors.textSecondary)
                        }

                        ForEach(adminFlags) { flag in
                            FlagRow(
                                flag: flag,
                                onToggle: { toggleFlag(flag) },
                                onDelete: { deleteFlag(flag) }
                            )
                        }
                    }
                }

                // Empty state
                if bundledFlags.isEmpty && adminFlags.isEmpty {
                    Text("No flags set")
                        .font(DesignSystem.Typography.formLabel)
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, DesignSystem.Spacing.md)
                }
            }

            Divider()

            // Add flag button
            Button {
                showingAddFlag = true
            } label: {
                Label("Add Flag", systemImage: "plus.circle.fill")
                    .font(DesignSystem.Typography.formLabel)
                    .foregroundColor(DesignSystem.Colors.moltenOrange)
            }
            .buttonStyle(.plain)

            // Export button
            if totalItemsWithData > 0 {
                Button {
                    Task {
                        await exportFlags()
                    }
                } label: {
                    HStack {
                        Label("Export All", systemImage: "square.and.arrow.up")
                        Text("(\(totalItemsWithData) \(totalItemsWithData == 1 ? "item" : "items"))")
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                    }
                    .font(DesignSystem.Typography.formLabel)
                    .foregroundColor(DesignSystem.Colors.accentPrimary)
                }
                .buttonStyle(.plain)
            }
        }
        .sheet(isPresented: $showingAddFlag) {
            AddFlagSheet(
                itemStableId: itemStableId,
                existingFlags: Set(adminFlags.map { $0.flag_key }),
                onSave: { flags in
                    Task {
                        for flag in flags {
                            try? await catalogFlagAdminRepository.saveFlag(flag)
                        }
                        await loadFlags()
                    }
                }
            )
        }
        .sheet(item: $exportedJSON) { wrapper in
            ExportSheet(json: wrapper.json)
        }
    }

    private func loadFlags() async {
        isLoading = true
        defer { isLoading = false }

        do {
            // Load bundled flags (from catalog.sqlite)
            bundledFlags = try await catalogFlagBundledRepository.fetchFlags(for: itemStableId)

            // Load admin flag additions (editable)
            let allAdminAdditions = try await catalogFlagAdminRepository.fetchFlagAdditions(for: itemStableId)
            // Filter out hidden flags (handled by separate UI elements)
            adminFlags = allAdminAdditions.filter { $0.flag_key != kDescriptionReplacementKey && $0.flag_key != kProcessedKey }

            // Load admin flag removals (bundled flags marked for deletion)
            let allAdminRemovals = try await catalogFlagAdminRepository.fetchFlagRemovals(for: itemStableId)
            adminFlagRemovals = Set(allAdminRemovals.map { $0.flag_key })

            // Count total unique items with any data (admin flags only, for export)
            let allFlags = try await catalogFlagAdminRepository.fetchAllFlags()
            let uniqueItems = Set(allFlags.map { $0.item_stable_id })
            totalItemsWithData = uniqueItems.count
        } catch {
            print("Error loading flags: \(error)")
        }
    }

    private func toggleFlag(_ flag: CatalogFlagAdminModel) {
        Task {
            let updatedFlag = CatalogFlagAdminModel(
                id: flag.id,
                item_stable_id: flag.item_stable_id,
                flag_key: flag.flag_key,
                flag_value: !flag.flag_value,
                flag_numeric: flag.flag_numeric,
                created_at: flag.created_at,
                updated_at: Date()
            )
            try? await catalogFlagAdminRepository.saveFlag(updatedFlag)
            await loadFlags()
        }
    }

    private func deleteFlag(_ flag: CatalogFlagAdminModel) {
        Task {
            try? await catalogFlagAdminRepository.removeAdminFlag(flag.id)
            await loadFlags()
        }
    }

    private func markFlagForRemoval(_ flag: CatalogFlagBundledModel) {
        Task {
            try? await catalogFlagAdminRepository.markFlagForRemoval(
                item_stable_id: itemStableId,
                flag_key: flag.flag_key
            )
            await loadFlags()
        }
    }

    private func undoFlagRemoval(_ flag: CatalogFlagBundledModel) {
        Task {
            try? await catalogFlagAdminRepository.removeAdminFlag(
                item_stable_id: itemStableId,
                flag_key: flag.flag_key
            )
            await loadFlags()
        }
    }

    @MainActor
    private func exportFlags() async {
        do {
            let allFlags = try await catalogFlagAdminRepository.fetchAllFlags()
            let allTags = try await catalogTagAdminRepository.fetchAllTags()
            print("DEBUG: fetchAllFlags returned \(allFlags.count) flags, \(allTags.count) tags")

            // Separate flags into additions and removals, excluding special keys
            let regularFlags = allFlags.filter { $0.flag_key != kDescriptionReplacementKey && $0.flag_key != kProcessedKey }
            let flagAdditions = regularFlags.filter { !$0.is_removal }
            let flagRemovals = regularFlags.filter { $0.is_removal }
            let descriptionReplacements = allFlags.filter { $0.flag_key == kDescriptionReplacementKey && !$0.is_removal }
            print("DEBUG: flagAdditions=\(flagAdditions.count), flagRemovals=\(flagRemovals.count), descReplacements=\(descriptionReplacements.count)")

            // Build JSON manually to avoid Codable actor isolation issues
            var json = "{\n"
            json += "  \"version\": \"1.2\",\n"

            let formatter = ISO8601DateFormatter()
            json += "  \"exported_at\": \"\(formatter.string(from: Date()))\",\n"

            // Flags array (additions only)
            json += "  \"flags\": [\n"
            for (index, flag) in flagAdditions.enumerated() {
                let comma = index < flagAdditions.count - 1 ? "," : ""
                let numericStr = flag.flag_numeric.map { String($0) } ?? "null"
                json += "    { \"item_stable_id\": \"\(flag.item_stable_id)\", \"flag_key\": \"\(flag.flag_key)\", \"flag_value\": \(flag.flag_value), \"flag_numeric\": \(numericStr) }\(comma)\n"
            }
            json += "  ],\n"

            // Flag removals array
            json += "  \"flag_removals\": [\n"
            for (index, flag) in flagRemovals.enumerated() {
                let comma = index < flagRemovals.count - 1 ? "," : ""
                json += "    { \"item_stable_id\": \"\(flag.item_stable_id)\", \"flag_key\": \"\(flag.flag_key)\" }\(comma)\n"
            }
            json += "  ],\n"

            // Description replacements array
            json += "  \"description_replacements\": [\n"
            let validReplacements = descriptionReplacements.filter { $0.description_replacement != nil }
            for (index, flag) in validReplacements.enumerated() {
                let comma = index < validReplacements.count - 1 ? "," : ""
                let escapedDesc = (flag.description_replacement ?? "")
                    .replacingOccurrences(of: "\\", with: "\\\\")
                    .replacingOccurrences(of: "\"", with: "\\\"")
                    .replacingOccurrences(of: "\n", with: "\\n")
                json += "    { \"item_stable_id\": \"\(flag.item_stable_id)\", \"description\": \"\(escapedDesc)\" }\(comma)\n"
            }
            json += "  ],\n"

            // Separate tag additions from removals
            let tagAdditions = allTags.filter { !$0.is_removal }
            let tagRemovals = allTags.filter { $0.is_removal }

            // Tags array (additions)
            json += "  \"tags\": [\n"
            for (index, tag) in tagAdditions.enumerated() {
                let comma = index < tagAdditions.count - 1 ? "," : ""
                json += "    { \"item_stable_id\": \"\(tag.item_stable_id)\", \"tag\": \"\(tag.tag)\" }\(comma)\n"
            }
            json += "  ],\n"

            // Tag removals array
            json += "  \"tag_removals\": [\n"
            for (index, tag) in tagRemovals.enumerated() {
                let comma = index < tagRemovals.count - 1 ? "," : ""
                json += "    { \"item_stable_id\": \"\(tag.item_stable_id)\", \"tag\": \"\(tag.tag)\" }\(comma)\n"
            }
            json += "  ]\n"
            json += "}"

            print("DEBUG: Built JSON with \(json.count) characters")
            exportedJSON = ExportedJSONWrapper(json: json)
        } catch {
            print("ERROR exporting flags: \(error)")
            exportedJSON = ExportedJSONWrapper(json: "Error: \(error.localizedDescription)")
        }
    }
}

// MARK: - Flag Row

private struct FlagRow: View {
    let flag: CatalogFlagAdminModel
    let onToggle: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: DesignSystem.Spacing.md) {
            // Toggle button
            Button {
                onToggle()
            } label: {
                Image(systemName: flag.flag_value ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(flag.flag_value ? DesignSystem.Colors.accentSuccess : DesignSystem.Colors.textTertiary)
                    .font(.title3)
            }
            .buttonStyle(.plain)

            // Flag info
            VStack(alignment: .leading, spacing: 2) {
                if let key = flag.typedFlagKey {
                    Text(key.displayName)
                        .font(DesignSystem.Typography.formLabel)
                        .foregroundColor(DesignSystem.Colors.textPrimary)

                    if let numeric = flag.flag_numeric, let unit = key.valueUnit {
                        Text("\(Int(numeric))\(unit)")
                            .font(DesignSystem.Typography.listItemCaption)
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                    }
                } else {
                    Text(flag.flag_key)
                        .font(DesignSystem.Typography.formLabel)
                        .foregroundColor(DesignSystem.Colors.textPrimary)
                }
            }

            Spacer()

            // Delete button
            Button(role: .destructive) {
                onDelete()
            } label: {
                Image(systemName: "trash")
                    .font(.caption)
                    .foregroundColor(DesignSystem.Colors.accentDanger)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, DesignSystem.Spacing.xs)
    }
}

// MARK: - Bundled Flag Row (Can be marked for removal)

private struct BundledFlagRow: View {
    let flag: CatalogFlagBundledModel
    let isMarkedForRemoval: Bool
    let onMarkForRemoval: () -> Void
    let onUndoRemoval: () -> Void

    var body: some View {
        HStack(spacing: DesignSystem.Spacing.md) {
            // Checkmark (shows removal state)
            Image(systemName: isMarkedForRemoval ? "xmark.circle.fill" : "checkmark.circle.fill")
                .foregroundColor(isMarkedForRemoval ? DesignSystem.Colors.accentDanger : DesignSystem.Colors.textSecondary)
                .font(.title3)

            // Flag info
            VStack(alignment: .leading, spacing: 2) {
                if let key = flag.typedFlagKey {
                    Text(key.displayName)
                        .font(DesignSystem.Typography.formLabel)
                        .foregroundColor(isMarkedForRemoval ? DesignSystem.Colors.textTertiary : DesignSystem.Colors.textSecondary)
                        .strikethrough(isMarkedForRemoval, color: DesignSystem.Colors.accentDanger)

                    if let numeric = flag.flag_numeric, let unit = key.valueUnit {
                        Text("\(Int(numeric))\(unit)")
                            .font(DesignSystem.Typography.listItemCaption)
                            .foregroundColor(DesignSystem.Colors.textTertiary)
                            .strikethrough(isMarkedForRemoval, color: DesignSystem.Colors.accentDanger)
                    }
                } else {
                    Text(flag.flag_key)
                        .font(DesignSystem.Typography.formLabel)
                        .foregroundColor(isMarkedForRemoval ? DesignSystem.Colors.textTertiary : DesignSystem.Colors.textSecondary)
                        .strikethrough(isMarkedForRemoval, color: DesignSystem.Colors.accentDanger)
                }
            }

            Spacer()

            // Remove/Undo button
            if isMarkedForRemoval {
                Button {
                    onUndoRemoval()
                } label: {
                    Image(systemName: "arrow.uturn.backward.circle.fill")
                        .font(.caption)
                        .foregroundColor(DesignSystem.Colors.accentPrimary)
                }
                .buttonStyle(.plain)
            } else {
                Button {
                    onMarkForRemoval()
                } label: {
                    Image(systemName: "xmark.circle")
                        .font(.caption)
                        .foregroundColor(DesignSystem.Colors.textTertiary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, DesignSystem.Spacing.xs)
        .opacity(isMarkedForRemoval ? 0.6 : 0.8)
    }
}

// MARK: - Add Flag Sheet

private struct AddFlagSheet: View {
    let itemStableId: String
    let existingFlags: Set<String>
    let onSave: ([CatalogFlagAdminModel]) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var selectedFlagKeys: Set<GlassFlagKey> = []
    @State private var numericValues: [GlassFlagKey: String] = [:]
    @State private var searchText: String = ""

    private var availableFlags: [GlassFlagKey] {
        GlassFlagKey.allCases.filter { !existingFlags.contains($0.rawValue) }
    }

    private var filteredFlags: [GlassFlagKey] {
        if searchText.isEmpty {
            return availableFlags.sorted { $0.displayName < $1.displayName }
        }
        let lowercasedSearch = searchText.lowercased()
        return availableFlags.filter {
            $0.displayName.lowercased().contains(lowercasedSearch) ||
            $0.rawValue.lowercased().contains(lowercasedSearch)
        }.sorted { $0.displayName < $1.displayName }
    }

    private var selectedNumericFlags: [GlassFlagKey] {
        selectedFlagKeys.filter { $0.requiresNumericValue }.sorted { $0.displayName < $1.displayName }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Select Flags") {
                    ForEach(filteredFlags, id: \.rawValue) { flagKey in
                        Button {
                            if selectedFlagKeys.contains(flagKey) {
                                selectedFlagKeys.remove(flagKey)
                                numericValues.removeValue(forKey: flagKey)
                            } else {
                                selectedFlagKeys.insert(flagKey)
                            }
                        } label: {
                            HStack {
                                Image(systemName: selectedFlagKeys.contains(flagKey) ? "checkmark.square.fill" : "square")
                                    .foregroundColor(selectedFlagKeys.contains(flagKey) ? DesignSystem.Colors.accentPrimary : DesignSystem.Colors.textSecondary)
                                Text(flagKey.displayName)
                                    .foregroundColor(DesignSystem.Colors.textPrimary)
                                Spacer()
                                if flagKey.requiresNumericValue {
                                    Text(flagKey.valueUnit ?? "")
                                        .font(.caption)
                                        .foregroundColor(DesignSystem.Colors.textSecondary)
                                }
                            }
                        }
                    }
                }

                if !selectedNumericFlags.isEmpty {
                    Section("Numeric Values") {
                        ForEach(selectedNumericFlags, id: \.rawValue) { flagKey in
                            HStack {
                                Text(flagKey.displayName)
                                    .foregroundColor(DesignSystem.Colors.textPrimary)
                                Spacer()
                                TextField("Value", text: Binding(
                                    get: { numericValues[flagKey] ?? "" },
                                    set: { numericValues[flagKey] = $0 }
                                ))
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                                .frame(width: 80)
                                if let unit = flagKey.valueUnit {
                                    Text(unit)
                                        .foregroundColor(DesignSystem.Colors.textSecondary)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Add Flags")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save \(selectedFlagKeys.count > 0 ? "(\(selectedFlagKeys.count))" : "")") {
                        saveFlags()
                    }
                    .disabled(selectedFlagKeys.isEmpty || !isValid)
                }
            }
            .searchable(text: $searchText, prompt: "Search flags")
        }
        .presentationDetents([.medium, .large])
    }

    private var isValid: Bool {
        // Check that all selected numeric flags have valid values
        for flagKey in selectedNumericFlags {
            guard let valueStr = numericValues[flagKey], Double(valueStr) != nil else {
                return false
            }
        }
        return true
    }

    private func saveFlags() {
        var flags: [CatalogFlagAdminModel] = []

        for flagKey in selectedFlagKeys {
            let numeric: Double?
            if flagKey.requiresNumericValue {
                numeric = Double(numericValues[flagKey] ?? "")
            } else {
                numeric = nil
            }

            let flag = CatalogFlagAdminModel(
                item_stable_id: itemStableId,
                flagKey: flagKey,
                flag_value: true,
                flag_numeric: numeric
            )
            flags.append(flag)
        }

        onSave(flags)
        dismiss()
    }
}

// MARK: - Export Wrapper

struct ExportedJSONWrapper: Identifiable {
    let id = UUID()
    let json: String
}

// MARK: - Export Sheet

private struct ExportSheet: View {
    let json: String

    @Environment(\.dismiss) private var dismiss
    @State private var showCopied = false
    @State private var fileURL: URL? = nil

    var body: some View {
        NavigationStack {
            ScrollView {
                Text(json)
                    .font(.system(.caption, design: .monospaced))
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)
            }
            .navigationTitle("Export (\(json.count) chars)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if let url = fileURL {
                        ShareLink(item: url) {
                            Label("Share", systemImage: "square.and.arrow.up")
                        }
                    } else {
                        Button {
                            UIPasteboard.general.string = json
                            showCopied = true
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                showCopied = false
                            }
                        } label: {
                            if showCopied {
                                Label("Copied!", systemImage: "checkmark")
                            } else {
                                Label("Copy", systemImage: "doc.on.doc")
                            }
                        }
                    }
                }
            }
            .task {
                // Write JSON to a temp file for sharing
                let formatter = DateFormatter()
                formatter.dateFormat = "yyyy-MM-dd-HHmmss"
                let filename = "catalog-flags-\(formatter.string(from: Date())).json"
                let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
                do {
                    try json.write(to: tempURL, atomically: true, encoding: .utf8)
                    fileURL = tempURL
                } catch {
                    print("Failed to write temp file: \(error)")
                }
            }
        }
    }
}

// MARK: - Preview

#Preview {
    let deps = AppDependencies(persistenceController: .createTestController())
    return CatalogFlagEditorView(
        itemStableId: "bullseye-0001-0",
        catalogFlagAdminRepository: deps.catalogFlagAdminRepository,
        catalogFlagBundledRepository: deps.catalogFlagBundledRepository,
        catalogTagAdminRepository: deps.catalogTagAdminRepository
    )
    .padding()
}

#endif

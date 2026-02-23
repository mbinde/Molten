//
//  CatalogDescriptionEditorView.swift
//  Molten
//
//  Created on 2025-12-21.
//
//  Admin UI view for editing catalog descriptions
//  Appears below the flag editor in InventoryDetailView when FLAG_ADMIN_UI is enabled
//

import SwiftUI

#if FLAG_ADMIN_UI

/// Admin UI editor for catalog descriptions
/// Pre-populates with current description, auto-saves when changed
struct CatalogDescriptionEditorView: View {
    let itemStableId: String
    let currentDescription: String?
    let catalogFlagAdminRepository: CatalogFlagAdminRepository

    @State private var editedDescription: String = ""
    @State private var isExpanded = false
    @State private var isLoading = false
    @State private var isSaving = false
    @State private var existingRecord: CatalogFlagAdminModel?
    @State private var hasUnsavedChanges = false
    @FocusState private var isTextEditorFocused: Bool

    /// The original description to compare against (trimmed)
    private var originalDescription: String {
        (currentDescription ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// The edited description (trimmed) for comparison
    private var trimmedEditedDescription: String {
        editedDescription.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Whether the description has meaningful changes
    private var hasChanges: Bool {
        trimmedEditedDescription != originalDescription
    }

    /// Whether we have a replacement saved
    private var hasSavedReplacement: Bool {
        existingRecord?.description_replacement != nil
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
                    Image(systemName: "text.quote")
                        .foregroundColor(DesignSystem.Colors.moltenTeal)
                    Text("Description Editor (Debug)")
                        .font(DesignSystem.Typography.subsectionTitle)
                        .fontWeight(DesignSystem.FontWeight.semibold)
                        .foregroundColor(DesignSystem.Colors.textPrimary)

                    Spacer()

                    if hasSavedReplacement {
                        Text("Modified")
                            .font(DesignSystem.Typography.listItemCaption)
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(DesignSystem.Colors.moltenTeal)
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
        .background(DesignSystem.Colors.tintTeal.opacity(0.3))
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.large)
                .stroke(DesignSystem.Colors.moltenTeal.opacity(0.5), lineWidth: 2)
        )
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.large))
        .task {
            await loadExistingReplacement()
        }
    }

    @ViewBuilder
    private var expandedContent: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity)
            } else {
                // Paste and Clear buttons at top
                HStack {
                    Button {
                        if let pastedText = UIPasteboard.general.string {
                            editedDescription = pastedText
                            hasUnsavedChanges = true
                        }
                    } label: {
                        Label("Paste", systemImage: "doc.on.clipboard")
                            .font(DesignSystem.Typography.listItemCaption)
                            .foregroundColor(DesignSystem.Colors.accentPrimary)
                    }
                    .buttonStyle(.plain)
                    .disabled(UIPasteboard.general.string == nil)

                    Spacer()

                    Button {
                        editedDescription = ""
                        hasUnsavedChanges = true
                    } label: {
                        Label("Clear", systemImage: "xmark.circle")
                            .font(DesignSystem.Typography.listItemCaption)
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                    }
                    .buttonStyle(.plain)
                    .disabled(editedDescription.isEmpty)
                }

                // Text editor
                TextEditor(text: $editedDescription)
                    .font(DesignSystem.Typography.formValue)
                    .frame(minHeight: 150)
                    .padding(DesignSystem.Spacing.sm)
                    .background(DesignSystem.Colors.backgroundSecondary)
                    .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium))
                    .focused($isTextEditorFocused)
                    .onChange(of: editedDescription) { _, _ in
                        hasUnsavedChanges = hasChanges
                    }
                    .onChange(of: isTextEditorFocused) { _, focused in
                        if !focused {
                            // Auto-save on blur
                            Task {
                                await saveIfNeeded()
                            }
                        }
                    }

                // Status row
                HStack {
                    if isSaving {
                        ProgressView()
                            .scaleEffect(0.8)
                        Text("Saving...")
                            .font(DesignSystem.Typography.listItemCaption)
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                    } else if hasUnsavedChanges {
                        Image(systemName: "circle.fill")
                            .font(.system(size: 8))
                            .foregroundColor(DesignSystem.Colors.moltenAmber)
                        Text("Unsaved changes")
                            .font(DesignSystem.Typography.listItemCaption)
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                    } else if hasSavedReplacement {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.caption)
                            .foregroundColor(DesignSystem.Colors.accentSuccess)
                        Text("Replacement saved")
                            .font(DesignSystem.Typography.listItemCaption)
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                    }

                    Spacer()

                    // Revert button
                    if hasSavedReplacement || hasUnsavedChanges {
                        Button {
                            revertToOriginal()
                        } label: {
                            Label("Revert", systemImage: "arrow.uturn.backward")
                                .font(DesignSystem.Typography.listItemCaption)
                                .foregroundColor(DesignSystem.Colors.accentDanger)
                        }
                        .buttonStyle(.plain)
                    }
                }

                // Done/Save button - shows when editing or when there are unsaved changes
                if isTextEditorFocused || hasUnsavedChanges {
                    Button {
                        isTextEditorFocused = false
                        Task {
                            await saveIfNeeded()
                        }
                    } label: {
                        Text(isTextEditorFocused ? "Done Editing" : "Save")
                            .font(DesignSystem.Typography.formLabel)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
    }

    private func loadExistingReplacement() async {
        isLoading = true
        defer { isLoading = false }

        do {
            let flags = try await catalogFlagAdminRepository.fetchFlags(for: itemStableId)
            existingRecord = flags.first { $0.flag_key == kDescriptionReplacementKey }

            // Pre-populate with saved replacement or original description
            if let saved = existingRecord?.description_replacement {
                editedDescription = saved
            } else {
                editedDescription = currentDescription ?? ""
            }
        } catch {
            print("Error loading description replacement: \(error)")
            editedDescription = currentDescription ?? ""
        }
    }

    private func saveIfNeeded() async {
        // Only save if there are meaningful changes
        guard hasChanges else {
            // If reverted to original, delete the record
            if let existing = existingRecord {
                await deleteReplacement(existing)
            }
            return
        }

        isSaving = true
        defer {
            isSaving = false
            hasUnsavedChanges = false
        }

        do {
            let flag = CatalogFlagAdminModel(
                id: existingRecord?.id ?? UUID(),
                item_stable_id: itemStableId,
                flag_key: kDescriptionReplacementKey,
                flag_value: true,
                flag_numeric: nil,
                description_replacement: trimmedEditedDescription,
                created_at: existingRecord?.created_at ?? Date(),
                updated_at: Date()
            )
            try await catalogFlagAdminRepository.saveFlag(flag)
            existingRecord = flag
        } catch {
            print("Error saving description replacement: \(error)")
        }
    }

    private func deleteReplacement(_ record: CatalogFlagAdminModel) async {
        do {
            try await catalogFlagAdminRepository.removeAdminFlag(record.id)
            existingRecord = nil
        } catch {
            print("Error deleting description replacement: \(error)")
        }
    }

    private func revertToOriginal() {
        editedDescription = currentDescription ?? ""
        hasUnsavedChanges = false

        // Delete saved replacement if exists
        if let existing = existingRecord {
            Task {
                await deleteReplacement(existing)
            }
        }
    }
}

// MARK: - Preview

#Preview {
    let deps = AppDependencies(persistenceController: .createTestController())
    return CatalogDescriptionEditorView(
        itemStableId: "bullseye-0001-0",
        currentDescription: "A beautiful deep red opal glass with excellent working properties. This color strikes when reheated and develops rich depth when properly annealed.",
        catalogFlagAdminRepository: deps.catalogFlagAdminRepository
    )
    .padding()
}

#endif

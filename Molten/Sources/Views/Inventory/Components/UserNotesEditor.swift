//
//  UserNotesEditor.swift
//  Flameworker
//
//  Created by Assistant on 10/16/25.
//  User notes editor for adding/editing notes on glass items
//

import SwiftUI

/// Editor view for creating and editing user notes on glass items
struct UserNotesEditor: View {
    let item: CompleteInventoryItemModel
    let userNotesRepository: UserNotesRepository

    @Environment(\.dismiss) private var dismiss

    // State
    @State private var notesText: String = ""
    @State private var existingNotes: UserNotesModel?
    @State private var isSaving = false
    @State private var isDeleting = false
    @State private var showingDeleteConfirmation = false
    @State private var showingError = false
    @State private var errorMessage: String?

    // Character limit
    private let characterLimit = 5000

    var body: some View {
        NavigationView {
            ZStack {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        // Item header
                        itemHeaderSection

                        // Notes editor
                        notesEditorSection

                        // Character count
                        characterCountSection

                        // Delete button (if notes exist)
                        if existingNotes != nil {
                            deleteButton
                        }
                    }
                    .padding()
                }

                // Loading overlay
                if isSaving || isDeleting {
                    Color.black.opacity(0.3)
                        .ignoresSafeArea()
                    ProgressView()
                        .scaleEffect(1.5)
                }
            }
            .navigationTitle(existingNotes == nil ? "Add Note" : "Edit Note")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .disabled(isSaving || isDeleting)
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveNotes()
                    }
                    .disabled(notesText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSaving || isDeleting)
                }
            }
            .onAppear {
                loadExistingNotes()
            }
            .alert("Error", isPresented: $showingError) {
                Button("OK") { }
            } message: {
                Text(errorMessage ?? "An unknown error occurred")
            }
            .confirmationDialog(
                isPresented: $showingDeleteConfirmation,
                title: "Delete Note",
                message: "Are you sure you want to delete this note? This action cannot be undone.",
                confirmTitle: "Delete",
                confirmRole: .destructive,
                onConfirm: {
                    deleteNotes()
                }
            )
        }
    }

    // MARK: - Sections

    private var itemHeaderSection: some View {
        GlassItemCard(item: item.glassItem, variant: .compact)
    }

    private var notesEditorSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Your Notes")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)

            TextEditor(text: $notesText)
                .frame(minHeight: 200)
                .padding(8)
                .background(DesignSystem.Colors.background)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                )
                .onChange(of: notesText) { _, newValue in
                    // Enforce character limit
                    if newValue.count > characterLimit {
                        notesText = String(newValue.prefix(characterLimit))
                    }
                }
        }
    }

    private var characterCountSection: some View {
        HStack {
            Spacer()
            Text("\(notesText.count) / \(characterLimit)")
                .font(.caption)
                .foregroundColor(notesText.count >= characterLimit ? .red : .secondary)
        }
    }

    private var deleteButton: some View {
        VStack(spacing: 12) {
            Divider()

            Button(action: {
                showingDeleteConfirmation = true
            }) {
                HStack {
                    Image(systemName: "trash")
                    Text("Delete Note")
                }
                .frame(maxWidth: .infinity)
                .foregroundColor(.red)
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
            .disabled(isSaving || isDeleting)
        }
        .padding(.top)
    }

    // MARK: - Actions

    private func loadExistingNotes() {
        Task {
            do {
                existingNotes = try await userNotesRepository.fetchNotes(forItem: item.glassItem.natural_key)
                if let notes = existingNotes {
                    notesText = notes.notes
                }
            } catch {
                // No existing notes is fine, just start with empty
                print("No existing notes found or error loading: \(error)")
            }
        }
    }

    private func saveNotes() {
        Task {
            isSaving = true
            defer { isSaving = false }

            do {
                let trimmedNotes = notesText.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmedNotes.isEmpty else {
                    errorMessage = "Notes cannot be empty"
                    showingError = true
                    return
                }

                let notes = UserNotesModel(
                    id: existingNotes?.id ?? UUID().uuidString,
                    item_natural_key: item.glassItem.natural_key,
                    notes: trimmedNotes
                )

                _ = try await userNotesRepository.setNotes(notes)
                dismiss()
            } catch {
                errorMessage = "Failed to save notes: \(error.localizedDescription)"
                showingError = true
            }
        }
    }

    private func deleteNotes() {
        Task {
            isDeleting = true
            defer { isDeleting = false }

            do {
                try await userNotesRepository.deleteNotes(forItem: item.glassItem.natural_key)
                dismiss()
            } catch {
                errorMessage = "Failed to delete notes: \(error.localizedDescription)"
                showingError = true
            }
        }
    }
}

// MARK: - Preview

#Preview("New Note") {
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

    UserNotesEditor(
        item: sampleCompleteItem,
        userNotesRepository: MockUserNotesRepository()
    )
}

#Preview("Edit Existing Note") {
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

    let mockRepo = MockUserNotesRepository()
    Task {
        _ = try? await mockRepo.createNotes(UserNotesModel(
            item_natural_key: "cim-874-0",
            notes: "This gray works great for backgrounds and neutral tones."
        ))
    }

    return UserNotesEditor(
        item: sampleCompleteItem,
        userNotesRepository: mockRepo
    )
}

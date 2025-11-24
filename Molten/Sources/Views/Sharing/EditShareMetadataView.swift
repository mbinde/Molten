//
//  EditShareMetadataView.swift
//  Molten
//
//  View for editing share metadata (display name and notes)
//

import SwiftUI

struct EditShareMetadataView: View {

    @Environment(\.dismiss) private var dismiss
    @Bindable var viewModel: InventorySharingViewModel

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Display Name", text: $viewModel.displayName)
                        .textContentType(.name)

                    TextField("Notes (Optional)", text: $viewModel.shareNotes, axis: .vertical)
                        .lineLimit(3...6)
                } header: {
                    Text("Share Information")
                } footer: {
                    Text("Your display name and notes will be visible to anyone who adds your share code.")
                }

                if let error = viewModel.errorMessage {
                    Section {
                        Text(error)
                            .foregroundColor(.red)
                            .font(.caption)
                    }
                }
            }
            .navigationTitle("Edit Share Info")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .accessibilityIdentifier("edit_share_cancel")
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task {
                            await viewModel.updateMyShareMetadata()
                            if viewModel.errorMessage == nil {
                                dismiss()
                            }
                        }
                    }
                    .disabled(viewModel.displayName.trimmingCharacters(in: .whitespaces).isEmpty || viewModel.isLoading)
                    .accessibilityIdentifier("edit_share_save")
                }
            }
        }
    }
}

#Preview {
    EditShareMetadataView(viewModel: InventorySharingViewModel())
}

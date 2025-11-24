//
//  CreateShareView.swift
//  Molten
//
//  View for creating a new share with metadata
//

import SwiftUI

struct CreateShareView: View {

    @Environment(\.dismiss) private var dismiss
    @Bindable var viewModel: InventorySharingViewModel

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Name (shared with others)", text: $viewModel.displayName)
                        .textContentType(.name)

                    TextField("Notes (Optional; shared with others)", text: $viewModel.shareNotes, axis: .vertical)
                        .lineLimit(3...6)
                } header: {
                    Text("Share Information")
                } footer: {
                    Text("Your display name and notes will be visible to anyone who adds your share code.")
                }

                Section {
                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                        Label("Automatic Deletion", systemImage: "clock.arrow.circlepath")
                            .font(.subheadline)
                            .fontWeight(.medium)

                        Text("Your share will be automatically deleted from the server 90 days after your last inventory update. Update your inventory at least once every 90 days to keep your share active.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("You can revoke your share at any time on the Inventory Sharing screen, and it will disappear from other devices the next time they try to open it.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, DesignSystem.Spacing.xs)
                } header: {
                    Text("Privacy & Data Retention")
                }

                if let error = viewModel.errorMessage {
                    Section {
                        Text(error)
                            .foregroundColor(.red)
                            .font(.caption)
                    }
                }
            }
            .navigationTitle("Create Share")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .accessibilityIdentifier("create_share_cancel")
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        Task {
                            await viewModel.createMyShare()
                            if viewModel.errorMessage == nil {
                                dismiss()
                            }
                        }
                    }
                    .disabled(viewModel.displayName.trimmingCharacters(in: .whitespaces).isEmpty || viewModel.isCreatingShare)
                    .accessibilityIdentifier("create_share_create")
                }
            }
        }
    }
}

#Preview {
    CreateShareView(viewModel: InventorySharingViewModel())
}

//
//  AddFriendView.swift
//  Molten
//
//  View for adding a friend by share code
//

import SwiftUI

struct AddFriendView: View {

    @Environment(\.dismiss) private var dismiss
    @Bindable var viewModel: InventorySharingViewModel

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Share Code", text: $viewModel.friendShareCode)
                        .textContentType(.oneTimeCode)
                        .autocapitalization(.allCharacters)
                        .disableAutocorrection(true)
                } header: {
                    Text("Share Code")
                } footer: {
                    Text("Ask your friend for their 6-character share code")
                }

                Section {
                    TextField("Nickname (Optional)", text: $viewModel.friendNickname)
                        .textContentType(.nickname)
                } header: {
                    Text("Customization")
                } footer: {
                    Text("Their display name will come from their share. Add a personal nickname to remember how you know them (e.g., \"Bob from GAS 2025\").")
                }

                if let error = viewModel.errorMessage {
                    Section {
                        Text(error)
                            .foregroundColor(.red)
                            .font(.caption)
                    }
                }
            }
            .navigationTitle("Add Friend")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        Task {
                            await viewModel.addFriend()
                            if viewModel.errorMessage == nil {
                                dismiss()
                            }
                        }
                    }
                    .disabled(viewModel.friendShareCode.isEmpty || viewModel.isAddingFriend)
                }
            }
        }
    }
}

#Preview {
    AddFriendView(viewModel: InventorySharingViewModel())
}

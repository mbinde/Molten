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
                    TextField("Friend's Name (Optional)", text: $viewModel.friendName)
                        .textContentType(.name)

                    TextField("Nickname (Optional)", text: $viewModel.friendNickname)
                        .textContentType(.nickname)
                } header: {
                    Text("Customization")
                } footer: {
                    Text("If left blank, their display name from the share will be used. Add a nickname to remember how you know them.")
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

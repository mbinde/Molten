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
    @FocusState private var focusedCharacterIndex: Int?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    ShareCodeInputView(
                        shareCode: $viewModel.friendShareCode,
                        focusedIndex: $focusedCharacterIndex
                    )
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
                            .foregroundColor(DesignSystem.Colors.accentDanger)
                            .font(DesignSystem.Typography.listItemCaption)
                    }
                }
            }
            .navigationTitle("Add Friend")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                // Clear form fields when sheet appears (unless pre-filled from deep link)
                if viewModel.friendShareCode.isEmpty {
                    viewModel.friendNickname = ""
                }
                viewModel.clearError()
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .accessibilityIdentifier("add_friend_cancel")
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
                    .accessibilityIdentifier("add_friend_add")
                }
            }
        }
    }
}

// MARK: - Share Code Input View

struct ShareCodeInputView: View {
    @Binding var shareCode: String
    @FocusState.Binding var focusedIndex: Int?

    private let characterLimit = 6

    private var characters: [String] {
        let code = shareCode.unformattedShareCode.uppercased()
        let chars = Array(code.prefix(characterLimit)).map { String($0) }
        return chars + Array(repeating: "", count: max(0, characterLimit - chars.count))
    }

    var body: some View {
        HStack(spacing: 8) {
            // First 3 characters
            ForEach(0..<3, id: \.self) { index in
                CharacterBox(
                    character: characters[index],
                    isFocused: focusedIndex == index
                )
                .onTapGesture {
                    focusedIndex = index
                }
            }

            // Dash separator
            Text("-")
                .font(.system(.title, design: .monospaced))
                .fontWeight(DesignSystem.FontWeight.bold)
                .foregroundColor(DesignSystem.Colors.textSecondary)

            // Last 3 characters
            ForEach(3..<6, id: \.self) { index in
                CharacterBox(
                    character: characters[index],
                    isFocused: focusedIndex == index
                )
                .onTapGesture {
                    focusedIndex = index
                }
            }
        }
        .padding(.vertical, 8)
        .background(
            // Hidden TextField for keyboard input
            TextField("", text: $shareCode)
                .textContentType(.oneTimeCode)
                .autocapitalization(.allCharacters)
                .disableAutocorrection(true)
                .keyboardType(.asciiCapable)
                .opacity(0)
                .focused($focusedIndex, equals: 0)
                .onChange(of: shareCode) { oldValue, newValue in
                    // Limit to 6 characters and uppercase
                    let cleaned = newValue.unformattedShareCode.uppercased()
                    shareCode = String(cleaned.prefix(characterLimit))

                    // Auto-advance focus
                    if shareCode.count == characterLimit {
                        focusedIndex = nil
                    }
                }
        )
        .onTapGesture {
            // Focus hidden text field when tapping anywhere
            focusedIndex = 0
        }
        .onAppear {
            // Auto-focus on appear
            focusedIndex = 0
        }
    }
}

struct CharacterBox: View {
    let character: String
    let isFocused: Bool

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium)
                .stroke(isFocused ? DesignSystem.Colors.moltenOrange : DesignSystem.Colors.textTertiary.opacity(0.3), lineWidth: 2)
                .background(
                    RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium)
                        .fill(DesignSystem.Colors.backgroundSecondary)
                )

            Text(character)
                .font(.system(.title, design: .monospaced))
                .fontWeight(DesignSystem.FontWeight.bold)
                .foregroundColor(character.isEmpty ? .clear : DesignSystem.Colors.textPrimary)
        }
        .frame(width: 40, height: 50)
    }
}

#Preview {
    AddFriendView(viewModel: InventorySharingViewModel())
}

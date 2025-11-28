//
//  CustomizeFriendView.swift
//  Molten
//
//  View for customizing friend icon and colors
//

import SwiftUI

struct CustomizeFriendView: View {

    @Environment(\.dismiss) private var dismiss
    let friend: FriendShare
    @Bindable var viewModel: InventorySharingViewModel

    @State private var selectedSymbol: String
    @State private var selectedBackgroundColor: Color
    @State private var selectedForegroundColor: Color
    @State private var nickname: String

    // Common SF Symbols for friend icons
    private let commonSymbols = [
        // Basic shapes
        "circle.fill",
        "square.fill",
        "triangle.fill",
        "diamond.fill",
        "hexagon.fill",

        // People & animals
        "person.circle.fill",
        "person.2.fill",
        "pawprint.fill",
        "tortoise.fill",
        "hare.fill",
        "bird.fill",

        // Nature & weather
        "star.fill",
        "moon.fill",
        "sun.max.fill",
        "cloud.fill",
        "snowflake",
        "leaf.fill",
        "drop.fill",
        "flame.fill",
        "sparkles",

        // Objects & symbols
        "heart.fill",
        "bolt.fill",
        "crown.fill",
        "gift.fill",
        "balloon.fill",
        "music.note",
        "pencil",
        "paintbrush.fill",
        "wrench.fill",
        "hammer.fill"
    ]

    // Common background colors with good contrast
    // Molten brand colors first, then iOS system colors
    private let backgroundColors: [(name: String, color: Color, hex: String)] = [
        // Molten brand colors
        ("Molten Orange", DesignSystem.Colors.moltenOrange, "#FF5722"),
        ("Molten Amber", DesignSystem.Colors.moltenAmber, "#FFC107"),
        ("Molten Teal", DesignSystem.Colors.moltenTeal, "#00796B"),
        // iOS system colors
        ("Blue", .blue, "#007AFF"),
        ("Purple", .purple, "#AF52DE"),
        ("Pink", .pink, "#FF2D55"),
        ("Red", .red, "#FF3B30"),
        ("Green", .green, "#34C759"),
        ("Indigo", .indigo, "#5856D6"),
        ("Brown", .brown, "#A2845E"),
        ("Gray", .gray, "#8E8E93"),
        ("Black", .black, "#000000")
    ]

    // Foreground/icon colors
    // Molten brand colors first, then iOS system colors
    private let foregroundColors: [(name: String, color: Color, hex: String)] = [
        ("White", .white, "#FFFFFF"),
        // Molten brand colors
        ("Molten Orange", DesignSystem.Colors.moltenOrange, "#FF5722"),
        ("Molten Amber", DesignSystem.Colors.moltenAmber, "#FFC107"),
        ("Molten Teal", DesignSystem.Colors.moltenTeal, "#00796B"),
        // iOS system colors
        ("Blue", .blue, "#007AFF"),
        ("Purple", .purple, "#AF52DE"),
        ("Pink", .pink, "#FF2D55"),
        ("Red", .red, "#FF3B30"),
        ("Green", .green, "#34C759"),
        ("Indigo", .indigo, "#5856D6"),
        ("Brown", .brown, "#A2845E"),
        ("Gray", .gray, "#8E8E93"),
        ("Black", .black, "#000000")
    ]

    init(friend: FriendShare, viewModel: InventorySharingViewModel) {
        self.friend = friend
        self.viewModel = viewModel

        // Initialize state with current values or defaults
        _selectedSymbol = State(initialValue: friend.iconSymbol ?? FriendShare.defaultIconSymbol)
        _selectedBackgroundColor = State(initialValue: {
            if let hex = friend.iconBackgroundHex {
                return Color(hex: hex)
            }
            return Color(hex: FriendShare.defaultIconBackgroundHex)
        }())
        _selectedForegroundColor = State(initialValue: {
            if let hex = friend.iconForegroundHex {
                return Color(hex: hex)
            }
            return Color(hex: FriendShare.defaultIconForegroundHex)
        }())
        _nickname = State(initialValue: friend.nickname ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
                // Preview section
                Section {
                    HStack {
                        Spacer()
                        VStack(spacing: DesignSystem.Spacing.md) {
                            Circle()
                                .fill(selectedBackgroundColor)
                                .frame(width: 80, height: 80)
                                .overlay(
                                    Image(systemName: selectedSymbol)
                                        .font(.system(size: 40))
                                        .foregroundStyle(selectedForegroundColor)
                                )

                            Text(friend.friendName)
                                .font(DesignSystem.Typography.listItemTitle)
                                .foregroundColor(DesignSystem.Colors.textPrimary)
                        }
                        Spacer()
                    }
                    .padding(.vertical, DesignSystem.Spacing.lg)
                } header: {
                    Text("Preview")
                }

                // Nickname section
                Section {
                    TextField("Nickname (Optional)", text: $nickname)
                        .textContentType(.nickname)
                } header: {
                    Text("Nickname")
                } footer: {
                    Text("Add a personal nickname to remember how you know them (e.g., \"Bob from GAS 2025\")")
                }

                // Symbol selection
                Section {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 60))], spacing: DesignSystem.Spacing.md) {
                        ForEach(commonSymbols, id: \.self) { symbol in
                            Button {
                                selectedSymbol = symbol
                            } label: {
                                Circle()
                                    .fill(selectedBackgroundColor.opacity(0.2))
                                    .frame(width: 60, height: 60)
                                    .overlay(
                                        Image(systemName: symbol)
                                            .font(.system(size: 28))
                                            .foregroundStyle(selectedSymbol == symbol ? selectedBackgroundColor : .secondary)
                                    )
                                    .overlay(
                                        Circle()
                                            .stroke(selectedBackgroundColor, lineWidth: selectedSymbol == symbol ? 3 : 0)
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, DesignSystem.Spacing.xs)
                } header: {
                    Text("Icon")
                }

                // Background color selection
                Section {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 50))], spacing: DesignSystem.Spacing.sm) {
                        ForEach(backgroundColors, id: \.hex) { item in
                            Button {
                                selectedBackgroundColor = item.color
                            } label: {
                                Circle()
                                    .fill(item.color)
                                    .frame(width: 50, height: 50)
                                    .overlay(
                                        Circle()
                                            .stroke(.white, lineWidth: selectedBackgroundColor.toHex() == item.hex ? 4 : 0)
                                    )
                                    .overlay(
                                        Circle()
                                            .stroke(.black.opacity(0.1), lineWidth: 1)
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, DesignSystem.Spacing.xs)
                } header: {
                    Text("Background Color")
                }

                // Foreground color selection
                Section {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 50))], spacing: DesignSystem.Spacing.sm) {
                        ForEach(foregroundColors, id: \.hex) { item in
                            Button {
                                selectedForegroundColor = item.color
                            } label: {
                                Circle()
                                    .fill(item.color)
                                    .frame(width: 50, height: 50)
                                    .overlay(
                                        Circle()
                                            .stroke(
                                                selectedForegroundColor.toHex() == item.hex ? .blue : .clear,
                                                lineWidth: 4
                                            )
                                    )
                                    .overlay(
                                        Circle()
                                            .stroke(.black.opacity(0.1), lineWidth: 1)
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, DesignSystem.Spacing.xs)
                } header: {
                    Text("Icon Color")
                } footer: {
                    Text("Choose a color that contrasts well with your background")
                }

                // Reset button
                Section {
                    Button {
                        resetToDefaults()
                    } label: {
                        HStack {
                            Image(systemName: "arrow.counterclockwise")
                            Text("Reset to Default")
                        }
                    }
                }
            }
            .navigationTitle("Customize")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .accessibilityIdentifier("customize_friend_cancel")
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveChanges()
                    }
                    .accessibilityIdentifier("customize_friend_save")
                }
            }
        }
    }

    private func resetToDefaults() {
        nickname = ""
        selectedSymbol = FriendShare.defaultIconSymbol
        selectedBackgroundColor = Color(hex: FriendShare.defaultIconBackgroundHex)
        selectedForegroundColor = Color(hex: FriendShare.defaultIconForegroundHex)
    }

    private func saveChanges() {
        let backgroundHex = selectedBackgroundColor.toHex()
        let foregroundHex = selectedForegroundColor.toHex()

        // Update nickname
        let trimmedNickname = nickname.trimmingCharacters(in: .whitespaces)
        viewModel.updateFriendNickname(
            friend,
            nickname: trimmedNickname.isEmpty ? nil : trimmedNickname
        )

        // Update icon
        viewModel.updateFriendIcon(
            friend,
            symbol: selectedSymbol,
            backgroundHex: backgroundHex,
            foregroundHex: foregroundHex
        )

        dismiss()
    }
}

#Preview {
    CustomizeFriendView(
        friend: FriendShare(
            shareCode: "ABC123",
            friendName: "Alice",
            dateAdded: Date()
        ),
        viewModel: InventorySharingViewModel()
    )
}

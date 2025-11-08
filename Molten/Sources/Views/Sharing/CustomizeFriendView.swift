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

    // Common SF Symbols for friend icons
    private let commonSymbols = [
        "circle.fill",
        "person.circle.fill",
        "star.fill",
        "heart.fill",
        "flame.fill",
        "sparkles",
        "moon.fill",
        "sun.max.fill",
        "bolt.fill",
        "leaf.fill",
        "drop.fill",
        "snowflake"
    ]

    // Common background colors with good contrast
    private let backgroundColors: [(name: String, color: Color, hex: String)] = [
        ("Blue", .blue, "#007AFF"),
        ("Purple", .purple, "#AF52DE"),
        ("Pink", .pink, "#FF2D55"),
        ("Red", .red, "#FF3B30"),
        ("Orange", .orange, "#FF9500"),
        ("Yellow", .yellow, "#FFCC00"),
        ("Green", .green, "#34C759"),
        ("Teal", .teal, "#5AC8FA"),
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
                                .font(.headline)
                        }
                        Spacer()
                    }
                    .padding(.vertical, DesignSystem.Spacing.lg)
                } header: {
                    Text("Preview")
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
                    HStack(spacing: DesignSystem.Spacing.lg) {
                        Button {
                            selectedForegroundColor = .white
                        } label: {
                            Circle()
                                .fill(.white)
                                .frame(width: 50, height: 50)
                                .overlay(
                                    Circle()
                                        .stroke(selectedForegroundColor == .white ? .blue : .black.opacity(0.1), lineWidth: selectedForegroundColor == .white ? 4 : 1)
                                )
                        }
                        .buttonStyle(.plain)

                        Button {
                            selectedForegroundColor = .black
                        } label: {
                            Circle()
                                .fill(.black)
                                .frame(width: 50, height: 50)
                                .overlay(
                                    Circle()
                                        .stroke(selectedForegroundColor == .black ? .blue : .black.opacity(0.1), lineWidth: selectedForegroundColor == .black ? 4 : 1)
                                )
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.vertical, DesignSystem.Spacing.xs)
                } header: {
                    Text("Icon Color")
                } footer: {
                    Text("Choose white or black for best contrast")
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
            .navigationTitle("Customize Icon")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveChanges()
                    }
                }
            }
        }
    }

    private func resetToDefaults() {
        selectedSymbol = FriendShare.defaultIconSymbol
        selectedBackgroundColor = Color(hex: FriendShare.defaultIconBackgroundHex)
        selectedForegroundColor = Color(hex: FriendShare.defaultIconForegroundHex)
    }

    private func saveChanges() {
        let backgroundHex = selectedBackgroundColor.toHex()
        let foregroundHex = selectedForegroundColor.toHex()

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

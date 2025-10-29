//
//  FloatingActionButton.swift
//  Molten
//
//  Floating action button with popup menu for quick actions
//

import SwiftUI

/// Action item for the floating action button menu
struct FABAction: Identifiable {
    let id = UUID()
    let title: String
    let icon: String
    let action: () -> Void
}

/// Floating action button that shows a popup menu when tapped
struct FloatingActionButton: View {
    let actions: [FABAction]

    @State private var isExpanded = false

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            // Dimmed background when expanded
            if isExpanded {
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                    .onTapGesture {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            isExpanded = false
                        }
                    }
            }

            VStack(alignment: .trailing, spacing: 16) {
                // Action buttons (shown when expanded)
                if isExpanded {
                    ForEach(actions.reversed()) { action in
                        actionButton(for: action)
                            .transition(.asymmetric(
                                insertion: .scale.combined(with: .opacity),
                                removal: .scale.combined(with: .opacity)
                            ))
                    }
                }

                // Main FAB button
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        isExpanded.toggle()
                    }
                } label: {
                    Image(systemName: isExpanded ? "xmark" : "plus")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .frame(width: 56, height: 56)
                        .background(Color.accentColor)
                        .clipShape(Circle())
                        .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 4)
                }
                .rotationEffect(.degrees(isExpanded ? 45 : 0))
            }
            .padding()
        }
    }

    private func actionButton(for fabAction: FABAction) -> some View {
        Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                isExpanded = false
            }
            // Small delay to let the close animation play
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                fabAction.action()
            }
        } label: {
            HStack(spacing: 12) {
                Text(fabAction.title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Color(.systemBackground))
                    .cornerRadius(20)
                    .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)

                Image(systemName: fabAction.icon)
                    .font(.title3)
                    .foregroundColor(.white)
                    .frame(width: 48, height: 48)
                    .background(Color.accentColor)
                    .clipShape(Circle())
                    .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)
            }
        }
    }
}

#Preview {
    ZStack {
        Color(.systemGroupedBackground)
            .ignoresSafeArea()

        FloatingActionButton(actions: [
            FABAction(title: "Add Inventory", icon: "archivebox.fill") { print("Add Inventory") },
            FABAction(title: "Add to Shopping List", icon: "cart.fill") { print("Add to Shopping") },
            FABAction(title: "Add Image", icon: "photo.fill") { print("Add Image") }
        ])
    }
}

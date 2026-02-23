//
//  ColorSearchButton.swift
//  Molten
//
//  Button with eyedropper icon and rainbow gradient ring for triggering color search.
//

import SwiftUI

/// Button that opens the color search interface
/// Displays an eyedropper icon surrounded by a rainbow gradient ring
struct ColorSearchButton: View {
    /// Whether color search is currently active
    let isActive: Bool

    /// Optional: The currently selected search color (shown when active)
    let activeColor: Color?

    /// Action to perform when tapped
    let action: () -> Void

    init(isActive: Bool, activeColor: Color? = nil, action: @escaping () -> Void) {
        self.isActive = isActive
        self.activeColor = activeColor
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            ZStack {
                // Background - either rainbow ring or solid color when active
                if isActive, let color = activeColor {
                    // Active state: show the selected color as background
                    Circle()
                        .fill(color)
                        .frame(width: 32, height: 32)

                    Circle()
                        .strokeBorder(Color.white.opacity(0.5), lineWidth: 2)
                        .frame(width: 32, height: 32)
                } else {
                    // Inactive state: rainbow gradient ring
                    Circle()
                        .fill(DesignSystem.Colors.backgroundSecondary)
                        .frame(width: 32, height: 32)

                    Circle()
                        .strokeBorder(
                            AngularGradient(
                                colors: [
                                    .red,
                                    .orange,
                                    .yellow,
                                    .green,
                                    .cyan,
                                    .blue,
                                    .purple,
                                    .pink,
                                    .red
                                ],
                                center: .center
                            ),
                            lineWidth: 3
                        )
                        .frame(width: 32, height: 32)
                }

                // Eyedropper icon
                Image(systemName: isActive ? "eyedropper.full" : "eyedropper")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(isActive ? contrastingTextColor : .primary)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isActive ? "Color search active" : "Search by color")
        .accessibilityHint(isActive ? "Tap to change or clear color filter" : "Tap to search catalog by color")
    }

    /// Calculate contrasting text color for the active color
    private var contrastingTextColor: Color {
        guard let color = activeColor else { return .white }

        // Get brightness of the color
        #if canImport(UIKit)
        let uiColor = UIColor(color)
        var white: CGFloat = 0
        uiColor.getWhite(&white, alpha: nil)
        return white > 0.5 ? .black : .white
        #else
        return .white
        #endif
    }
}

// MARK: - Preview

#Preview {
    HStack(spacing: 20) {
        ColorSearchButton(isActive: false, action: {})
        ColorSearchButton(isActive: true, activeColor: .blue, action: {})
        ColorSearchButton(isActive: true, activeColor: .yellow, action: {})
        ColorSearchButton(isActive: true, activeColor: .red, action: {})
    }
    .padding()
}

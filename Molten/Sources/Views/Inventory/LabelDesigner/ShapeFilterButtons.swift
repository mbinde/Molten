//
//  ShapeFilterButtons.swift
//  Molten
//
//  Shape filter buttons for label format selection
//

import SwiftUI

/// Horizontal row of shape filter buttons for filtering label formats
struct ShapeFilterButtons: View {
    @Binding var selectedShape: LabelShape?

    var body: some View {
        HStack(spacing: 8) {
            ForEach(LabelShape.allCases) { shape in
                ShapeFilterButton(
                    shape: shape,
                    isSelected: selectedShape == shape,
                    action: {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            if selectedShape == shape {
                                // Tap again to deselect
                                selectedShape = nil
                            } else {
                                selectedShape = shape
                            }
                        }
                    }
                )
            }
        }
        .padding(.vertical, 4)
    }
}

/// Individual shape filter button
private struct ShapeFilterButton: View {
    let shape: LabelShape
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                shapeIcon
                    .frame(width: 32, height: 24)
                Text(shape.displayName)
                    .font(.caption2)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(isSelected ? Color.accentColor.opacity(0.2) : Color(.systemGray6))
            .foregroundColor(isSelected ? .accentColor : .primary)
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("shape_filter_\(shape.rawValue)")
    }

    @ViewBuilder
    private var shapeIcon: some View {
        if let systemImage = shape.systemImage {
            Image(systemName: systemImage)
                .font(.system(size: 20))
        } else {
            // Custom icon for flag/barbell labels
            FlagLabelIcon()
        }
    }
}

/// Custom icon for flag/barbell cable labels (no SF Symbol equivalent)
struct FlagLabelIcon: View {
    var body: some View {
        HStack(spacing: 1) {
            RoundedRectangle(cornerRadius: 1)
                .frame(width: 6, height: 14)
            Rectangle()
                .frame(width: 10, height: 3)
            RoundedRectangle(cornerRadius: 1)
                .frame(width: 6, height: 14)
        }
    }
}

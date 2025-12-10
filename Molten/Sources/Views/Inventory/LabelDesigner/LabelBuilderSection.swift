//
//  LabelBuilderSection.swift
//  Molten
//
//  Extracted from LabelDesignerView.swift
//

import SwiftUI

struct LabelBuilderSection: View {
    @Binding var builderConfig: LabelBuilderConfig
    @Binding var fontScale: Double
    let selectedFormat: LabelGeometry
    let onToggleField: (LabelTextField) -> Void

    var body: some View {
        Section {
            VStack(alignment: .leading, spacing: 12) {
                // Font Size (at the top)
                VStack(alignment: .leading, spacing: 6) {
                    Text("Font Size")
                        .font(.subheadline)
                        .fontWeight(.medium)

                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("\(Int(fontScale * 100))%")
                                .font(.caption)
                                .foregroundColor(DesignSystem.Colors.textSecondary)
                                .monospacedDigit()
                            Spacer()
                        }

                        Slider(value: $fontScale, in: 0.2...2.0, step: 0.1) {
                            Text("Font Size")
                        }
                        .tint(.blue)

                        HStack {
                            Text("Smaller")
                                .font(.caption2)
                                .foregroundColor(DesignSystem.Colors.textSecondary)
                            Spacer()
                            Text("Larger")
                                .font(.caption2)
                                .foregroundColor(DesignSystem.Colors.textSecondary)
                        }
                    }
                }

                Divider()

                // QR Code Position
                VStack(alignment: .leading, spacing: 6) {
                    Text("QR Code Position")
                        .font(.subheadline)
                        .fontWeight(.medium)

                    Picker("QR Position", selection: $builderConfig.qrPosition) {
                        ForEach(QRCodePosition.allCases, id: \.self) { position in
                            Text(position.displayName(for: selectedFormat.shape)).tag(position)
                        }
                    }
                    .pickerStyle(.segmented)

                    // Overlap warning
                    if builderConfig.manufacturerImageOverlapsQR() {
                        HStack(alignment: .top, spacing: 6) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.caption)
                                .foregroundColor(.red)
                            Text("QR code will cover manufacturer image")
                                .font(.caption)
                                .foregroundColor(.red)
                        }
                        .padding(.top, 4)
                    }

                    if builderConfig.qrPosition != .none {
                        // QR Size slider
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text("QR Code Size")
                                    .font(.caption)
                                Spacer()
                                Text("\(Int((builderConfig.qrSize ?? 0.65) * 100))%")
                                    .font(.caption)
                                    .foregroundColor(DesignSystem.Colors.textSecondary)
                                    .monospacedDigit()
                            }

                            Slider(
                                value: Binding(
                                    get: { builderConfig.qrSize ?? 0.65 },
                                    set: { builderConfig.qrSize = $0 }
                                ),
                                in: 0.5...0.8,
                                step: 0.05
                            )
                            .tint(.blue)

                            HStack {
                                Text("Smaller")
                                    .font(.caption2)
                                    .foregroundColor(DesignSystem.Colors.textSecondary)
                                Spacer()
                                Text("Larger")
                                    .font(.caption2)
                                    .foregroundColor(DesignSystem.Colors.textSecondary)
                            }
                        }
                    }
                }

                Divider()

                // Text Fields
                VStack(alignment: .leading, spacing: 6) {
                    Text("Label Fields")
                        .font(.subheadline)
                        .fontWeight(.medium)

                    // Active fields with drag-to-reorder
                    if !builderConfig.textFields.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text("Active Fields")
                                    .font(.caption)
                                    .foregroundColor(DesignSystem.Colors.textSecondary)
                                Spacer()
                                Text("Hold & drag to reorder")
                                    .font(.caption2)
                                    .foregroundColor(DesignSystem.Colors.textSecondary)
                            }

                            ForEach(Array(builderConfig.textFields.enumerated()), id: \.element) { index, field in
                                LabelFieldRow(
                                    field: field,
                                    isActive: true,
                                    onTap: { onToggleField(field) }
                                )
                                .draggable(field.rawValue) {
                                    // Drag preview
                                    Text(field.rawValue)
                                        .padding(8)
                                        .background(Color(.systemGray5))
                                        .cornerRadius(6)
                                }
                                .dropDestination(for: String.self) { items, _ in
                                    guard let droppedName = items.first,
                                          let droppedField = LabelTextField(rawValue: droppedName),
                                          let fromIndex = builderConfig.textFields.firstIndex(of: droppedField),
                                          fromIndex != index else {
                                        return false
                                    }
                                    withAnimation {
                                        builderConfig.textFields.move(fromOffsets: IndexSet(integer: fromIndex), toOffset: index > fromIndex ? index + 1 : index)
                                    }
                                    return true
                                }
                            }
                        }
                    }

                    // Available fields - tap to add
                    let unusedFields = LabelTextField.allCases.filter { !builderConfig.textFields.contains($0) }
                    if !unusedFields.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Available Fields")
                                .font(.caption)
                                .foregroundColor(DesignSystem.Colors.textSecondary)
                                .padding(.top, 8)

                            ForEach(unusedFields, id: \.self) { field in
                                LabelFieldRow(
                                    field: field,
                                    isActive: false,
                                    onTap: { onToggleField(field) }
                                )
                            }
                        }
                    }
                }
            }
        } header: {
            Text("Label Layout")
        } footer: {
            // Layout validation warnings
            let validation = builderConfig.validateLayout(for: selectedFormat, fontScale: fontScale)
            if !validation.warnings.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(validation.warnings, id: \.self) { warning in
                        HStack(alignment: .top, spacing: 6) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.caption)
                                .foregroundColor(.orange)
                            Text(warning)
                                .font(.caption)
                                .foregroundColor(.orange)
                        }
                    }
                }
                .padding(.top, 8)
            }
        }
    }
}

// MARK: - Label Field Row

private struct LabelFieldRow: View {
    let field: LabelTextField
    let isActive: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 8) {
                if isActive {
                    Image(systemName: "line.3.horizontal")
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                        .font(.caption)
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                } else {
                    Image(systemName: "plus.circle.fill")
                        .foregroundColor(.green)
                }

                Text(field.rawValue)
                    .font(.subheadline)
                    .foregroundColor(isActive ? .primary : .secondary)

                Spacer()

                if isActive {
                    Image(systemName: "minus.circle.fill")
                        .foregroundColor(.red)
                }
            }
        }
        .buttonStyle(.plain)
        .padding(.vertical, 6)
        .padding(.horizontal, 8)
        .background(Color(.systemGray6))
        .cornerRadius(6)
        .accessibilityIdentifier("label_builder_field_\(field.rawValue.lowercased().replacingOccurrences(of: " ", with: "_"))")
    }
}

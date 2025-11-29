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
                                .foregroundColor(.secondary)
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
                                .foregroundColor(.secondary)
                            Spacer()
                            Text("Larger")
                                .font(.caption2)
                                .foregroundColor(.secondary)
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
                                    .foregroundColor(.secondary)
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
                                    .foregroundColor(.secondary)
                                Spacer()
                                Text("Larger")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }

                Divider()

                // Text Fields
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("Label Fields")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        Spacer()
                        Text("Tap to toggle")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }

                    // Included fields with reorder buttons
                    if !builderConfig.textFields.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Active Fields (in order):")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .padding(.bottom, 4)

                            ForEach(Array(builderConfig.textFields.enumerated()), id: \.element) { index, field in
                                HStack(spacing: 8) {
                                    // Reorder buttons
                                    VStack(spacing: 0) {
                                        Button {
                                            if index > 0 {
                                                builderConfig.textFields.swapAt(index, index - 1)
                                            }
                                        } label: {
                                            Image(systemName: "chevron.up")
                                                .font(.caption2)
                                                .foregroundColor(index > 0 ? .secondary : .clear)
                                        }
                                        .buttonStyle(.plain)
                                        .disabled(index == 0)

                                        Button {
                                            if index < builderConfig.textFields.count - 1 {
                                                builderConfig.textFields.swapAt(index, index + 1)
                                            }
                                        } label: {
                                            Image(systemName: "chevron.down")
                                                .font(.caption2)
                                                .foregroundColor(index < builderConfig.textFields.count - 1 ? .secondary : .clear)
                                        }
                                        .buttonStyle(.plain)
                                        .disabled(index == builderConfig.textFields.count - 1)
                                    }

                                    Button {
                                        onToggleField(field)
                                    } label: {
                                        HStack(spacing: 8) {
                                            Image(systemName: "checkmark.circle.fill")
                                                .foregroundColor(.green)

                                            Text(field.rawValue)
                                                .font(.subheadline)

                                            Spacer()
                                        }
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                    }
                                    .buttonStyle(.plain)
                                    .accessibilityIdentifier("label_builder_field_\(field.rawValue.lowercased().replacingOccurrences(of: " ", with: "_"))")
                                }
                                .padding(.vertical, 6)
                                .padding(.horizontal, 8)
                                .background(Color(.systemGray6))
                                .cornerRadius(6)
                            }
                        }

                        Divider()
                            .padding(.vertical, 8)
                    }

                    // Available fields (not included)
                    let unusedFields = LabelTextField.allCases.filter { !builderConfig.textFields.contains($0) }
                    if !unusedFields.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Available Fields:")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .padding(.bottom, 4)

                            ForEach(unusedFields, id: \.self) { field in
                                Button {
                                    onToggleField(field)
                                } label: {
                                    HStack(spacing: 8) {
                                        Image(systemName: "circle")
                                            .foregroundColor(.secondary)

                                        Text(field.rawValue)
                                            .font(.subheadline)
                                            .foregroundColor(.secondary)

                                        Spacer()
                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                }
                                .buttonStyle(.plain)
                                .padding(.vertical, 6)
                                .padding(.horizontal, 8)
                                .accessibilityIdentifier("label_builder_field_\(field.rawValue.lowercased().replacingOccurrences(of: " ", with: "_"))")
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

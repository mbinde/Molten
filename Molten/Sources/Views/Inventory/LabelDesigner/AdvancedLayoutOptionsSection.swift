//
//  AdvancedLayoutOptionsSection.swift
//  Molten
//
//  Extracted from LabelDesignerView.swift
//

import SwiftUI

struct AdvancedLayoutOptionsSection: View {
    @Binding var builderConfig: LabelBuilderConfig
    @Binding var showAdvancedLayoutOptions: Bool

    var body: some View {
        Section {
            DisclosureGroup(
                isExpanded: $showAdvancedLayoutOptions,
                content: {
                    VStack(alignment: .leading, spacing: 16) {
                        // Manufacturer Image Position
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Manufacturer Image")
                                .font(.subheadline)
                                .fontWeight(.medium)

                            Picker("Image Position", selection: $builderConfig.manufacturerImagePosition) {
                                ForEach(ManufacturerImagePosition.allCases, id: \.self) { position in
                                    Text(position.rawValue).tag(position)
                                }
                            }
                            .pickerStyle(.segmented)

                            // Overlap warning
                            if builderConfig.manufacturerImageOverlapsQR() {
                                HStack(alignment: .top, spacing: 6) {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .font(.caption)
                                        .foregroundColor(.red)
                                    Text("Manufacturer image will be covered by QR code")
                                        .font(.caption)
                                        .foregroundColor(.red)
                                }
                                .padding(.top, 4)
                            }

                            // Manufacturer Image Size slider
                            if builderConfig.manufacturerImagePosition != .none {
                                VStack(alignment: .leading, spacing: 4) {
                                    HStack {
                                        Text("Image Size")
                                            .font(.caption)
                                        Spacer()
                                        Text("\(Int((builderConfig.manufacturerImageSize ?? 0.6) * 100))%")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                            .monospacedDigit()
                                    }

                                    Slider(
                                        value: Binding(
                                            get: { builderConfig.manufacturerImageSize ?? 0.6 },
                                            set: { builderConfig.manufacturerImageSize = $0 }
                                        ),
                                        in: 0.4...0.8,
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
                                .padding(.top, 8)
                            }
                        }

                        // Per-field formatting controls
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Field Formatting")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .padding(.top, 8)

                            ForEach(builderConfig.textFields, id: \.self) { field in
                                VStack(alignment: .leading, spacing: 8) {
                                    Text(field.rawValue.capitalized)
                                        .font(.caption)
                                        .fontWeight(.medium)

                                    // Get current format or default
                                    let currentFormat = builderConfig.format(for: field)

                                    // Style picker (plain/bold/italic)
                                    HStack(spacing: 12) {
                                        Text("Style:")
                                            .font(.caption)
                                            .foregroundColor(.secondary)

                                        Button {
                                            var format = builderConfig.format(for: field)
                                            format.bold = false
                                            format.italic = false
                                            builderConfig.fieldFormats[field] = format
                                        } label: {
                                            Text("Plain")
                                                .font(.caption)
                                                .padding(.horizontal, 8)
                                                .padding(.vertical, 4)
                                                .background(!currentFormat.bold && !currentFormat.italic ? DesignSystem.Colors.accentSecondary : Color.clear)
                                                .foregroundColor(!currentFormat.bold && !currentFormat.italic ? .white : .primary)
                                                .cornerRadius(4)
                                        }
                                        .buttonStyle(.plain)

                                        Button {
                                            var format = builderConfig.format(for: field)
                                            format.bold = true
                                            format.italic = false
                                            builderConfig.fieldFormats[field] = format
                                        } label: {
                                            Text("Bold")
                                                .font(.caption)
                                                .fontWeight(.bold)
                                                .padding(.horizontal, 8)
                                                .padding(.vertical, 4)
                                                .background(currentFormat.bold && !currentFormat.italic ? DesignSystem.Colors.accentSecondary : Color.clear)
                                                .foregroundColor(currentFormat.bold && !currentFormat.italic ? .white : .primary)
                                                .cornerRadius(4)
                                        }
                                        .buttonStyle(.plain)

                                        Button {
                                            var format = builderConfig.format(for: field)
                                            format.bold = false
                                            format.italic = true
                                            builderConfig.fieldFormats[field] = format
                                        } label: {
                                            Text("Italic")
                                                .font(.caption)
                                                .italic()
                                                .padding(.horizontal, 8)
                                                .padding(.vertical, 4)
                                                .background(!currentFormat.bold && currentFormat.italic ? DesignSystem.Colors.accentSecondary : Color.clear)
                                                .foregroundColor(!currentFormat.bold && currentFormat.italic ? .white : .primary)
                                                .cornerRadius(4)
                                        }
                                        .buttonStyle(.plain)
                                    }

                                    // Font size slider
                                    VStack(alignment: .leading, spacing: 4) {
                                        HStack {
                                            Text("Font Size")
                                                .font(.caption)
                                            Spacer()
                                            Text("\(Int(currentFormat.fontSize))pt")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                                .monospacedDigit()
                                        }

                                        Slider(
                                            value: Binding(
                                                get: { builderConfig.format(for: field).fontSize },
                                                set: { newValue in
                                                    var format = builderConfig.format(for: field)
                                                    format.fontSize = newValue
                                                    builderConfig.fieldFormats[field] = format
                                                }
                                            ),
                                            in: 5...14,
                                            step: 0.5
                                        )
                                        .tint(.blue)

                                        HStack {
                                            Text("5pt")
                                                .font(.caption2)
                                                .foregroundColor(.secondary)
                                            Spacer()
                                            Text("14pt")
                                                .font(.caption2)
                                                .foregroundColor(.secondary)
                                        }
                                    }

                                    Divider()
                                }
                            }
                        }
                    }
                },
                label: {
                    Label("Advanced Layout Options", systemImage: "slider.horizontal.3")
                }
            )
        }
    }
}

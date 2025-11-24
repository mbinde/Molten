//
//  AdvancedSheetOptionsSection.swift
//  Molten
//
//  Extracted from LabelDesignerView.swift
//

import SwiftUI

struct AdvancedSheetOptionsSection: View {
    @Binding var showAdvancedOptions: Bool
    @Binding var startRow: Int
    @Binding var startColumn: Int
    @Binding var offsetX: Double
    @Binding var offsetY: Double
    let selectedFormat: AveryFormat

    var body: some View {
        Section {
            DisclosureGroup(
                isExpanded: $showAdvancedOptions,
                content: {
                    VStack(spacing: 20) {
                        // Partial Sheet Controls
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Partial Sheet")
                                .font(.headline)

                            Text("Use this if you're printing on a partially-used label sheet")
                                .font(.caption)
                                .foregroundColor(.secondary)

                            // Start Row
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text("Start Row")
                                        .font(.subheadline)
                                    Spacer()
                                    Text("Row \(startRow + 1)")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .monospacedDigit()
                                }

                                Picker("Start Row", selection: $startRow) {
                                    ForEach(0..<selectedFormat.rows, id: \.self) { row in
                                        Text("Row \(row + 1)").tag(row)
                                    }
                                }
                                .pickerStyle(.wheel)
                                .frame(height: 100)
                            }

                            // Start Column
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text("Start Column")
                                        .font(.subheadline)
                                    Spacer()
                                    Text("Column \(startColumn + 1)")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .monospacedDigit()
                                }

                                Picker("Start Column", selection: $startColumn) {
                                    ForEach(0..<selectedFormat.columns, id: \.self) { col in
                                        Text("Column \(col + 1)").tag(col)
                                    }
                                }
                                .pickerStyle(.segmented)
                            }

                            // Show position description
                            if startRow != 0 || startColumn != 0 {
                                HStack(spacing: 4) {
                                    Image(systemName: "arrow.down.right.circle.fill")
                                        .foregroundColor(.orange)
                                    Text("Printing will start at Row \(startRow + 1), Column \(startColumn + 1)")
                                        .font(.caption)
                                        .foregroundColor(.orange)
                                }

                                Button {
                                    withAnimation {
                                        startRow = 0
                                        startColumn = 0
                                    }
                                } label: {
                                    Label("Reset to Full Sheet", systemImage: "arrow.counterclockwise")
                                        .font(.caption)
                                }
                                .buttonStyle(.bordered)
                                .accessibilityIdentifier("label_designer_reset_sheet")
                            }
                        }

                        Divider()

                        // Print Position Adjustments
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Position Adjustments")
                                .font(.headline)

                            // Horizontal offset
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text("Horizontal Position")
                                        .font(.subheadline)
                                    Spacer()
                                    Text(offsetX > 0 ? "+\(Int(offsetX))pt" : "\(Int(offsetX))pt")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .monospacedDigit()
                                }

                                Slider(value: $offsetX, in: -10...10, step: 0.5) {
                                    Text("Horizontal Offset")
                                }
                                .tint(.orange)

                                HStack {
                                    Text("← Left")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                    Spacer()
                                    Text("Right →")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                            }

                            // Vertical offset
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text("Vertical Position")
                                        .font(.subheadline)
                                    Spacer()
                                    Text(offsetY > 0 ? "+\(Int(offsetY))pt" : "\(Int(offsetY))pt")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .monospacedDigit()
                                }

                                Slider(value: $offsetY, in: -10...10, step: 0.5) {
                                    Text("Vertical Offset")
                                }
                                .tint(.orange)

                                HStack {
                                    Text("↑ Up")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                    Spacer()
                                    Text("Down ↓")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                            }

                            // Reset button
                            if offsetX != 0.0 || offsetY != 0.0 {
                                Button {
                                    withAnimation {
                                        offsetX = 0.0
                                        offsetY = 0.0
                                    }
                                } label: {
                                    Label("Reset Position", systemImage: "arrow.counterclockwise")
                                        .font(.caption)
                                }
                                .buttonStyle(.bordered)
                                .accessibilityIdentifier("label_designer_reset_position")
                            }
                        }
                    }
                },
                label: {
                    Label("Advanced Sheet Options", systemImage: "gearshape")
                }
            )
        }
    }
}
